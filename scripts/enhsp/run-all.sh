#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../utils/runner_common.sh
source "$APP_ROOT/scripts/utils/runner_common.sh"
PDDL_ROOT="${PDDL_ROOT:-$(runner_pddl_root "$APP_ROOT/benchmarks/pddl")}"
COMPOSE_FILE="$APP_ROOT/docker-compose.yml"
BUILD_IMAGE=0
POSITIONAL=()

usage() {
    cat <<EOF
Uso: $(basename "$0") [MODELLO] [ISTANZE] [opzioni]

Esegue ENHSP su un insieme di istanze tramite Docker Compose.

Argomenti:
  MODELLO       granular, direct-opt o direct (default: direct).
  ISTANZE       samples o all (default: samples).

Opzioni:
  --build       Costruisce l'immagine Docker prima dell'esecuzione.

Esempi:
  $(basename "$0") direct samples --build
  $(basename "$0") granular all
  TIME_LIMIT=300 $(basename "$0") direct-opt samples
EOF
}

while (($# > 0)); do
    case "$1" in
        --build)
            BUILD_IMAGE=1
            ;;
        --)
            shift
            POSITIONAL+=("$@")
            break
            ;;
        -*)
            echo "Opzione sconosciuta: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            POSITIONAL+=("$1")
            ;;
    esac
    shift
done

if ((${#POSITIONAL[@]} > 2)); then
    echo "Troppi argomenti: ${POSITIONAL[*]}" >&2
    usage >&2
    exit 2
fi

if [ -n "${POSITIONAL[0]:-}" ]; then
    PDDL_MODEL="${POSITIONAL[0]}"
elif [ -z "${PDDL_MODEL:-}" ] && [ -t 0 ]; then
    read -r -p "Modello (granular/direct-opt/direct): " PDDL_MODEL
else
    PDDL_MODEL="${PDDL_MODEL:-direct}"
fi

if [ -n "${POSITIONAL[1]:-}" ]; then
    INSTANCE_SET="${POSITIONAL[1]}"
elif [ -z "${INSTANCE_SET:-}" ] && [ -t 0 ]; then
    read -r -p "Istanze (samples/all): " INSTANCE_SET
else
    INSTANCE_SET="${INSTANCE_SET:-samples}"
fi

case "$INSTANCE_SET" in
    "samples"|"all") ;;
    *) runner_die "selezione istanze non supportata: $INSTANCE_SET (valori ammessi: samples, all)" ;;
esac

RUN_ONE="${RUN_ONE:-$SCRIPT_DIR/run-one.sh}"
case "$PDDL_MODEL" in
    "direct")
        DEFAULT_DOMAIN="$PDDL_ROOT/domains/numeric.pddl"
        DEFAULT_PROBLEMS_DIR="$PDDL_ROOT/instances-direct-numeric"
        DEFAULT_SAMPLE_LIST="$APP_ROOT/benchmarks/manifests/sample-instances.txt"
        DEFAULT_PROBLEM_NAME_PATTERN="*.pddl"
        DEFAULT_PLANNER="wastar-colour"
        ;;
    "direct-opt")
        DEFAULT_DOMAIN="$PDDL_ROOT/domains/numeric-opt.pddl"
        DEFAULT_PROBLEMS_DIR="$PDDL_ROOT/instances-direct-numeric-opt"
        DEFAULT_SAMPLE_LIST="$APP_ROOT/benchmarks/manifests/sample-instances.txt"
        DEFAULT_PROBLEM_NAME_PATTERN="*.pddl"
        DEFAULT_PLANNER="wastar-colour-opt"
        ;;
    "granular")
        DEFAULT_DOMAIN=""
        DEFAULT_PROBLEMS_DIR="$PDDL_ROOT/instances-granular-enhsp-compatible"
        DEFAULT_SAMPLE_LIST="$APP_ROOT/benchmarks/manifests/sample-instances.txt"
        DEFAULT_PROBLEM_NAME_PATTERN="*-problem.pddl"
        DEFAULT_PLANNER="greedy-hadd"
        ;;
    *)
        runner_die "modello non supportato: $PDDL_MODEL (valori ammessi: granular, direct-opt, direct)"
        ;;
esac

if [ "$INSTANCE_SET" = "samples" ]; then
    DEFAULT_PROBLEM_LIST="$DEFAULT_SAMPLE_LIST"
else
    DEFAULT_PROBLEM_LIST=""
fi

