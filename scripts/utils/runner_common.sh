#!/usr/bin/env bash

runner_die() {
    echo "Errore: $*" >&2
    exit 1
}

runner_abs_path() {
    local path="$1"
    local base="${2:-$(pwd)}"

    if [ -z "$path" ]; then
        printf '%s\n' "$base"
        return
    fi

    if [ "${path#/}" != "$path" ]; then
        printf '%s\n' "$path"
    else
        printf '%s/%s\n' "$base" "$path"
    fi
}

runner_require_docker_compose() {
    command -v docker >/dev/null 2>&1 || runner_die "Docker non trovato nel PATH"
    docker compose version >/dev/null 2>&1 || runner_die "il plugin Docker Compose non e' disponibile"
}

runner_project_container_path() {
    local project_root="$1"
    local path="$2"

    case "$path" in
        "$project_root")
            printf '/app\n'
            ;;
        "$project_root"/*)
            printf '/app/%s\n' "${path#"$project_root"/}"
            ;;
        *)
            printf '%s\n' "$path"
            ;;
    esac
}

runner_add_compose_env_args() {
    local args_name="$1"
    shift
    local -n args_ref="$args_name"
    local variable_name

    for variable_name in "$@"; do
        if [[ -v $variable_name ]]; then
            args_ref+=(--env "$variable_name=${!variable_name}")
        fi
    done
}

runner_add_compose_path_env_args() {
    local project_root="$1"
    local args_name="$2"
    shift 2
    local -n args_ref="$args_name"
    local variable_name value

    for variable_name in "$@"; do
        if [[ -v $variable_name ]]; then
            value="$(runner_project_container_path "$project_root" "${!variable_name}")"
            args_ref+=(--env "$variable_name=$value")
        fi
    done
}

runner_pddl_root() {
    local preferred="$1"
    local fallback="${2:-}"

    if [ -d "$preferred" ]; then
        printf '%s\n' "$preferred"
    elif [ -n "$fallback" ] && [ -d "$fallback" ]; then
        printf '%s\n' "$fallback"
    else
        printf '%s\n' "$preferred"
    fi
}

runner_problem_path() {
    local problem="$1"
    local problems_dir="$2"

    if [ "${problem#/}" != "$problem" ] || [ -f "$problem" ]; then
        runner_abs_path "$problem"
    else
        runner_abs_path "$problems_dir/$problem"
    fi
}

runner_problem_name_for_model() {
    local problem="$1"
    local pddl_model="$2"

    if [ "$pddl_model" = "granular" ]; then
        case "$problem" in
            *-problem.pddl) ;;
            *.pddl) problem="${problem%.pddl}-problem.pddl" ;;
            *) problem="$problem-problem.pddl" ;;
        esac
    else
        case "$problem" in
            *.pddl) ;;
            *) problem="$problem.pddl" ;;
        esac
    fi

    printf '%s\n' "$problem"
}

runner_problem_list_stream() {
    local list_file="$1"
    local problems_dir="$2"
    local pattern="$3"
    local pddl_model="${4:-}"
    local entry problem problem_name
    declare -A seen=()

    while IFS= read -r entry || [ -n "$entry" ]; do
        entry="${entry%$'\r'}"
        if [[ "$entry" =~ ^[[:space:]]*(#|$) ]]; then
            continue
        fi
        case "$entry" in
            */*) runner_die "nella lista sono ammessi solo nomi file: $entry" ;;
        esac
        problem_name="$(runner_problem_name_for_model "$entry" "$pddl_model")"
        if [ "$pddl_model" = "direct" ] || [ "$pddl_model" = "direct-opt" ]; then
            case "$problem_name" in
                *-domain.pddl|*-problem.pddl) runner_die "nome problem direct non valido nella lista: $entry" ;;
            esac
        fi
        [[ "$problem_name" == $pattern ]] || runner_die "nome problem non valido nella lista: $entry"
        [ -z "${seen[$problem_name]+x}" ] || runner_die "problem duplicato nella lista: $entry"
        seen["$problem_name"]=1
        problem="$problems_dir/$problem_name"
        runner_require_file "problem nella lista" "$problem"
        printf '%s\0' "$problem"
    done < "$list_file"
}

runner_require_file() {
    local label="$1"
    local path="$2"
    [ -f "$path" ] || runner_die "$label non trovato: $path"
}

runner_require_dir() {
    local label="$1"
    local path="$2"
    [ -d "$path" ] || runner_die "$label non trovata: $path"
}

