#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../utils/runner_common.sh
source "$APP_ROOT/scripts/utils/runner_common.sh"
PDDL_ROOT="${PDDL_ROOT:-$(runner_pddl_root "$APP_ROOT/benchmarks/pddl")}"
COMPOSE_FILE="$APP_ROOT/docker-compose.yml"
BUILD_IMAGE=0
SHOW_HELP=0
POSITIONAL=()

while (($# > 0)); do
    case "$1" in
        --build)
            BUILD_IMAGE=1
            ;;
        -h|--help)
            SHOW_HELP=1
            ;;
        --)
            shift
            POSITIONAL+=("$@")
            break
            ;;
        -*)
            echo "Opzione sconosciuta: $1" >&2
            exit 2
            ;;
        *)
            POSITIONAL+=("$1")
            ;;
    esac
    shift
done

PDDL_MODEL="${PDDL_MODEL:-direct}"
case "$PDDL_MODEL" in
    "direct")
        DEFAULT_DOMAIN="$PDDL_ROOT/domains/numeric.pddl"
        DEFAULT_PROBLEMS_DIR="$PDDL_ROOT/instances-direct-numeric"
        DEFAULT_PROBLEM_EXAMPLE="$PDDL_ROOT/instances-direct-numeric/plt0_2_4_2_1.pddl"
        DEFAULT_PLANNER="wastar-colour"
        ;;
    "direct-opt")
        DEFAULT_DOMAIN="$PDDL_ROOT/domains/numeric-opt.pddl"
        DEFAULT_PROBLEMS_DIR="$PDDL_ROOT/instances-direct-numeric-opt"
        DEFAULT_PROBLEM_EXAMPLE="$PDDL_ROOT/instances-direct-numeric-opt/plt0_2_4_2_1.pddl"
        DEFAULT_PLANNER="wastar-colour-opt"
        ;;
    "granular")
        DEFAULT_DOMAIN=""
        DEFAULT_PROBLEMS_DIR="$PDDL_ROOT/instances-granular-enhsp-compatible"
        DEFAULT_PROBLEM_EXAMPLE="$PDDL_ROOT/instances-granular-enhsp-compatible/plt0_2_4_2_1-problem.pddl"
        DEFAULT_PLANNER="greedy-hadd"
        ;;
    *)
        runner_die "PDDL_MODEL non supportato: $PDDL_MODEL (valori ammessi: direct, direct-opt, granular)"
        ;;
esac

DOMAIN="${DOMAIN:-$DEFAULT_DOMAIN}"
PROBLEMS_DIR="${PROBLEMS_DIR:-$DEFAULT_PROBLEMS_DIR}"
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

usage() {
    cat <<EOF
Uso: $(basename "$0") [--build] <path_problem.pddl>

Esegue una singola istanza ENHSP tramite Docker Compose.

Opzioni:
  --build       Costruisce l'immagine Docker prima dell'esecuzione.
  -h, --help    Mostra questo messaggio.

Esempio:
  PDDL_MODEL=$PDDL_MODEL $(basename "$0") "$DEFAULT_PROBLEM_EXAMPLE"

Variabili opzionali:
  PDDL_MODEL=$PDDL_MODEL
  DOMAIN=${DOMAIN:-<automatico dal problem granulare>}
  PROBLEMS_DIR=$PROBLEMS_DIR
  OUTPUT_DIR=$OUTPUT_DIR
  TIME_LIMIT=$TIME_LIMIT
  JAVA_OPTS=$JAVA_OPTS
  HEURISTIC=$HEURISTIC
  SEARCH=$SEARCH
  WH=$WH
  TIES=$TIES
  PLANNER=$PLANNER
  VALIDATE_PLANS=$VALIDATE_PLANS
EOF
}

if ((SHOW_HELP)); then
    usage
    exit 0
fi

if [ "${#POSITIONAL[@]}" -ne 1 ]; then
    usage >&2
    exit 1
fi

PROBLEM_ARG="${POSITIONAL[0]}"