DOMAIN="${DOMAIN:-$DEFAULT_DOMAIN}"
PROBLEMS_DIR="${PROBLEMS_DIR:-$DEFAULT_PROBLEMS_DIR}"
PROBLEM_LIST="${PROBLEM_LIST-$DEFAULT_PROBLEM_LIST}"
PROBLEM_NAME_PATTERN="${PROBLEM_NAME_PATTERN:-$DEFAULT_PROBLEM_NAME_PATTERN}"
TIME_LIMIT="${TIME_LIMIT:-900}"
JAVA_OPTS="${JAVA_OPTS:--Xmx24G}"
PLANNER="${PLANNER:-$DEFAULT_PLANNER}"

DEFAULT_RUN_NAME="enhsp-$PLANNER"
case "$PLANNER" in
    wastar-*)
        DEFAULT_HEURISTIC="${PLANNER#wastar-}"
        SEARCH="${SEARCH:-WAStar}"
        TIES="${TIES:-larger_g}"
        ;;
    greedy-*)
        DEFAULT_HEURISTIC="${PLANNER#greedy-}"
        SEARCH="${SEARCH:-gbfs}"
        TIES="${TIES:-smaller_g}"
        ;;
    *)
        DEFAULT_HEURISTIC="colour"
        SEARCH="${SEARCH:-WAStar}"
        TIES="${TIES:-larger_g}"
        ;;
esac
DEFAULT_HEURISTIC="${DEFAULT_HEURISTIC%-opt}"
if [ "$DEFAULT_HEURISTIC" = "optblind" ]; then
    DEFAULT_HEURISTIC="blind"
fi
HEURISTIC="${HEURISTIC:-$DEFAULT_HEURISTIC}"

if [ "$PDDL_MODEL" = "direct-opt" ]; then
    case "$DEFAULT_RUN_NAME" in
        *-opt) ;;
        *) DEFAULT_RUN_NAME="$DEFAULT_RUN_NAME-opt" ;;
    esac
fi

if [ "$PDDL_MODEL" = "granular" ]; then
    DEFAULT_RUN_NAME="${DEFAULT_RUN_NAME/enhsp-/enhsp-granular-}"
    RESULT_ENCODING="granular"
else
    DEFAULT_RUN_NAME="${DEFAULT_RUN_NAME/enhsp-/enhsp-direct-}"
    RESULT_ENCODING="direct"
fi
RESULT_RUN_NAME="${DEFAULT_RUN_NAME#enhsp-${RESULT_ENCODING}-}"

WH="${WH:-1}"
OUTPUT_DIR="${OUTPUT_DIR:-$APP_ROOT/results/pddl/enhsp/$RESULT_ENCODING/$RESULT_RUN_NAME}"
BIN_DIR="${BIN_DIR:-${TMPDIR:-/tmp}/pddl-runner-bin/$DEFAULT_RUN_NAME}"
VALIDATE_PLANS="${VALIDATE_PLANS:-1}"
SKIP_EXISTING_RESULTS="${SKIP_EXISTING_RESULTS:-1}"
PAPER2024_SELECTION="${PAPER2024_SELECTION:-0}"

if [ "${PLOTTING_RUNNER_IN_DOCKER:-0}" != "1" ]; then
    runner_require_file "file Docker Compose" "$COMPOSE_FILE"
    runner_require_docker_compose

    export LOCAL_UID="${LOCAL_UID:-$(id -u)}"
    export LOCAL_GID="${LOCAL_GID:-$(id -g)}"

    if ((BUILD_IMAGE)); then
        docker compose -f "$COMPOSE_FILE" build pddl-plotting
    fi

    DOCKER_ENV_ARGS=(--env PLOTTING_RUNNER_IN_DOCKER=1)
    runner_add_compose_env_args DOCKER_ENV_ARGS \
        TIME_LIMIT JAVA_OPTS PLANNER SEARCH TIES HEURISTIC WH \
        PROBLEM_NAME_PATTERN VALIDATE_PLANS SKIP_EXISTING_RESULTS \
        PAPER2024_SELECTION JAVA_BIN FD_DISABLE_NEGATIVE_AXIOMS
    runner_add_compose_path_env_args "$APP_ROOT" DOCKER_ENV_ARGS \
        PDDL_ROOT RUN_ONE DOMAIN PROBLEMS_DIR PROBLEM_LIST OUTPUT_DIR BIN_DIR

    exec docker compose -f "$COMPOSE_FILE" run --rm -T \
        --workdir /app \
        "${DOCKER_ENV_ARGS[@]}" \
        pddl-plotting \
        /app/scripts/enhsp/run-all.sh "$PDDL_MODEL" "$INSTANCE_SET"