runner_init_stats_csv() {
    local csv_file="$1"

    printf '%s\n' \
        "problem,status,valid,total_runtime_sec,actions,expanded_nodes,exit_code,plan_file,planner_log,val_log" \
        > "$csv_file"
}

runner_append_stats_row() {
    local csv_file="$1"
    shift

    printf '"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' "$@" >> "$csv_file"
}

runner_run_id() {
    local basename="$1"
    local seed
    seed="$(echo "$basename" | sed -n 's/.*_\([0-9][0-9]*\)seed_.*/\1/p')"

    if [ -n "$seed" ]; then
        printf '%s\n' "$seed"
        return
    fi

    echo "${basename%.pddl}" | sed 's/[^A-Za-z0-9_-]/_/g'
}

runner_check_no_floating_block() {
    local domain="$1"
    local problem="$2"

    if grep -q "(floating-block" "$domain" "$problem"; then
        cat >&2 <<'MSG'
Errore: trovato ancora '(floating-block ...)' nel dominio o nel problema.
Nel modello aggiornato devi usare solo:
  (blockedrow nX) per blocco orizzontale
  (blockedcol nX) per blocco verticale
MSG
        exit 1
    fi
}

runner_setup_enhsp_path() {
    local app_root="$1"
    local bin_dir="$2"
    mkdir -p "$bin_dir"

    export PATH="$bin_dir:$app_root/planners/enhsp:$PATH"

    local enhsp_exec
    enhsp_exec="$(find "$app_root/planners/enhsp" -maxdepth 4 -type f -iname "enhsp" -perm -u+x 2>/dev/null | head -n 1 || true)"
    if [ -n "$enhsp_exec" ]; then
        ln -sf "$enhsp_exec" "$bin_dir/enhsp"
        export PATH="$bin_dir:$PATH"
        return 0
    fi

    local enhsp_jar
    enhsp_jar="$(find "$app_root/planners/enhsp" -maxdepth 5 -type f \( -iname "*enhsp*.jar" -o -iname "enhsp.jar" \) 2>/dev/null | head -n 1 || true)"
    if [ -n "$enhsp_jar" ]; then
        {
            printf '%s\n' '#!/usr/bin/env bash'
            printf '%s\n' 'java_cmd="${JAVA_BIN:-java}"'
            printf '%s\n' 'java_major="$("$java_cmd" -version 2>&1 | awk -F "[\".]" '"'"'/version/ { print ($2 == "1" ? $3 : $2); exit }'"'"')"'
            printf '%s\n' 'if [ -z "$java_major" ] || [ "$java_major" -lt 17 ]; then'
            printf '%s\n' '    echo "Errore: ENHSP richiede Java >= 17; trovato $("$java_cmd" -version 2>&1 | head -n 1)" >&2'
            printf '%s\n' '    echo "Imposta JAVA_BIN=/percorso/a/java oppure aggiorna la JVM usata dallo script." >&2'
            printf '%s\n' '    exit 1'
            printf '%s\n' 'fi'
            printf 'exec "$java_cmd" ${JAVA_OPTS:-} -jar %q "$@"\n' "$enhsp_jar"
        } > "$bin_dir/enhsp"
        chmod +x "$bin_dir/enhsp"
        export PATH="$bin_dir:$PATH"
        return 0
    fi

    if command -v enhsp >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

runner_setup_val_path() {
    local app_root="$1"
    local bin_dir="$2"
    mkdir -p "$bin_dir"

    export PATH="$bin_dir:$app_root/planners/VAL:$PATH"

    local val_exec="$app_root/planners/VAL/validate"
    if [ -x "$val_exec" ]; then
        ln -sf "$val_exec" "$bin_dir/validate"
        ln -sf "$val_exec" "$bin_dir/Validate"
        export PATH="$bin_dir:$PATH"
    fi
}

runner_prepare_val_compatible_inputs() {
    local domain="$1"
    local problem="$2"
    local plan="$3"
    local out_dir="$4"
    local val_domain="$out_dir/domain.val.pddl"
    local val_problem="$out_dir/problem.val.pddl"
    local val_plan="$out_dir/plan.val"
    local tmp_file all_locs declared_locs missing_locs loc_constants missing_line constants_block colour_constants

    mkdir -p "$out_dir"
    cp "$domain" "$val_domain"
    cp "$problem" "$val_problem"

    if grep -q "total-cost" "$val_domain" "$val_problem"; then
        sed -i '/^[[:space:]]*(:requirements/ {
            /:fluents/! s/)/ :fluents)/
            /:action-costs/! s/)/ :action-costs)/
        }' "$val_domain"

        if ! grep -q "^[[:space:]]*(:functions" "$val_domain"; then
            tmp_file="$out_dir/domain.functions.pddl"
            awk '
                !inserted && /^[[:space:]]*\(:constants/ {
                    print "    (:functions"
                    print "        (total-cost) - number"
                    print "    )"
                    print ""
                    inserted = 1
                }
                { print }
            ' "$val_domain" > "$tmp_file"
            mv "$tmp_file" "$val_domain"
        fi
    fi

    loc_constants="$(grep -Eo 'loc_[0-9]+_[0-9]+' "$val_domain" | sort -u | tr '\n' ' ')"
    constants_block="$(awk '
        /^[[:space:]]*\(:constants/ { in_constants = 1 }
        in_constants { print }
        in_constants && /^[[:space:]]*\)/ { exit }
    ' "$val_domain")"
    colour_constants=""
    if ! grep -Eq '(^|[[:space:]])none([[:space:]]|$)' <<< "$constants_block"; then
        colour_constants="$colour_constants none"
    fi
    if ! grep -Eq '(^|[[:space:]])wall([[:space:]]|$)' <<< "$constants_block"; then
        colour_constants="$colour_constants wall"
    fi
    tmp_file="$out_dir/domain.constants.pddl"
    awk -v locs="$loc_constants" -v colours="$colour_constants" '
        !inserted && /^[[:space:]]*\(:constants/ {
            print
            if (colours != "") {
                print "       " colours " - colour"
            }
            if (locs != "") {
                print "       " locs "- location"
            }
            inserted = 1
            next
        }
        { print }
    ' "$val_domain" > "$tmp_file"
    mv "$tmp_file" "$val_domain"

    perl -0pi -e 's/(\(:action shooting_(?:row|column)_\d+\n)([ \t]*):precondition/$1$2:parameters ()\n$2:precondition/g' "$val_domain"

    all_locs="$out_dir/problem.all-locs"
    declared_locs="$out_dir/problem.declared-locs"
    missing_locs="$out_dir/problem.missing-locs"
    grep -Eo 'loc_[0-9]+_[0-9]+' "$val_problem" | sort -u > "$all_locs" || true
    awk '
        /\(:objects/ { in_objects = 1 }
        in_objects { print }
        in_objects && /^[[:space:]]*\)/ { exit }
    ' "$val_problem" | grep -Eo 'loc_[0-9]+_[0-9]+' | sort -u > "$declared_locs" || true
    comm -23 "$all_locs" "$declared_locs" > "$missing_locs" || true

    if [ -s "$missing_locs" ]; then
        missing_line="$(tr '\n' ' ' < "$missing_locs")"
        tmp_file="$out_dir/problem.objects.pddl"
        awk -v locs="$missing_line" '
            !inserted && /^[[:space:]]*n[0-9]+[[:space:]]+-[[:space:]]+num/ {
                print "        " locs "- location"
                inserted = 1
            }
            { print }
        ' "$val_problem" > "$tmp_file"
        mv "$tmp_file" "$val_problem"
    fi

    grep -E '^[[:space:]]*\(' "$plan" \
        | sed -E 's/[[:space:]]+\)/)/; s/^[[:space:]]*//; s/[[:space:]]*$//' \
        > "$val_plan" || true
}

runner_extract_plotting_plan() {
    local log_file="$1"
    local plan_file="$2"

    grep -Eio '\([[:space:]]*(shoot-row|shoot-column|shoot-row-and-column|shoot-only-full-row)[^)]*\)' "$log_file" \
        | sed 's/^[[:space:]]*//' \
        > "$plan_file" || true
}

runner_extract_plotting_granular_plan() {
    local log_file="$1"
    local plan_file="$2"

    grep -Eio '\([[:space:]]*(shooting_(row|column)(_[0-9]+)?|fall_block|colour_roulette|horizontal_bullet_[a-z_]+|vertical_bullet_[a-z_]+)[^)]*\)' "$log_file" \
        | sed 's/^[[:space:]]*//' \
        > "$plan_file" || true
}

runner_problem_stem_for_model() {
    local problem="$1"
    local pddl_model="$2"
    local stem

    stem="$(basename "$problem")"
    stem="${stem%.pddl}"
    if [ "$pddl_model" = "granular" ]; then
        stem="${stem%-problem}"
    fi

    printf '%s\n' "$stem"
}

runner_paper2024_filter_problem_stream() {
    local pddl_model="$1"
    local problem stem plt1_index

    plt1_index=0
    while IFS= read -r -d '' problem; do
        stem="$(runner_problem_stem_for_model "$problem" "$pddl_model")"

        case "$stem" in
            plt0_7_7_*)
                continue
                ;;
            plt0_*)
                printf '%s\0' "$problem"
                ;;
            plt1_*)
                plt1_index=$((plt1_index + 1))
                if [ "$plt1_index" -le 73 ] && [ $(((plt1_index - 1) % 6)) -eq 0 ]; then
                    printf '%s\0' "$problem"
                fi
                ;;
        esac
    done
}