if [ "${PLOTTING_RUNNER_IN_DOCKER:-0}" != "1" ]; then
    runner_require_file "file Docker Compose" "$COMPOSE_FILE"
    runner_require_docker_compose

    export LOCAL_UID="${LOCAL_UID:-$(id -u)}"
    export LOCAL_GID="${LOCAL_GID:-$(id -g)}"

    if ((BUILD_IMAGE)); then
        docker compose -f "$COMPOSE_FILE" build pddl-plotting
    fi

    DOCKER_ENV_ARGS=(
        --env PLOTTING_RUNNER_IN_DOCKER=1
        --env "PDDL_MODEL=$PDDL_MODEL"
    )
    runner_add_compose_env_args DOCKER_ENV_ARGS \
        TIME_LIMIT JAVA_OPTS PLANNER SEARCH TIES HEURISTIC WH \
        VALIDATE_PLANS JAVA_BIN FD_DISABLE_NEGATIVE_AXIOMS
    runner_add_compose_path_env_args "$APP_ROOT" DOCKER_ENV_ARGS \
        PDDL_ROOT DOMAIN PROBLEMS_DIR OUTPUT_DIR BIN_DIR \
        PLAN_DIR LOG_DIR VAL_DIR PLAN_FILE PLANNER_LOG VAL_LOG

    PROBLEM_ARG="$(runner_project_container_path "$APP_ROOT" "$PROBLEM_ARG")"
    exec docker compose -f "$COMPOSE_FILE" run --rm -T \
        --workdir /app \
        "${DOCKER_ENV_ARGS[@]}" \
        pddl-plotting \
        /app/scripts/enhsp/run-one.sh "$PROBLEM_ARG"
fi

PROBLEM_ARG="$(runner_problem_name_for_model "$PROBLEM_ARG" "$PDDL_MODEL")"

PROBLEM="$(runner_problem_path "$PROBLEM_ARG" "$PROBLEMS_DIR")"
if [ "$PDDL_MODEL" = "granular" ] && [ -z "$DOMAIN" ]; then
    DOMAIN="${PROBLEM%-problem.pddl}-domain.pddl"
fi

DOMAIN="$(runner_abs_path "$DOMAIN")"
OUTPUT_DIR="$(runner_abs_path "$OUTPUT_DIR")"
BIN_DIR="$(runner_abs_path "$BIN_DIR")"
PLAN_DIR="${PLAN_DIR:-$OUTPUT_DIR/plans}"
LOG_DIR="${LOG_DIR:-$OUTPUT_DIR/logs}"
VAL_DIR="${VAL_DIR:-$OUTPUT_DIR/validation}"

mkdir -p "$PLAN_DIR" "$LOG_DIR" "$VAL_DIR" "$BIN_DIR"
runner_require_file "domain" "$DOMAIN"
runner_require_file "problem" "$PROBLEM"
runner_setup_enhsp_path "$APP_ROOT" "$BIN_DIR" || runner_die "comando enhsp non trovato nel PATH"
if [ "$VALIDATE_PLANS" = "1" ]; then
    runner_setup_val_path "$APP_ROOT" "$BIN_DIR"
    command -v validate >/dev/null 2>&1 || runner_die "validate non trovato nel PATH"
fi
runner_check_no_floating_block "$DOMAIN" "$PROBLEM"

BASENAME="$(basename "$PROBLEM")"
NAME="${BASENAME%.pddl}"
if [ "$PDDL_MODEL" = "granular" ]; then
    NAME="${NAME%-problem}"
fi

PLAN_FILE="${PLAN_FILE:-$PLAN_DIR/$NAME.plan}"
PLANNER_LOG="${PLANNER_LOG:-$LOG_DIR/$NAME.planner.log}"
VAL_LOG="${VAL_LOG:-$VAL_DIR/$NAME.val.log}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/enhsp-${NAME}.XXXXXX")"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

rm -f "$PLAN_FILE" "$PLANNER_LOG" "$VAL_LOG"

echo "PDDL model:   $PDDL_MODEL"
echo "Domain:       $DOMAIN"
echo "Problem:      $PROBLEM"
echo "Output dir:   $OUTPUT_DIR"
echo "Plan:         $PLAN_FILE"
echo "Planner log:  $PLANNER_LOG"
echo "VAL log:      $VAL_LOG"
echo "Time limit:   $TIME_LIMIT"
echo "Java opts:    $JAVA_OPTS"
echo "Validate:     $VALIDATE_PLANS"
if [ -n "$PLANNER" ]; then
    echo "Planner:      $PLANNER"
    echo "Heuristic:    $HEURISTIC"
    echo "Search:       $SEARCH"
    echo "H weight:     $WH"
    echo "Tie-breaking: $TIES"