fi

PLAN_DIR="$OUTPUT_DIR/plans"
LOG_DIR="$OUTPUT_DIR/logs"
VAL_DIR="$OUTPUT_DIR/validation"
CSV_FILE="$OUTPUT_DIR/stats.csv"

OUTPUT_DIR="$(runner_abs_path "$OUTPUT_DIR")"
PLAN_DIR="$OUTPUT_DIR/plans"
LOG_DIR="$OUTPUT_DIR/logs"
VAL_DIR="$OUTPUT_DIR/validation"
CSV_FILE="$OUTPUT_DIR/stats.csv"
BIN_DIR="$(runner_abs_path "$BIN_DIR")"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/enhsp-run-all.XXXXXX")"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$PLAN_DIR" "$LOG_DIR" "$VAL_DIR" "$BIN_DIR"

RUN_ONE="$(runner_abs_path "$RUN_ONE")"
PROBLEMS_DIR="$(runner_abs_path "$PROBLEMS_DIR")"
if [ -n "$PROBLEM_LIST" ]; then
    PROBLEM_LIST="$(runner_abs_path "$PROBLEM_LIST")"
    runner_require_file "lista problem" "$PROBLEM_LIST"
    PAPER2024_SELECTION=0
fi
if [ -n "$DOMAIN" ]; then
    DOMAIN="$(runner_abs_path "$DOMAIN")"
fi

[ -x "$RUN_ONE" ] || runner_die "runner singolo non trovato o non eseguibile: $RUN_ONE"
if [ -n "$DOMAIN" ]; then
    runner_require_file "domain" "$DOMAIN"
fi
runner_require_dir "cartella problem" "$PROBLEMS_DIR"
runner_setup_enhsp_path "$APP_ROOT" "$BIN_DIR" || true
if [ "$VALIDATE_PLANS" = "1" ]; then
    runner_setup_val_path "$APP_ROOT" "$BIN_DIR"
fi

export RUN_ONE PDDL_MODEL DOMAIN PROBLEMS_DIR OUTPUT_DIR PLAN_DIR LOG_DIR VAL_DIR TIME_LIMIT JAVA_OPTS HEURISTIC SEARCH WH TIES PLANNER BIN_DIR VALIDATE_PLANS SKIP_EXISTING_RESULTS PAPER2024_SELECTION

