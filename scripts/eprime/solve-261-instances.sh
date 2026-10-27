#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
EPRIME_ROOT="$PROJECT_ROOT/benchmarks/eprime"
INSTANCE_LIST="$PROJECT_ROOT/benchmarks/manifests/sample-instances.txt"
INSTANCE_DIR="$EPRIME_ROOT/instances"
DOCKERFILE="$PROJECT_ROOT/docker/eprime.Dockerfile"
EPRIME_IMAGE="${EPRIME_IMAGE:-chuffed-savilerow:1.10.0}"
MODEL_FAMILY="${EPRIME_MODEL_FAMILY:-default-models}"
BACKEND="${EPRIME_BACKEND:-chuffed}"
MODEL_OVERRIDE="${CHUFFED_MODEL:-}"
BUILD_IMAGE=0
MEMORY_LIMIT="${EPRIME_MEMORY:-16g}"
TIMEOUT_SECONDS="${EPRIME_TIMEOUT_SECONDS:-900}"
POSITIONAL=()

usage() {
    cat <<EOF
Usage: $(basename "$0") [s|sa] [deadend|empty|monochrome|nosymm|symm] [options]
  --backend NAME       chuffed or sat (default: chuffed)
  --model PATH         Explicit .eprime model
  --model-family NAME  Model directory (default: default-models)
  --memory SIZE        RAM limit (default: 16g)
  --timeout SEC        Time budget per problem (default: 900)
  --build              Build Docker image
EOF
}