else
    echo "Heuristic:    $HEURISTIC"
    echo "Search:       $SEARCH"
    echo "H weight:     $WH"
    echo "Tie-breaking: $TIES"
fi
echo
echo "Esecuzione ENHSP..."

START_TIME="$(date +%s.%N)"

ENHSP_ARGS=(-o "$DOMAIN" -f "$PROBLEM")
if [ -n "$PLANNER" ]; then
    ENHSP_ARGS+=(-planner "$PLANNER")
else
    if [ -n "$HEURISTIC" ]; then
        ENHSP_ARGS+=(-h "$HEURISTIC")
    fi
    if [ -n "$SEARCH" ]; then
        ENHSP_ARGS+=(-s "$SEARCH")
    fi
    ENHSP_ARGS+=(-wh "$WH" -ties "$TIES")
fi

set +e
# qui viene richiamato il planner
timeout "$TIME_LIMIT" enhsp "${ENHSP_ARGS[@]}" > "$PLANNER_LOG" 2>&1
ENHSP_EXIT=$?
set -e

END_TIME="$(date +%s.%N)"
ELAPSED_TIME="$(awk "BEGIN {printf \"%.3f\", $END_TIME - $START_TIME}")"

{
    echo
    echo "Tempo esecuzione ENHSP: ${ELAPSED_TIME} sec"
} >> "$PLANNER_LOG"

cat "$PLANNER_LOG"

if [ "$ENHSP_EXIT" -eq 124 ]; then
    echo
    echo "Errore: timeout dopo ${TIME_LIMIT} secondi"
    exit 124
fi

if [ "$ENHSP_EXIT" -ne 0 ]; then
    echo
    echo "Errore: ENHSP e' terminato con exit code $ENHSP_EXIT"
    exit "$ENHSP_EXIT"
fi

echo
echo "Estrazione piano dal log ENHSP..."
if [ "$PDDL_MODEL" = "granular" ]; then
    runner_extract_plotting_granular_plan "$PLANNER_LOG" "$PLAN_FILE"
else
    runner_extract_plotting_plan "$PLANNER_LOG" "$PLAN_FILE"
fi

if [ ! -s "$PLAN_FILE" ]; then
    echo
    echo "Errore: non ho trovato azioni valide nel log ENHSP."
    echo "Righe utili dal log:"
    grep -Ei "plan|solution|solved|unsolvable|goal|error|exception|total-block|metric" "$PLANNER_LOG" || true
    exit 1
fi

echo
echo "Piano estratto in: $PLAN_FILE"
cat "$PLAN_FILE"

if [ "$VALIDATE_PLANS" != "1" ]; then
    {
        echo "Validation skipped (VALIDATE_PLANS=$VALIDATE_PLANS)."
        echo "Plan not checked with VAL."
    } > "$VAL_LOG"
    echo
    cat "$VAL_LOG"
    exit 0
fi

echo
echo "Validazione con VAL..."

VAL_DOMAIN="$DOMAIN"
VAL_PROBLEM="$PROBLEM"
VAL_PLAN="$PLAN_FILE"
if [ "$PDDL_MODEL" = "granular" ]; then
    VAL_INPUT_DIR="$WORK_DIR/val-input"
    runner_prepare_val_compatible_inputs "$DOMAIN" "$PROBLEM" "$PLAN_FILE" "$VAL_INPUT_DIR"
    VAL_DOMAIN="$VAL_INPUT_DIR/domain.val.pddl"
    VAL_PROBLEM="$VAL_INPUT_DIR/problem.val.pddl"
    VAL_PLAN="$VAL_INPUT_DIR/plan.val"
fi

set +e
validate "$VAL_DOMAIN" "$VAL_PROBLEM" "$VAL_PLAN" > "$VAL_LOG" 2>&1
VAL_EXIT=$?
set -e

cat "$VAL_LOG"

if grep -qi "Plan valid" "$VAL_LOG"; then
    echo
    echo "OK: piano valido"
    exit 0
fi

echo
echo "Errore: piano non valido oppure VAL non ha confermato 'Plan valid'"
echo "Exit code VAL: $VAL_EXIT"
exit 1