run_single_problem() {
    local problem="$1"
    local basename name_no_ext planner_log val_log final_plan console_log

    basename="$(basename "$problem")"
    name_no_ext="${basename%.pddl}"
    if [ "$PDDL_MODEL" = "granular" ]; then
        name_no_ext="${name_no_ext%-problem}"
    fi
    planner_log="$LOG_DIR/${name_no_ext}.planner.log"
    val_log="$VAL_DIR/${name_no_ext}.val.log"
    final_plan="$PLAN_DIR/${name_no_ext}.plan"
    console_log="$TMP_DIR/${name_no_ext}.console.log"

    if [ "$SKIP_EXISTING_RESULTS" = "1" ] && [ -e "$planner_log" ]; then
        local existing_summary status valid total_runtime_sec expanded_nodes actions
        existing_summary="$(runner_existing_result_summary "$planner_log" "$val_log" "$final_plan" "$VALIDATE_PLANS")"
        IFS='|' read -r status valid total_runtime_sec actions <<< "$existing_summary"
        expanded_nodes="$(runner_log_expanded_nodes "$planner_log")"
        [ -s "$final_plan" ] || final_plan=""
        runner_append_stats_row "$CSV_FILE" \
            "$basename" "$status" "$valid" "$total_runtime_sec" "$actions" "$expanded_nodes" "0" \
            "$final_plan" "$planner_log" "$val_log"
        echo "[skipped_existing] $basename | status=$status | valid=$valid | total=${total_runtime_sec}s | actions=$actions"
        return 0
    fi

    local start_ns end_ns total_runtime_sec exit_code
    start_ns="$(date +%s%N)"

    set +e
    "$RUN_ONE" "$problem" > "$console_log" 2>&1
    exit_code=$?
    set -e

    end_ns="$(date +%s%N)"
    total_runtime_sec="$(awk -v s="$start_ns" -v e="$end_ns" 'BEGIN { printf "%.3f", (e-s)/1000000000 }')"

    [ -f "$planner_log" ] || cp "$console_log" "$planner_log"
    [ -f "$val_log" ] || : > "$val_log"
    [ -s "$final_plan" ] || final_plan=""

    local expanded_nodes actions valid status
    expanded_nodes="$(runner_log_expanded_nodes "$planner_log")"
    if [ -n "$final_plan" ] && [ -f "$final_plan" ]; then
        actions="$(grep -E '^[[:space:]]*\(' "$final_plan" | wc -l | tr -d ' ')"
    else
        actions="0"
    fi

    if grep -qi "Plan valid" "$planner_log" "$val_log" 2>/dev/null; then
        valid="true"
    elif grep -qiE "Validation skipped|Validazione saltata" "$planner_log" "$val_log" 2>/dev/null; then
        valid="skipped"
    elif grep -qiE "Plan invalid|Goal not satisfied|Plan failed|Failed plans" "$planner_log" "$val_log" 2>/dev/null; then
        valid="false"
    else
        valid="unknown"
    fi

    if [ "$exit_code" -eq 0 ] && { [ "$valid" = "true" ] || [ "$valid" = "skipped" ]; }; then
        status="ok"
    elif [ "$exit_code" -eq 0 ] && [ -n "$final_plan" ] && [ "$VALIDATE_PLANS" != "1" ]; then
        valid="skipped"
        status="ok"
    elif [ "$exit_code" -eq 124 ] || grep -qi "timeout" "$planner_log"; then
        status="timeout"
    elif [ "$valid" = "false" ]; then
        status="invalid_plan"
    elif grep -qiE "no solution|unsolvable|unsolved|Problem unsolvable" "$planner_log"; then
        status="unsolved"
    elif grep -qiE "enhsp.*not found|comando enhsp non trovato|command not found|No such file" "$planner_log"; then
        status="planner_not_found"
    else
        status="planner_error"
    fi

    runner_append_stats_row "$CSV_FILE" \
        "$basename" "$status" "$valid" "$total_runtime_sec" "$actions" "$expanded_nodes" "$exit_code" \
        "$final_plan" "$planner_log" "$val_log"
    echo "[$status] $basename | exit=$exit_code | valid=$valid | total=${total_runtime_sec}s | actions=$actions"

    if [ "$status" != "ok" ]; then
        echo "  log: $planner_log"
        sed -n '1,8p' "$planner_log" | sed 's/^/  > /'
    fi
}

FIND_FILTER=(-name "$PROBLEM_NAME_PATTERN")
if [ "$PDDL_MODEL" = "direct" ] || [ "$PDDL_MODEL" = "direct-opt" ]; then
    FIND_FILTER+=(! -name "*-domain.pddl" ! -name "*-problem.pddl")
fi

list_problem_files() {
    if [ -n "$PROBLEM_LIST" ]; then
        runner_problem_list_stream "$PROBLEM_LIST" "$PROBLEMS_DIR" "$PROBLEM_NAME_PATTERN" "$PDDL_MODEL"
        return
    fi

    find "$PROBLEMS_DIR" -maxdepth 1 -type f "${FIND_FILTER[@]}" -print0 \
        | sort -z \
        | {
            if [ "$PAPER2024_SELECTION" = "1" ]; then
                runner_paper2024_filter_problem_stream "$PDDL_MODEL"
            else
                cat
            fi
          }
}

PROBLEM_COUNT="$(
    list_problem_files \
        | tr -cd '\0' \
        | wc -c \
        | tr -d ' '
)"

if [ "$PROBLEM_COUNT" -eq 0 ]; then
    echo "Nessun problem PDDL trovato in: $PROBLEMS_DIR"
    exit 1
fi

runner_init_stats_csv "$CSV_FILE"

if [ "$PAPER2024_SELECTION" = "1" ]; then
    runner_write_paper2024_heap_skips "$PDDL_MODEL" "$PROBLEMS_DIR" "$CSV_FILE" "$LOG_DIR" "$VAL_DIR" "$PLAN_DIR" "$TIME_LIMIT"
fi

while IFS= read -r -d '' problem; do
    run_single_problem "$problem"
done < <(list_problem_files)

echo
echo "Statistiche salvate in: $CSV_FILE"
echo
echo "Riepilogo:"
awk -F',' '
NR > 1 {
    gsub(/"/, "", $2)
    gsub(/"/, "", $3)
    status[$2]++
    valid[$3]++
}
END {
    print "Status:"
    for (s in status) print "  " s ": " status[s]
    print "Valid:"
    for (v in valid) print "  " v ": " valid[v]
}
' "$CSV_FILE"