while (($# > 0)); do
    case "$1" in
        --build)
            BUILD_IMAGE=1
            ;;
        --backend)
            if (($# < 2)); then
                echo "Missing value for --backend" >&2
                exit 2
            fi
            BACKEND="$2"
            shift
            ;;
        --model)
            if (($# < 2)); then
                echo "Missing value for --model" >&2
                exit 2
            fi
            MODEL_OVERRIDE="$2"
            shift
            ;;
        --model-family)
            if (($# < 2)); then
                echo "Missing value for --model-family" >&2
                exit 2
            fi
            MODEL_FAMILY="$2"
            shift
            ;;
        --memory|--ram)
            if (($# < 2)); then
                echo "Missing value for $1" >&2
                exit 2
            fi
            MEMORY_LIMIT="$2"
            shift
            ;;
        --timeout)
            if (($# < 2)); then
                echo "Missing value for --timeout" >&2
                exit 2
            fi
            TIMEOUT_SECONDS="$2"
            shift
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            POSITIONAL+=("$1")
            ;;
    esac
    shift
done

case "$BACKEND" in
    chuffed) SOLVER_ARGS=(-chuffed -run-solver) ;;
    sat) SOLVER_ARGS=(-sat -sat-family kissat -run-solver) ;;
    *)
        echo "Unsupported backend: $BACKEND" >&2
        exit 2
        ;;
esac

if ((${#POSITIONAL[@]} > 2)); then
    echo "Too many arguments: ${POSITIONAL[*]}" >&2
    usage >&2
    exit 2
fi
if [[ -n "$MODEL_OVERRIDE" && ${#POSITIONAL[@]} -gt 0 ]]; then
    echo "Do not combine MODEL/CONSTRAINTS with --model or CHUFFED_MODEL" >&2
    exit 2
fi
if [[ -z "$MODEL_OVERRIDE" ]]; then
    EPRIME_MODEL="${POSITIONAL[0]:-${EPRIME_MODEL:-}}"
    if [[ -z "$EPRIME_MODEL" && -t 0 ]]; then
        read -r -p "Modello EPrime (s/sa): " EPRIME_MODEL
    else
        EPRIME_MODEL="${EPRIME_MODEL:-sa}"
    fi
    CONSTRAINTS="${POSITIONAL[1]:-${EPRIME_CONSTRAINTS:-}}"
    if [[ -z "$CONSTRAINTS" && -t 0 ]]; then
        read -r -p "Vincoli (deadend/empty/monochrome/nosymm/symm): " CONSTRAINTS
    else
        CONSTRAINTS="${CONSTRAINTS:-nosymm}"
    fi
    case "$EPRIME_MODEL" in
        s|sa) ;;
        *)
            echo "Unsupported EPrime model: $EPRIME_MODEL (allowed: s, sa)" >&2
            exit 2
            ;;
    esac
    case "$CONSTRAINTS" in
        deadend|empty|monochrome|nosymm|symm) ;;
        *)
            echo "Unsupported constraints: $CONSTRAINTS (allowed: deadend, empty, monochrome, nosymm, symm)" >&2
            exit 2
            ;;
    esac
    case "$MODEL_FAMILY" in
        ""|.|..|*/*)
            echo "Invalid model family: $MODEL_FAMILY" >&2
            exit 2
            ;;
    esac
    MODEL_RELATIVE="models/$MODEL_FAMILY/plotting_${EPRIME_MODEL}_${CONSTRAINTS}.eprime"
    RUN_NAME="$EPRIME_MODEL-$CONSTRAINTS"
else
    case "$MODEL_OVERRIDE" in
        /*|../*|*/../*|*/..|*//*)
            echo "Invalid model path: $MODEL_OVERRIDE" >&2
            exit 2
            ;;
        *.eprime) ;;
        *)
            echo "The model path must end in .eprime: $MODEL_OVERRIDE" >&2
            exit 2
            ;;
    esac
    MODEL_RELATIVE="$MODEL_OVERRIDE"
    MODEL_FAMILY="$(basename "$(dirname "$MODEL_RELATIVE")")"
    if [[ "$MODEL_FAMILY" == "." ]]; then
        MODEL_FAMILY="custom"
    fi
    RUN_NAME="$(basename "$MODEL_RELATIVE" .eprime)"
    RUN_NAME="${RUN_NAME#plotting_}"
    RUN_NAME="${RUN_NAME//_/-}"
fi

OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT/results/eprime/$BACKEND/$MODEL_FAMILY/$RUN_NAME}"
case "$OUTPUT_DIR" in
    */../*|*/..)
        echo "OUTPUT_DIR cannot contain '..': $OUTPUT_DIR" >&2
        exit 2
        ;;
    /*) ;;
    *) OUTPUT_DIR="$PROJECT_ROOT/$OUTPUT_DIR" ;;
esac
case "$OUTPUT_DIR" in
    "$PROJECT_ROOT"/*) ;;
    *)
        echo "OUTPUT_DIR must be inside the mounted project: $PROJECT_ROOT" >&2
        exit 2
        ;;
esac
LOG_DIR="$OUTPUT_DIR/logs"
SOLUTION_DIR="$OUTPUT_DIR/solutions"
if [[ ! -f "$INSTANCE_LIST" ]]; then
    echo "Instance list not found: $INSTANCE_LIST" >&2
    exit 1
fi
if [[ ! -f "$DOCKERFILE" ]]; then
    echo "Dockerfile not found: $DOCKERFILE" >&2
    exit 1
fi
if [[ ! -f "$EPRIME_ROOT/$MODEL_RELATIVE" ]]; then
    echo "Essence Prime model not found: $EPRIME_ROOT/$MODEL_RELATIVE" >&2
    exit 1
fi
if [[ ! "$TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Timeout must be a positive number of seconds: $TIMEOUT_SECONDS" >&2
    exit 2
fi
if [[ -n "$MEMORY_LIMIT" && ! "$MEMORY_LIMIT" =~ ^[1-9][0-9]*[kKmMgGtT]?$ ]]; then
    echo "Invalid memory limit: $MEMORY_LIMIT (examples: 8g, 12000m)" >&2
    exit 2
fi
if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is required but was not found in PATH." >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR" "$LOG_DIR" "$SOLUTION_DIR"
if ((BUILD_IMAGE)); then
    docker build \
        --tag "$EPRIME_IMAGE" \
        --file "$DOCKERFILE" \
        "$PROJECT_ROOT/docker"
fi

DOCKER_USER="${LOCAL_UID:-$(id -u)}:${LOCAL_GID:-$(id -g)}"
docker_memory_args=()
if [[ -n "$MEMORY_LIMIT" ]]; then
    docker_memory_args=(--memory "$MEMORY_LIMIT" --memory-swap "$MEMORY_LIMIT")
fi

CSV_FILE="$OUTPUT_DIR/stats.csv"
if [[ ! -s "$CSV_FILE" ]]; then
    printf '%s\n' 'problem,step,status,attempt_runtime_sec,cumulative_runtime_sec,solver_runtime_sec,savilerow_runtime_sec,exit_code,param_file,log_file,solution_file' > "$CSV_FILE"
fi

WORK_DIR="$(mktemp -d "$OUTPUT_DIR/.work.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

total=0
solved=0
failed=0
missing=0

while IFS= read -r problem || [[ -n "$problem" ]]; do
    [[ -z "$problem" ]] && continue
    [[ "$problem" == \#* ]] && continue
    if [[ ! "$problem" =~ ^[A-Za-z0-9_.-]+$ ]]; then
        echo "Invalid problem name in list: $problem" >&2
        exit 1
    fi
    problem_log="$LOG_DIR/$problem.log"
    if awk -F',' -v p="\"$problem\"" '$1 == p && $3 == "\"solved\"" { found=1 } END { exit !found }' "$CSV_FILE"; then
        echo "[$problem] Already solved; skipping"
        continue
    fi
    IFS=_ read -r seed rows cols goal suffix <<< "${problem#plt}"
    if [[ ! "$rows" =~ ^[0-9]+$ || ! "$cols" =~ ^[0-9]+$ || ! "$goal" =~ ^[0-9]+$ ]]; then
        echo "Invalid instance name (expected pltSEED_ROWS_COLS_GOAL): $problem" >&2
        exit 1
    fi
    max_steps=$((rows * cols - goal))
    if ((max_steps < 1)); then
        echo "[$problem] Invalid step range: board area minus goal is $max_steps" >&2
        exit 1
    fi
    group_solved=0
    group_attempted=0
    cumulative_seconds=0
    problem_start_ns=$(date +%s%N)
    problem_deadline_ns=$((problem_start_ns + TIMEOUT_SECONDS * 1000000000))
    for ((step=1; step<=max_steps; step++)); do
        param_file="${problem}_${step}.param"
        param_path="$INSTANCE_DIR/$param_file"
        [[ -f "$param_path" ]] || continue
        remaining_ns=$((problem_deadline_ns - $(date +%s%N)))
        if ((remaining_ns <= 0)); then
            break
        fi
        remaining_seconds="$(awk -v ns="$remaining_ns" 'BEGIN { printf "%.3f", ns / 1000000000 }')"
        ((group_attempted += 1))
        step_dir="$WORK_DIR/$problem/step-$step"
        mkdir -p "$step_dir"
        local_param_path="$step_dir/$param_file"
        info_file="$local_param_path.info"
        cp "$param_path" "$local_param_path"
        container_workdir="/app/${step_dir#"$PROJECT_ROOT"/}"
        echo "[$problem] Solving noSteps=$step (${remaining_seconds}s remaining${MEMORY_LIMIT:+, RAM $MEMORY_LIMIT})"
        printf '\n===== noSteps=%s | remaining budget=%ss =====\n' "$step" "$remaining_seconds" >> "$problem_log"
        start_ns=$(date +%s%N)
        set +e
        docker run --rm \
            --user "$DOCKER_USER" \
            --volume "$PROJECT_ROOT:/app" \
            --workdir "$container_workdir" \
            "${docker_memory_args[@]}" \
            "$EPRIME_IMAGE" \
            sh -c 'deadline=$1; shift; remaining_ns=$((deadline - $(date +%s%N) - 100000000)); if [ "$remaining_ns" -le 0 ]; then exit 124; fi; remaining=$(awk -v ns="$remaining_ns" '\''BEGIN { printf "%.3fs", ns / 1000000000 }'\''); exec timeout --signal=TERM --kill-after=10s "$remaining" "$@"' \
            sh "$problem_deadline_ns" savilerow "/app/benchmarks/eprime/$MODEL_RELATIVE" "$param_file" \
                "${SOLVER_ARGS[@]}" < /dev/null >> "$problem_log" 2>&1
        status=$?
        end_ns=$(date +%s%N)
        attempt_seconds="$(awk -v s="$start_ns" -v e="$end_ns" 'BEGIN { printf "%.3f", (e - s) / 1000000000 }')"
        cumulative_seconds="$(awk -v s="$problem_start_ns" -v e="$end_ns" 'BEGIN { printf "%.3f", (e - s) / 1000000000 }')"
        if ((status == 124 || status == 137)); then
            attempt_status=timeout
        elif [[ -f "$info_file" ]] && grep -q '^SolverSatisfiable:1$' "$info_file"; then
            attempt_status=solved
        elif ((status == 0)) && [[ -f "$info_file" ]] && grep -q '^SolverSatisfiable:0$' "$info_file"; then
            attempt_status=unsolved
        else
            attempt_status=error
        fi
        solver_seconds="$(awk -F: '$1 == "SolverTotalWallTime" {print $2; exit}' "$info_file" 2>/dev/null || :)"
        savilerow_seconds="$(awk -F: '$1 == "SavileRowTotalTime" {print $2; exit}' "$info_file" 2>/dev/null || :)"
        if [[ "$attempt_status" != solved ]] && ((end_ns >= problem_deadline_ns)); then
            attempt_status=timeout
        fi
        solution_file=""
        if [[ "$attempt_status" == solved ]]; then
            generated_solution="$step_dir/$param_file.solution"
            if [[ -f "$generated_solution" ]]; then
                solution_file="$SOLUTION_DIR/$problem.solution"
                cp "$generated_solution" "$solution_file"
            fi
        fi
        printf '"%s",%s,"%s",%s,%s,"%s","%s",%s,"%s","%s","%s"\n' \
            "$problem" "$step" "$attempt_status" "$attempt_seconds" "$cumulative_seconds" \
            "$solver_seconds" "$savilerow_seconds" "$status" "$param_file" "$problem_log" "$solution_file" >> "$CSV_FILE"
        if [[ "$attempt_status" == solved ]]; then
            echo "[$problem] Solved at noSteps=$step after ${cumulative_seconds}s total"
            group_solved=1
            break
        fi
        if [[ "$attempt_status" == timeout ]]; then
            break
        fi
        if [[ "$attempt_status" == error ]]; then
            echo "[$problem] Failed at noSteps=$step (exit $status); see $problem_log" >&2
        fi
    done
    ((total += 1))
    if ((group_attempted == 0)); then
        printf '"%s",,"missing",0,0,,,,"","%s",""\n' "$problem" "$problem_log" >> "$CSV_FILE"
        ((missing += 1))
        echo "[$problem] No .param candidates found"
    elif ((group_solved)); then
        ((solved += 1))
    else
        ((failed += 1))
    fi
done < "$INSTANCE_LIST"

cat <<EOF
Completed.
Problems: $total
Successful: $solved
Failed: $failed
Problems without parameters: $missing
Results: $OUTPUT_DIR
CSV: $CSV_FILE
EOF
((failed == 0 && missing == 0))