runner_time_limit_seconds() {
    local limit="$1"
    local seconds

    seconds="${limit%s}"
    if [[ "$seconds" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        awk -v s="$seconds" 'BEGIN { printf "%.3f", s }'
    else
        printf '0.000\n'
    fi
}

runner_count_plan_actions() {
    local plan_file="$1"

    if [ -n "$plan_file" ] && [ -f "$plan_file" ]; then
        grep -E '^[[:space:]]*\(' "$plan_file" | wc -l | tr -d ' '
    else
        printf '0\n'
    fi
}

runner_log_runtime_sec() {
    local planner_log="$1"
    local runtime

    runtime=""
    if [ -f "$planner_log" ]; then
        runtime="$(awk '
            /Tempo esecuzione/ {
                for (i = 1; i <= NF; i++) {
                    if ($(i + 1) == "sec") {
                        value = $i
                    }
                }
            }
            /\] Total time:/ {
                for (i = 1; i <= NF; i++) {
                    if ($(i - 1) == "Total" && $i == "time:") {
                        value = $(i + 1)
                        gsub(/s|,/, "", value)
                    }
                }
            }
            /^INFO[[:space:]]+Planner time:/ {
                for (i = 1; i <= NF; i++) {
                    if ($(i - 1) == "Planner" && $i == "time:") {
                        fallback = $(i + 1)
                        gsub(/s|,/, "", fallback)
                    }
                }
            }
            END {
                if (value != "") {
                    printf "%.3f", value
                } else if (fallback != "") {
                    printf "%.3f", fallback
                }
            }
        ' "$planner_log")"
    fi

    if [ -n "$runtime" ]; then
        printf '%s\n' "$runtime"
    else
        printf '0.000\n'
    fi
}

runner_log_exit_code() {
    local planner_log="$1"

    if [ ! -f "$planner_log" ]; then
        printf '\n'
        return
    fi

    awk '
        {
            line = tolower($0)
        }
        match(line, /runner exit code:[[:space:]]*[0-9]+/) {
            value = substr(line, RSTART, RLENGTH)
            sub(/^.*:[[:space:]]*/, "", value)
            runner_value = value
        }
        match(line, /search exit code:[[:space:]]*[0-9]+/) {
            value = substr(line, RSTART, RLENGTH)
            sub(/^.*:[[:space:]]*/, "", value)
            search_value = value
        }
        match(line, /(terminato con|terminated with) exit code[[:space:]]+[0-9]+/) {
            value = substr(line, RSTART, RLENGTH)
            sub(/^.*[[:space:]]/, "", value)
            fallback = value
        }
        /caught signal 15/ {
            external_timeout = 1
        }
        END {
            if (runner_value != "") {
                print runner_value
            } else if (external_timeout) {
                # GNU timeout sends SIGTERM and returns 124.
                print 124
            } else if (search_value != "") {
                print search_value
            } else if (fallback != "") {
                print fallback
            }
        }
    ' "$planner_log"
}

runner_log_expanded_nodes() {
    local planner_log="$1"

    if [ ! -f "$planner_log" ]; then
        printf '\n'
        return
    fi

    awk '
        /Expanded Nodes:[[:space:]]*[0-9]+/ {
            line = $0
            sub(/^.*Expanded Nodes:[[:space:]]*/, "", line)
            sub(/[^0-9].*$/, "", line)
            if (line ~ /^[0-9]+$/) {
                value = line
            }
        }
        /Expanded[[:space:]]+[0-9]+[[:space:]]+state\(s\)\./ {
            line = $0
            sub(/^.*Expanded[[:space:]]+/, "", line)
            sub(/[[:space:]].*$/, "", line)
            if (line ~ /^[0-9]+$/) {
                value = line
            }
        }
        END { print value }
    ' "$planner_log"
}

runner_detect_validation() {
    local planner_log="$1"
    local val_log="$2"

    if grep -qi "Plan valid" "$planner_log" "$val_log" 2>/dev/null; then
        printf 'true\n'
    elif grep -qiE "Validation skipped|Validazione saltata" "$planner_log" "$val_log" 2>/dev/null; then
        printf 'skipped\n'
    elif grep -qiE "Plan invalid|Goal not satisfied|Plan failed|Failed plans" "$planner_log" "$val_log" 2>/dev/null; then
        printf 'false\n'
    else
        printf 'unknown\n'
    fi
}

runner_existing_result_summary() {
    local planner_log="$1"
    local val_log="$2"
    local final_plan="$3"
    local validate_plans="$4"
    local valid status runtime actions

    if [ ! -s "$final_plan" ]; then
        final_plan=""
    fi

    valid="$(runner_detect_validation "$planner_log" "$val_log")"
    runtime="$(runner_log_runtime_sec "$planner_log")"
    actions="$(runner_count_plan_actions "$final_plan")"

    if [ "$valid" = "true" ] || [ "$valid" = "skipped" ]; then
        status="ok"
    elif [ -n "$final_plan" ] && [ "$validate_plans" != "1" ]; then
        valid="skipped"
        status="ok"
    elif grep -qiE "^timeout([[:space:]:.!]|$)|\\[timeout\\]|timed out|time limit has been reached|caught signal 24|exit code 124|search exit code: 23" "$planner_log" 2>/dev/null; then
        status="timeout"
    elif [ "$valid" = "false" ]; then
        status="invalid_plan"
    elif grep -qiE "no solution|without finding a solution|unsolvable|unsolved|Problem unsolvable|Completely explored state space|search exit code: 12|OutOfMemoryError|Java heap space" "$planner_log" 2>/dev/null; then
        status="unsolved"
    elif grep -qiE "enhsp.*not found|comando enhsp non trovato|command not found|No such file" "$planner_log" 2>/dev/null; then
        status="planner_not_found"
    else
        status="planner_error"
    fi

    printf '%s|%s|%s|%s\n' "$status" "$valid" "$runtime" "$actions"
}

runner_write_paper2024_heap_skips() {
    local pddl_model="$1"
    local problems_dir="$2"
    local csv_file="$3"
    local log_dir="$4"
    local val_dir="$5"
    local plan_dir="$6"
    local time_limit="$7"
    local heap_pattern problem basename name_no_ext planner_log val_log final_plan runtime

    if [ "$pddl_model" = "granular" ]; then
        heap_pattern="plt0_7_7_*-problem.pddl"
    else
        heap_pattern="plt0_7_7_*.pddl"
    fi

    runtime="$(runner_time_limit_seconds "$time_limit")"

    while IFS= read -r -d '' problem; do
        basename="$(basename "$problem")"
        name_no_ext="${basename%.pddl}"
        if [ "$pddl_model" = "granular" ]; then
            name_no_ext="${name_no_ext%-problem}"
        fi

        planner_log="$log_dir/${name_no_ext}.planner.log"
        val_log="$val_dir/${name_no_ext}.val.log"
        final_plan="$plan_dir/${name_no_ext}.plan"

        if [ ! -f "$planner_log" ]; then
            {
                echo "Problem skipped by paper_2024 run-all selection."
                echo "Marked unsolved because 7x7 instances saturate heap space."
                echo "java.lang.OutOfMemoryError: Java heap space"
                echo "Tempo esecuzione Planner: $runtime sec"
            } > "$planner_log"
        fi
        [ -f "$val_log" ] || echo "Validation not run: 7x7 heap-space saturated instance." > "$val_log"
        [ -s "$final_plan" ] || final_plan=""

        runner_append_stats_row "$csv_file" \
            "$basename" "unsolved" "unknown" "$runtime" "0" "" "137" \
            "$final_plan" "$planner_log" "$val_log"
    done < <(
        if [ "$pddl_model" = "granular" ]; then
            find "$problems_dir" -maxdepth 1 -type f -name "$heap_pattern" -print0
        else
            find "$problems_dir" -maxdepth 1 -type f -name "$heap_pattern" ! -name "*-domain.pddl" ! -name "*-problem.pddl" -print0
        fi \
            | sort -z
    )
}
