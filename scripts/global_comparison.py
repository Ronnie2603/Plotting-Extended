#!/usr/bin/env python3
"""
Generate all global comparisons for the completed Plotting runs.
"""

from __future__ import annotations

import csv
import json
import math
import re
import shutil
import statistics
import subprocess
import sys
from collections import Counter
from dataclasses import dataclass, replace
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "results/comparisons"
SAMPLE_MANIFEST = ROOT / "benchmarks/manifests/sample-instances.txt"
TIMEOUT = 900.0
ENCODING_LABELS = {"direct-base": "Direct base", "direct-new": "Direct new", "granular": "Granular"}
# New numeric model: keep the planner order and notation of the heuristic table.
HEURISTIC_COMPARISON_LABELS = {
    "direct-new-wastar-capacity": r"$A^*\! -\! h^{capacity}$",
    "direct-new-wastar-colour": r"$A^*\! -\! h^{colour}$",
    "direct-new-greedy-capacity": r"$GBFS\! -\! h^{capacity}$",
    "direct-new-greedy-colour": r"$GBFS\! -\! h^{colour}$",
}
# Planner comparison table: exclude Chuffed sa-deadend-v5 (commented-out row).
PLANNER_COMPARISON_LABELS = {
    "direct-new-wastar-blind": r"ENHSP $A^*$ — blind",
    "direct-new-wastar-colour": r"ENHSP $A^*$ — $h^{colour}$",
    "direct-new-greedy-hadd": r"ENHSP $GBFS$ — $h^{add}$",
    "direct-new-greedy-colour": r"ENHSP $GBFS$ — $h^{colour}$",
    "fdm": r"FD(m) $A^*$ — blind",
    "symk": "SymK — Bidirectional search",
    "eprime/sat/sat-finetune/sa-deadend-v5": "SAT — sa-deadend-v5",
    "eprime/chuffed/default-models/sa-nosymm": "Chuffed — sa-nosymm",
}
COMPARISON_LABELS = {
    "heuristic-comparison": HEURISTIC_COMPARISON_LABELS,
    "planner-comparison": PLANNER_COMPARISON_LABELS,
}
SOLVED_UNSOLVABLE_INSTANCES = frozenset({
    "plt2_5_5_4_3",
    "plt5_4_4_4_3",
})
# All runs are included, restricted to the shared benchmark sample.
EXCLUDED_PDDL_RUNS: set[str] = set()
ACTION = re.compile(r"^\s*(?:\d+(?:\.\d+)?\s*:\s*)?\(([\w-]+)\b", re.M)
METRICS = ("runtime", "search_time_ms", "expanded_nodes", "visited_nodes", "shots", "actions")
TITLES = {"runtime": "Runtime (s)", "search_time_ms": "Search (ms)", "expanded_nodes": "Expanded nodes",
          "visited_nodes": "Visited nodes", "shots": "Shots / plan cost",
          "actions": "PDDL actions"}


@dataclass(frozen=True)
class RunSpec:
    key: str
    label: str
    path: Path
    encoding: str
    source: str = "pddl"


@dataclass(frozen=True)
class Row:
    problem: str
    status: str
    valid: str
    runtime: float | None
    expanded_nodes: float | None
    shots: float | None
    actions: float | None
    cost_source: str
    source_status: str
    solved: bool
    visited_nodes: float | None = None
    search_time_ms: float | None = None
    peak_memory_kb: float | None = None
    # ENHSP's reported Heuristic Time (msec).
    heuristic_time_ms: float | None = None
    grounding_time_ms: float | None = None


def defaults() -> tuple[dict[str, RunSpec], dict[str, list[str]]]:
    results = ROOT / "results/pddl"
    known = {
        "enhsp/granular/greedy-colour": ("granular-colour", "Granular GBFS colour", "granular"),
        "enhsp/granular/greedy-hadd": ("granular-hadd", "Granular GBFS hadd", "granular"),
        "enhsp/granular/wastar-blind": ("granular-wastar-blind", "Granular WA* blind", "granular"),
        "enhsp/direct-base/greedy-colour-base": ("direct-base-greedy-colour", "Direct base GBFS colour", "direct-base"),
        "enhsp/direct-new/greedy-colour-new": ("direct-new-greedy-colour", "Direct new GBFS colour", "direct-new"),
        "enhsp/direct-base/greedy-hadd-base": ("direct-base-greedy-hadd", "Direct base GBFS hadd", "direct-base"),
        "enhsp/direct-base/wastar-colour-base": ("direct-base-wastar-colour", "Direct base WA* colour", "direct-base"),
        "enhsp/direct-base/wastar-blind-base": ("direct-base-wastar-blind", "Direct base WA* blind", "direct-base"),
        "enhsp/direct-new/wastar-blind-new": ("direct-new-wastar-blind", "Direct new WA* blind", "direct-new"),
        "enhsp/direct-new/wastar-colour-new": ("direct-new-wastar-colour", "Direct new WA* colour", "direct-new"),
        "enhsp/direct-new/wastar-capacity-new": ("direct-new-wastar-capacity", "Direct new WA* capacity", "direct-new"),
        "enhsp/direct-new/greedy-capacity-new": ("direct-new-greedy-capacity", "Direct new GBFS capacity", "direct-new"),
        "enhsp/direct-new/greedy-hadd-new": ("direct-new-greedy-hadd", "Direct new GBFS hadd", "direct-new"),
        "fast-downward/fdm-new-blind": ("fdm", "FD(m) blind", "granular"),
        "symk": ("symk", "SymK", "granular"),
    }
    specs = []
    stats_files = sorted(results.rglob("stats.csv")) if results.is_dir() else []
    for stats_file in stats_files:
        directory = stats_file.parent
        relative = directory.relative_to(results).as_posix()
        if relative in EXCLUDED_PDDL_RUNS:
            continue
        default_encoding = (
            directory.parent.name
            if relative.startswith("enhsp/") and directory.parent.name in ENCODING_LABELS
            else "unknown"
        )
        key, label, encoding = known.get(
            relative,
            (relative.replace("/", "-"), relative.replace("/", " / ").replace("-", " "), default_encoding),
        )
        if relative not in known and encoding in {"direct-base", "direct-new"}:
            configuration = directory.name.removesuffix("-new").removesuffix("-base").replace("-", " ")
            label = f"{ENCODING_LABELS[encoding]} / {configuration}"
        specs.append(RunSpec(key, label, directory, encoding))

    eprime_results = ROOT / "results/eprime"
    for stats_file in sorted(eprime_results.rglob("stats.csv")) if eprime_results.is_dir() else []:
        relative = stats_file.parent.relative_to(eprime_results)
        parts = relative.parts
        backend = parts[0] if parts else "unknown"
        configuration = " / ".join(parts[1:])
        label = f"EPrime {backend} / {configuration}"
        specs.append(RunSpec(f"eprime/{relative.as_posix()}", label, stats_file.parent, "eprime", "eprime"))

    by_key = {spec.key: spec for spec in specs}
    if not specs:
        raise SystemExit("No results found under results/pddl or results/eprime")
    greedy = [key for key in ("granular-colour", "granular-hadd", "direct-base-greedy-colour", "direct-base-greedy-hadd") if key in by_key]
    suites = {
        "greedy": greedy,
        "heuristic-comparison": [key for key in HEURISTIC_COMPARISON_LABELS if key in by_key],
        "planner-comparison": [key for key in PLANNER_COMPARISON_LABELS if key in by_key],
        "enhsp": [spec.key for spec in specs if spec.source == "pddl" and spec.path.relative_to(results).parts[0] == "enhsp"],
        "eprime": [spec.key for spec in specs if spec.source == "eprime"],
        "all-runs": [spec.key for spec in specs],
    }
    return by_key, {name: keys for name, keys in suites.items() if keys}


def normalize(value: str) -> str:
    return re.sub(r"(?:-problem)?\.pddl$|\.plan$", "", Path(value.strip()).name)


def number(value: object) -> float | None:
    try:
        result = float(value)
        return result if math.isfinite(result) and result >= 0 else None
    except (TypeError, ValueError):
        return None


def average(values: list[float]) -> float | None:
    return statistics.mean(values) if values else None


def metric_values(rows: list[Row], field: str) -> list[float]:
    return [value for r in rows if (value := getattr(r, field)) is not None]


def local_artifact(directory: Path, raw: str, folder: str, filename: str) -> Path | None:
    # Prefer this run's files over stale absolute paths in imported CSVs.
    for path in (directory / folder / filename, directory / folder / Path(raw).name,
                 directory / raw, Path(raw)):
        if raw or path == directory / folder / filename:
            if path.is_file():
                return path
    return None


def last_metric(text: str, patterns: tuple[str, ...]) -> float | None:
    for pattern in patterns:
        matches = re.findall(pattern, text, re.M)
        if matches:
            return number(matches[-1])
    return None


def grounding_time_ms(item: dict, log_text: str) -> float | None:
    """Read measured grounding time; FD/SymK use instantiation wall time."""
    value = number(item.get("grounding_time_ms"))
    if value is not None:
        return value
    seconds = number(item.get("grounding_time_sec"))
    if seconds is not None:
        return seconds * 1000
    value = last_metric(log_text, (
        r"^\s*Grounding Time(?: \(msec\))?:\s*([\d.eE+-]+)\s*$",
    ))
    if value is not None:
        return value
    seconds = last_metric(log_text, (
        r"^Instantiating:\s*\[[\d.eE+-]+s CPU,\s*([\d.eE+-]+)s wall-clock\]",
    ))
    return seconds * 1000 if seconds is not None else None


def plan_metrics(path: Path | None) -> tuple[float | None, float | None, str]:
    if path is None:
        return None, None, ""
    text = path.read_text(encoding="utf-8", errors="replace")
    names = ACTION.findall(text)
    if not names and not re.search(r"^;\s*cost\s*=", text, re.M):
        return None, None, ""
    shot_count = sum(n.startswith(("shooting_row_", "shooting_column_", "shoot-")) for n in names)
    if shot_count:
        return float(len(names)), float(shot_count), "plan_shot_count"
    cost = last_metric(text, (r"^;\s*cost\s*=\s*([\d.eE+-]+)",))
    return float(len(names)), cost, "plan_cost_comment" if cost is not None else ""


def read_run(spec: RunSpec, timeout: float, warnings: list[str]) -> dict[str, Row]:
    if spec.source == "eprime":
        return read_eprime_run(spec, timeout, warnings)
    path = spec.path if spec.path.is_file() else spec.path / "stats.csv"
    if not path.is_file():
        warnings.append(f"Missing stats.csv: {path}")
        return {}
    directory = path.parent
    result = {}
    # Read once: a running benchmark may append additional rows during reporting.
    records = list(csv.DictReader(path.read_text(encoding="utf-8").splitlines()))
    for item in records:
        if not item.get("problem") or any(item.get(k) in (None, "") for k in ("status", "valid", "total_runtime_sec")) or any(v is None for v in item.values()):
            warnings.append(f"Skipped incomplete CSV row in {path}")
            continue
        problem = normalize(item["problem"])
        if problem in result:
            raise ValueError(f"Duplicate problem {problem} in {path}")
        status = item["status"].strip().lower()
        valid = item["valid"].strip().lower()
        runtime = number(item.get("total_runtime_sec"))
        source_status = status
        log = local_artifact(directory, item.get("planner_log", ""), "logs", f"{problem}.planner.log")
        log_text = log.read_text(encoding="utf-8", errors="replace") if log else ""
        # The historical "unsolved" status also covers heap failures. Only
        # explicit impossibility proofs for allowlisted instances count as solved.
        resource_failure = number(item.get("exit_code")) in {124, 137, 143} or bool(re.search(
            r"OutOfMemoryError|Java heap space|out of memory|memory limit (?:reached|exceeded)|"
            r"\btimeout\b|time limit (?:reached|exceeded)", log_text, re.I,
        ))
        proven_unsolvable = status in {"unsolved", "unsolvable"} and not resource_failure and bool(re.search(
            r"^\s*Problem unsolvable\b|Completely explored state space.*no solution|"
            r"^\s*search exit code:\s*12\s*$", log_text, re.I | re.M,
        ))
        accepted_unsolvable = proven_unsolvable and problem in SOLVED_UNSOLVABLE_INSTANCES
        if valid == "false":
            status = "invalid_plan"
        elif (status == "ok" or proven_unsolvable) and runtime is not None and runtime > timeout:
            status = "timeout"
        has_plan = status == "ok" and valid == "true"
        # Invalid plans count as solved for comparisons, retaining their status.
        solved = runtime is not None and runtime <= timeout and (
            has_plan or status == "invalid_plan"
            or (accepted_unsolvable and status in {"unsolved", "unsolvable"})
        )
        if status in {"unsolved", "unsolvable"}:
            status = "unsolvable" if accepted_unsolvable else "unsolved"
        if status == "ok" and not has_plan:
            status = "unvalidated"
        plan = local_artifact(directory, item.get("plan_file", ""), "plans", f"{problem}.plan")
        actions, shots, cost_source = plan_metrics(plan) if has_plan else (None, None, "")
        if actions is None and not proven_unsolvable:
            actions = number(item.get("actions"))
        expanded = number(item.get("expanded_nodes"))
        visited = number(item.get("states_evaluated"))
        if visited is None:
            visited = number(item.get("visited_nodes"))
        search_time_ms = number(item.get("search_time_ms"))
        if search_time_ms is None:
            search_time_sec = number(item.get("search_time_sec"))
            search_time_ms = search_time_sec * 1000 if search_time_sec is not None else None
        if expanded is None:
            expanded = last_metric(log_text, (r"^Expanded Nodes:\s*(\d+)", r"\] Expanded\s+(\d+)\s+state"))
        if visited is None:
            visited = last_metric(log_text, (r"^States Evaluated:\s*(\d+)", r"\] Evaluated\s+(\d+)\s+state"))
        if search_time_ms is None:
            search_time_ms = last_metric(log_text, (r"^Search Time \(msec\):\s*([\d.eE+-]+)",))
        if search_time_ms is None:
            search_time_sec = last_metric(
                log_text,
                (r"\] Actual search time:\s*([\d.eE+-]+)s", r"\] Search time:\s*([\d.eE+-]+)s"),
            )
            search_time_ms = search_time_sec * 1000 if search_time_sec is not None else None
        peak_memory_kb = number(item.get("peak_memory_kb"))
        if peak_memory_kb is None:
            peak_memory_kb = last_metric(log_text, (r"^Peak memory:\s*([\d.eE+-]+)\s*KB",))
        if peak_memory_kb is None:
            bracket_memory = [number(value) for value in re.findall(r"\[t=[^\]]+,\s*([\d.eE+-]+)\s+KB\]", log_text)]
            peak_memory_kb = max((value for value in bracket_memory if value is not None), default=None)
        heuristic_time_ms = number(item.get("heuristic_time_ms"))
        if heuristic_time_ms is None:
            heuristic_time_ms = last_metric(
                log_text, (r"^Heuristic Time \(msec\):\s*([\d.eE+-]+)\s*$",)
            )
        if has_plan and shots is None:
            shots = number(item.get("metric"))
            cost_source = "csv_metric" if shots is not None else ""
            if shots is None:
                shots = last_metric(log_text, (r"^Metric \(Search\):\s*([\d.eE+-]+)", r"\] Plan cost:\s*([\d.eE+-]+)"))
                cost_source = "log_metric" if shots is not None else ""
        result[problem] = Row(
            problem, status, valid, runtime, expanded, shots, actions,
            cost_source, source_status, solved, visited, search_time_ms, peak_memory_kb,
            heuristic_time_ms, grounding_time_ms(item, log_text),
        )
    return result


def read_eprime_run(spec: RunSpec, timeout: float, warnings: list[str]) -> dict[str, Row]:
    """Collapse increasing-horizon attempts into one result per problem.

    The runner's cumulative time includes all earlier unsatisfiable horizons,
    Savile Row translation and container overhead, not just the final solve.
    SAT and allowlisted exhaustive UNSAT count as solved; VAL only applies to PDDL.
    """
    path = spec.path / "stats.csv"
    records = list(csv.DictReader(path.read_text(encoding="utf-8").splitlines()))
    attempts: dict[str, list[dict]] = {}
    for item in records:
        if (any(item.get(k) in (None, "") for k in ("problem", "status", "cumulative_runtime_sec"))
                or any(v is None for v in item.values())
                or number(item.get("cumulative_runtime_sec")) is None):
            warnings.append(f"Skipped incomplete CSV row in {path}")
            continue
        problem = normalize(item["problem"])
        previous = attempts.setdefault(problem, [])
        if previous and previous[-1]["status"].strip().lower() == "solved":
            continue
        # A rerun appends a new sequence to the same CSV; use that sequence.
        step = number(item.get("step"))
        previous_step = number(previous[-1].get("step")) if previous else None
        if previous and step is not None and previous_step is not None and step <= previous_step:
            previous.clear()
        previous.append(item)

    result = {}
    for problem, entries in attempts.items():
        final = entries[-1]
        source_status = final["status"].strip().lower()
        runtime = number(final["cumulative_runtime_sec"])
        step = number(final.get("step"))
        # UNSAT counts as solved only after all horizons used by the runner
        # (1 through rows * cols - goal) have completed successfully.
        proven_unsolvable = False
        if source_status == "unsolved":
            match = re.fullmatch(r"plt\d+_(\d+)_(\d+)_(\d+)_\d+", problem)
            if match and step is not None:
                rows, cols, goal = map(int, match.groups())
                max_steps = rows * cols - goal
                proven_unsolvable = max_steps > 0 and {
                    number(entry.get("step")) for entry in entries
                    if entry["status"].strip().lower() == "unsolved"
                    and number(entry.get("exit_code")) == 0
                } == set(range(1, max_steps + 1))
            if not proven_unsolvable:
                warnings.append(f"Unfinished EPrime horizon search: {problem} in {path}")
                continue
        has_plan = source_status == "solved" and runtime <= timeout
        accepted_unsolvable = proven_unsolvable and problem in SOLVED_UNSOLVABLE_INSTANCES
        solved = (source_status == "solved" or accepted_unsolvable) and runtime <= timeout
        status = (("unsolvable" if accepted_unsolvable else "unsolved")
                  if proven_unsolvable and runtime <= timeout else "ok" if has_plan
                  else "timeout" if source_status == "solved" or proven_unsolvable else source_status)
        solver_times = [number(entry.get("solver_runtime_sec")) for entry in entries]
        search_time_ms = sum(solver_times) * 1000 if all(t is not None for t in solver_times) else None
        result[problem] = Row(
            problem=problem, status=status, valid="solver" if solved else "",
            runtime=runtime, expanded_nodes=None, shots=step if has_plan else None,
            actions=None, cost_source="eprime_horizon" if has_plan else "",
            source_status=source_status, solved=solved, search_time_ms=search_time_ms,
        )
    return result


def write_csv(path: Path, rows: list[dict], fields: list[str] | None = None) -> None:
    if fields is None:
        fields = list(rows[0]) if rows else ["no_data"]
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(
            {key: f"{value:.3f}" if isinstance(value, float) else value
             for key, value in row.items()}
            for row in rows
        )


def heuristic_ms_per_evaluation(rows: list[Row]) -> float | None:
    """Arithmetic mean of per-instance Heuristic Time / States Evaluated."""
    measured = [r.heuristic_time_ms / r.visited_nodes for r in rows
                if r.heuristic_time_ms is not None
                and r.visited_nodes is not None
                and r.visited_nodes > 0]
    return average(measured)


def par2_cost(row: Row, timeout: float) -> float:
    """Use actual time for solved outcomes (including invalid plans), else twice the limit."""
    if row.solved and row.runtime is not None and 0 <= row.runtime <= timeout:
        return row.runtime
    return 2 * timeout


def summary(spec: RunSpec, data: dict[str, Row], cohort: set[str], shared: set[str], timeout: float) -> dict:
    rows = [data[p] for p in sorted(cohort) if p in data]
    solved = [r for r in rows if r.solved]
    matched = [data[p] for p in sorted(shared)]
    penalties = [par2_cost(r, timeout) for r in rows]
    solved_times = [r.runtime for r in solved if r.runtime is not None]
    expanded_rates = []
    evaluated_rates = []
    for row in solved:
        elapsed_sec = row.search_time_ms / 1000 if row.search_time_ms is not None and row.search_time_ms > 0 else row.runtime
        if elapsed_sec is None or elapsed_sec <= 0:
            continue
        if row.expanded_nodes is not None:
            expanded_rates.append(row.expanded_nodes / elapsed_sec)
        if row.visited_nodes is not None:
            evaluated_rates.append(row.visited_nodes / elapsed_sec)
    memory_mb = [row.peak_memory_kb / 1024 for row in solved if row.peak_memory_kb is not None]
    # Grounding can finish even when search fails: use every measured row in
    # the cohort, independently of the search outcome.
    grounding_times = metric_values(rows, "grounding_time_ms")
    output = {
        "run": spec.label, "encoding": spec.encoding, "cohort": len(cohort),
        "completed": len(rows), "missing": len(cohort) - len(rows),
        "solved": len(solved), "failed": len(rows) - len(solved),
        "coverage_completed_pct": 100 * len(solved) / len(rows) if rows else None,
        "par2_mean_sec": average(penalties),
        "par2_sum_sec": sum(penalties),
        "timeout_sec": timeout,
        "statuses": json.dumps(dict(sorted(Counter(r.status for r in rows).items()))),
        "jointly_solved": len(matched),
        "best_runtime_sec": min(solved_times) if solved_times else None,
        "worst_solved_runtime_sec": max(solved_times) if solved_times else None,
        "expanded_nodes_per_sec": average(expanded_rates),
        "states_evaluated_per_sec": average(evaluated_rates),
        "mean_peak_memory_mb": average(memory_mb),
        "grounding_time_n": len(grounding_times),
        "mean_grounding_time_ms": average(grounding_times),
    }
    for field in METRICS:
        for scope, chosen in (("solved", solved), ("joint", matched)):
            values = metric_values(chosen, field)
            output[f"{scope}_{field}_n"] = len(values)
            output[f"{scope}_{field}_mean"] = average(values)
    # Do not divide search time by expanded/evaluated nodes here:
    # that is a search throughput measure, not heuristic evaluation time.
    output["ms_per_heuristic_evaluation"] = heuristic_ms_per_evaluation(solved)
    return output


def compact_summary(item: dict) -> dict:
    """Extend the legacy summary columns with timing statistics in ms."""
    return {
        "run": item["run"],
        "instances": item["completed"],
        "solved": f"{item['solved']}/{item['completed']}",
        "coverage_percent": item["coverage_completed_pct"],
        "par2_timeout_sec": item["timeout_sec"],
        "par2_score": item["par2_sum_sec"],
        "best_runtime_sec": item["best_runtime_sec"],
        "mean_solved_runtime_sec": item["solved_runtime_mean"],
        "worst_solved_runtime_sec": item["worst_solved_runtime_sec"],
        "mean_search_time_ms": item["solved_search_time_ms_mean"],
        "grounding_time_n": item["grounding_time_n"],
        "mean_grounding_time_ms": item["mean_grounding_time_ms"],
        "mean_expanded_nodes": item["solved_expanded_nodes_mean"],
        "mean_states_evaluated": item["solved_visited_nodes_mean"],
        "expanded_nodes_per_sec": item["expanded_nodes_per_sec"],
        "states_evaluated_per_sec": item["states_evaluated_per_sec"],
        # 6 decimals to retain sub-millisecond differences between heuristics.
        "ms_per_heuristic_evaluation": (
            f"{item['ms_per_heuristic_evaluation']:.6f}"
            if item["ms_per_heuristic_evaluation"] is not None else ""
        ),
        "mean_peak_memory_mb": item["mean_peak_memory_mb"],
    }


def enhsp_grounding_measurements(
    specs: list[RunSpec], data: dict[str, dict[str, Row]],
) -> tuple[dict[str, list[RunSpec]], dict[str, dict[str, list[float]]]]:
    """Group available ENHSP grounding measurements by encoding and instance."""
    groups: dict[str, list[RunSpec]] = {}
    for spec in specs:
        if spec.source != "pddl":
            continue
        try:
            relative = spec.path.relative_to(ROOT / "results/pddl/enhsp")
        except ValueError:
            continue
        if len(relative.parts) != 2 or relative.parts[0] not in ENCODING_LABELS:
            continue
        encoding = relative.parts[0]
        groups.setdefault(encoding, []).append(spec)

    measurements: dict[str, dict[str, list[float]]] = {}
    for encoding, runs in groups.items():
        measured: dict[str, list[float]] = {}
        for spec in runs:
            for problem, row in data[spec.key].items():
                if row.grounding_time_ms is not None:
                    measured.setdefault(problem, []).append(row.grounding_time_ms)
        measurements[encoding] = measured
    return groups, measurements


def grounding_by_encoding(specs: list[RunSpec], data: dict[str, dict[str, Row]]) -> list[dict]:
    """Average ENHSP measurements per instance first, then across instances.

    Keep both all measured instances and a common measured cohort across
    encodings. Missing measurements are never treated as zero or as timeouts.
    """
    groups, measurements = enhsp_grounding_measurements(specs, data)
    common = set.intersection(*(set(measured) for measured in measurements.values())) if measurements else set()
    output = []
    for encoding in ("direct-base", "direct-new", "granular"):
        if encoding not in groups:
            continue
        runs = groups[encoding]
        measured = measurements[encoding]
        instance_means = {problem: statistics.mean(values) for problem, values in measured.items()}
        output.append({
            "planner": "ENHSP", "encoding": encoding, "runs": len(runs),
            "instances": len(set().union(*(set(data[spec.key]) for spec in runs))),
            "grounding_instances": len(measured),
            "grounding_time_n": sum(len(values) for values in measured.values()),
            "mean_grounding_time_ms": average(list(instance_means.values())),
            "common_grounding_instances": len(common),
            "common_grounding_time_n": sum(len(measured[problem]) for problem in common),
            "common_mean_grounding_time_ms": average([instance_means[problem] for problem in sorted(common)]),
        })
    return output


def group_key(problem: str) -> tuple[int, int, int]:
    match = re.match(r"plt\d+_(\d+)_(\d+)_(\d+)_", problem)
    return tuple(map(int, match.groups())) if match else (0, 0, 0)


def save_vector_plot(fig, path: Path, bbox_inches: str | None = "tight") -> None:
    """Save the SVG source, then convert that exact SVG to PDF."""
    svg = path.with_suffix(".svg")
    fig.savefig(svg, bbox_inches=bbox_inches)
    subprocess.run(["rsvg-convert", "--format=pdf", "--output", str(path.with_suffix(".pdf")),
                    str(svg)], check=True)


def grounding_plots(
    directory: Path, table_directory: Path,
    specs: list[RunSpec], data: dict[str, dict[str, Row]],
) -> list[str]:
    """Grounding overviews and paired scatter plots using instance means."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.ticker import FuncFormatter, NullLocator

    groups, measurements = enhsp_grounding_measurements(specs, data)
    if not groups:
        return []
    common = set.intersection(*(set(measured) for measured in measurements.values()))
    names = ENCODING_LABELS
    colours = {"direct-base": "#3366a6", "direct-new": "#df8430", "granular": "#278875"}
    encodings = [key for key in names if key in groups]
    instance_means = {
        encoding: {problem: statistics.mean(values) / 1000 for problem, values in measured.items()}
        for encoding, measured in measurements.items()
    }
    table_directory.mkdir(parents=True, exist_ok=True)
    write_csv(table_directory / "grounding-by-instance.csv", [
        {"encoding": encoding, "problem": problem,
         "rows": group_key(problem)[0], "cols": group_key(problem)[1],
         "colours": group_key(problem)[2],
         "grounding_time_n": len(measurements[encoding][problem]),
         "mean_grounding_time_ms": value * 1000, "common_cohort": problem in common}
        for encoding in encodings
        for problem, value in sorted(instance_means[encoding].items())
    ])
    if not common:
        return []
    directory.mkdir(parents=True, exist_ok=True)
    values = {key: [instance_means[key][p] for p in sorted(common)] for key in encodings}
    palette = [colours[key] for key in encodings]
    labels = [names[key] for key in encodings]
    sizes = sorted({group_key(p)[0] * group_key(p)[1] for p in common})
    size_values = {
        key: {size: [instance_means[key][p] for p in sorted(common)
                     if group_key(p)[0] * group_key(p)[1] == size] for size in sizes}
        for key in encodings
    }
    observed = set().union(*(set(data[run.key]) for runs in groups.values() for run in runs))
    footer = f"{len(observed) - len(common)} of {len(observed)} tested instances excluded: grounding unavailable in at least one encoding."
    formatter = FuncFormatter(lambda value, position: f"{value:g}")

    def log_scale(ax, axis):
        positive = all(value > 0 for series in values.values() for value in series)
        options = {} if positive else {"linthresh": .001}
        getattr(ax, f"set_{axis}scale")("log" if positive else "symlog", **options)
        getattr(ax, f"{axis}axis").set_major_formatter(formatter)
        getattr(ax, f"{axis}axis").set_minor_locator(NullLocator())

    def draw_mean(ax):
        means = [statistics.mean(values[key]) for key in encodings]
        ax.barh(labels, means, color=palette, height=.52)
        for index, value in enumerate(means):
            ax.annotate(f"{value:.3f} s", (value, index), xytext=(7, 0),
                        textcoords="offset points", va="center", fontweight="bold")
        ax.invert_yaxis()
        ax.set_xlim(0, max(means) * 1.24 if max(means) > 0 else 1)
        ax.set(xlabel="Mean grounding time (s)")
        ax.grid(axis="x", alpha=.18)

    def draw_scalability(ax):
        for key in encodings:
            means, lower, upper = [], [], []
            for size in sizes:
                measured = size_values[key][size]
                means.append(statistics.mean(measured))
                quartiles = statistics.quantiles(measured, n=4, method="inclusive") if len(measured) > 1 else measured * 3
                lower.append(quartiles[0])
                upper.append(quartiles[2])
            ax.plot(sizes, means, marker="o", markersize=4, color=colours[key], label=names[key])
            ax.fill_between(sizes, lower, upper, color=colours[key], alpha=.12)
        log_scale(ax, "y")
        ax.set_xticks(sizes)
        ax.set(xlabel="Grid cells (rows × columns)", ylabel="Grounding time in seconds (log scale)")
        ax.legend(frameon=False, fontsize=9)
        ax.grid(which="major", alpha=.18)

    def draw_size_distribution(ax):
        legend_names = {"direct-base": r"Direct $\mathit{Base}$",
                        "direct-new": r"Direct $\mathit{New}$", "granular": "Granular"}
        # Each encoding contributes all measured instances, including grid sizes
        # for which another encoding has no grounding measurements.
        distribution_sizes = sorted({group_key(p)[0] * group_key(p)[1]
                                     for measured in instance_means.values() for p in measured})
        width = .75 / len(encodings)
        for index, key in enumerate(encodings):
            measured_by_size = {
                size: [value for p, value in sorted(instance_means[key].items())
                       if group_key(p)[0] * group_key(p)[1] == size]
                for size in distribution_sizes
            }
            available = [(position, measured_by_size[size])
                         for position, size in enumerate(distribution_sizes) if measured_by_size[size]]
            if not available:
                continue
            positions = [position + (index - (len(encodings) - 1) / 2) * width
                         for position, _ in available]
            boxes = ax.boxplot([measured for _, measured in available],
                               positions=positions, widths=width * .8, vert=False,
                               patch_artist=True, manage_ticks=False,
                               medianprops={"color": "#202d3a", "linewidth": 1.2},
                               flierprops={"marker": ".", "markersize": 3, "alpha": .4,
                                           "markeredgecolor": colours[key]})
            for patch in boxes["boxes"]:
                patch.set(facecolor=colours[key], alpha=.7)
            boxes["boxes"][0].set_label(legend_names[key])
        ax.set_yticks(range(len(distribution_sizes)), [str(size) for size in distribution_sizes])
        log_scale(ax, "x")
        ax.set_xlabel("Grounding time in seconds (log scale)", fontsize=14, fontweight="bold")
        ax.set_ylabel("Grid cells (rows × columns)", fontsize=14, fontweight="bold")
        ax.grid(which="major", alpha=.18)
        ax.tick_params(axis="both", which="both", labelsize=12)
        legend = ax.legend(fontsize=11, loc="lower right", frameon=True,
                           facecolor="white", edgecolor="black", framealpha=1,
                           fancybox=False, borderpad=.6, labelspacing=.5, handlelength=2.2)
        legend.get_frame().set_linewidth(1)

    def save(fig, name):
        # Preserve the square canvas for the standalone grid distribution.
        bbox = None if name == "grounding-grid-y-distribution" else "tight"
        save_vector_plot(fig, directory / name, bbox_inches=bbox)
        plt.close(fig)

    files = []
    views = [("grounding-mean", draw_mean), ("grounding-scalability", draw_scalability)]
    with plt.rc_context({"font.size": 10, "axes.spines.top": False,
                         "axes.spines.right": False, "axes.axisbelow": True}):
        for name, draw in views:
            fig, ax = plt.subplots(figsize=(8.5, 4.8))
            draw(ax)
            fig.text(.5, .015, footer, ha="center", fontsize=8, color="#4b5563")
            fig.tight_layout(rect=(0, .055, 1, 1))
            save(fig, name)
            files.append(name)
        fig, axes = plt.subplots(1, 2, figsize=(14, 4.8))
        for ax, (_, draw) in zip(axes, views):
            draw(ax)
        fig.text(.5, .012, footer, ha="center", fontsize=9, color="#4b5563")
        fig.tight_layout(rect=(0, .045, 1, 1), w_pad=3)
        save(fig, "grounding-overview")
        files.append("grounding-overview")
        fig, ax = plt.subplots(figsize=(8.5, 8.5))
        draw_size_distribution(ax)
        fig.tight_layout()
        save(fig, "grounding-grid-y-distribution")
        files.append("grounding-grid-y-distribution")
        all_values = [value for series in values.values() for value in series]
        lower = min(all_values) / 1.3 if min(all_values) > 0 else 0
        upper = max(all_values) * 1.3 if max(all_values) > 0 else 1
        problems = sorted(common)
        markers = {"direct-base": "o", "direct-new": "s", "granular": "^"}
        for reference in ("direct-new",):
            if reference not in encodings or len(encodings) < 2:
                continue
            fig, ax = plt.subplots(figsize=(8, 7.5))
            for compared in encodings:
                if compared == reference:
                    continue
                ax.scatter([instance_means[reference][p] for p in problems],
                           [instance_means[compared][p] for p in problems],
                           color=colours[compared], marker=markers[compared],
                           s=27, alpha=.6, linewidths=0, label=names[compared], zorder=3)
            ax.plot([lower, upper], [lower, upper], linestyle="--", color="#59636e",
                    linewidth=1.2, label="Equal grounding time (y = x)", zorder=2)
            log_scale(ax, "x")
            log_scale(ax, "y")
            ax.set(xlim=(lower, upper), ylim=(lower, upper),
                   xlabel=f"{names[reference]} grounding time (s, log scale)",
                   ylabel="Compared encoding grounding time (s, log scale)")
            ax.set_aspect("equal", adjustable="box")
            ax.grid(which="major", alpha=.18)
            ax.legend(frameon=False, fontsize=9,
                      loc="upper left" if reference == "direct-base" else "lower right")
            fig.text(.5, .04, "Each point pairs the same instance; below the diagonal = faster than the reference.",
                     ha="center", fontsize=8, color="#4b5563")
            fig.text(.5, .015, footer, ha="center", fontsize=8, color="#4b5563")
            fig.tight_layout(rect=(0, .075, 1, 1))
            name = f"grounding-scatter-{reference}"
            save(fig, name)
            files.append(name)
    return files


def plots(directory: Path, specs: list[RunSpec], data: dict[str, dict[str, Row]], common: set[str], timeout: float, all_tested: bool = False) -> list[str]:
    if directory.name in {"greedy", "eprime"}:
        return []
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    plt.rcParams.update({"font.size": 10, "axes.spines.top": False, "axes.spines.right": False})
    files = []
    prefix = "all-tested-" if all_tested else ""
    heuristic_comparison = directory.name == "heuristic-comparison"
    planner_comparison = directory.name == "planner-comparison"

    def style(index):
        if heuristic_comparison:
            # Colour identifies the heuristic; line style identifies the search.
            key = specs[index].key
            return {"color": plt.get_cmap("tab10")(0 if "capacity" in key else 1),
                    "linestyle": "--" if "greedy" in key else "-"}
        if planner_comparison:
            key = specs[index].key
            linestyle = ("--" if specs[index].source == "eprime"
                         else ":" if key in {"fdm", "symk"} else "-")
            return {"color": plt.get_cmap("tab10")(index % 10),
                    "linestyle": linestyle}
        return {"color": plt.get_cmap("tab20")(index % 20),
                "linestyle": ("-", "--", "-.", ":")[(index // 20) % 4]}

    def save(fig, name):
        fig.tight_layout()
        save_vector_plot(fig, directory / f"{prefix}{name}")
        plt.close(fig)
        files.append(name)

    log_base = 3
    fig, ax = plt.subplots(figsize=(8.5 if planner_comparison else 10, 5))
    for index, spec in enumerate(specs):
        times = sorted(data[spec.key][p].runtime for p in common
                       if p in data[spec.key] and data[spec.key][p].solved
                       and data[spec.key][p].runtime is not None)
        ax.step([0, *times], [0, *range(1, len(times) + 1)],
                where="post", label=spec.label, **style(index))
    ticks = [0, 1]
    ticks.extend(log_base ** exponent for exponent in range(1, math.floor(math.log(timeout / log_base, log_base)) + 1))
    if timeout not in ticks:
        ticks.append(timeout)
    ax.set_xscale("symlog", base=log_base, linthresh=1)
    ax.set_xticks(ticks, [f"{tick:g}" for tick in ticks])
    ax.set_xlim(left=0)
    instance_count = len(common)
    y_ticks = list(range(0, instance_count, 50))
    if instance_count not in y_ticks:
        y_ticks.append(instance_count)
    ax.set_ylim(0, max(1, instance_count))
    ax.set_yticks(y_ticks)
    if planner_comparison:
        ax.set_xlabel("Runtime in seconds (log scale)", fontsize=14, fontweight="bold")
        ax.set_ylabel("Number of solved instances", fontsize=14, fontweight="bold")
    else:
        ax.set(xlabel="Runtime per instance (s, log3 scale)", ylabel="Number of instances solved")
    ax.grid(alpha=.2)
    if planner_comparison:
        from matplotlib.lines import Line2D
        from matplotlib.offsetbox import AnchoredOffsetbox, DrawingArea, HPacker, TextArea, VPacker

        legend_fontsize = 11
        encoding_labels = {"direct-base": "Direct", "direct-new": "Direct", "granular": "Granular"}
        encodings = [encoding_labels.get(spec.encoding, "")
                     for spec in specs]
        label_boxes = [TextArea(spec.label, textprops={"fontsize": legend_fontsize}) for spec in specs]
        for label_box in label_boxes:
            label_box.set_figure(fig)
        renderer = fig.canvas.get_renderer()
        label_width = max(box.get_bbox(renderer).width for box in label_boxes) * 72 / fig.dpi
        legend_rows = []
        for index, (label_box, encoding) in enumerate(zip(label_boxes, encodings)):
            sample = DrawingArea(24, 10)
            sample.add_artist(Line2D([0, 24], [5, 5], **style(index)))
            # A fixed first-column width keeps Direct and Granular aligned
            # across renderers, including SVG and its PDF conversion.
            entry = HPacker(children=[sample, label_box], align="center", pad=0, sep=6,
                            width=24 + 6 + label_width)
            legend_rows.append(HPacker(
                children=[entry, TextArea(encoding, textprops={"fontsize": legend_fontsize})],
                align="center", pad=0, sep=10,
            ))
        # Pack each label and encoding together to align their rows even when
        # math superscripts make the planner labels taller than plain text.
        legend = AnchoredOffsetbox(
            loc="lower right", child=VPacker(children=legend_rows, align="left", pad=0, sep=4),
            bbox_to_anchor=(1.005, .015), bbox_transform=ax.transAxes,
            prop={"size": legend_fontsize}, pad=.4, borderpad=.3, frameon=True,
        )
        legend.patch.set(facecolor="white", edgecolor=".8", alpha=.95)
        ax.add_artist(legend)
    else:
        ax.legend(fontsize=8, loc="upper left", bbox_to_anchor=(1.02, 1))
    save(fig, "planner_cumulative_instances" if planner_comparison else "solved-over-time")

    if heuristic_comparison or planner_comparison:
        return files

    groups = sorted({group_key(p) for p in common}, key=lambda g: (g[0] * g[1], *g))
    fig, ax = plt.subplots(figsize=(max(11, len(groups) * .38), 5))
    for index, spec in enumerate(specs):
        rates = []
        for group in groups:
            members = [p for p in common if p in data[spec.key] and group_key(p) == group]
            rates.append(100 * sum(data[spec.key][p].solved for p in members) / len(members) if members else math.nan)
        ax.plot(range(len(groups)), rates, marker=".", label=spec.label, **style(index))
    ax.set_xticks(range(len(groups)), [f"{r}×{c}, {k}c" for r, c, k in groups], rotation=70, ha="right")
    ax.set(ylabel="Coverage (%)", ylim=(-3, 103))
    ax.legend(fontsize=8, loc="upper left", bbox_to_anchor=(1.02, 1))
    ax.grid(alpha=.2)
    save(fig, "scalability")

    return files


def write_suite(table_directory: Path, plot_directory: Path, specs: list[RunSpec], data: dict[str, dict[str, Row]], timeout: float) -> dict:
    table_directory.mkdir(parents=True, exist_ok=True)
    common = set.intersection(*(set(data[s.key]) for s in specs))
    shared = {p for p in common if all(data[s.key][p].solved for s in specs)}
    summaries = [summary(s, data[s.key], common, shared, timeout) for s in specs]
    compact_summaries = [compact_summary(item) for item in summaries]
    write_csv(table_directory / "summary.csv", compact_summaries)
    write_csv(table_directory / "cohort.csv", [{"problem": p, "jointly_solved": p in shared} for p in sorted(common)], ["problem", "jointly_solved"])
    grouped = []
    for group in sorted({group_key(p) for p in common}, key=lambda g: (g[0] * g[1], *g)):
        cohort = {p for p in common if group_key(p) == group}
        for s in specs:
            grouped.append({"rows": group[0], "cols": group[1], "colours": group[2],
                            **summary(s, data[s.key], cohort, shared & cohort, timeout)})
    write_csv(table_directory / "by-size-summary.csv", grouped)
    if common and table_directory.name not in {"greedy", "eprime"}:
        plot_directory.mkdir(parents=True, exist_ok=True)
        plots(plot_directory, specs, data, common, timeout)
    if table_directory.name == "all-runs":
        observed = set.union(*(set(data[s.key]) for s in specs))
        write_csv(table_directory / "all-tested-summary.csv",
                  [compact_summary(summary(s, data[s.key], observed, shared, timeout)) for s in specs])
        if observed:
            plot_directory.mkdir(parents=True, exist_ok=True)
            plots(plot_directory, specs, data, observed, timeout, all_tested=True)
    return {"suite": table_directory.name, "runs": len(specs), "common_completed": len(common), "jointly_solved": len(shared)}


def main() -> None:
    if len(sys.argv) != 1:
        raise SystemExit("global_comparison.py does not accept arguments")
    if shutil.which("rsvg-convert") is None:
        raise SystemExit("SVG-to-PDF conversion requires rsvg-convert (see README.md).")
    specs, suites = defaults()
    keys = {key for values in suites.values() for key in values}
    warnings = []
    try:
        data = {key: read_run(specs[key], TIMEOUT, warnings) for key in sorted(keys)}
    except ValueError as exc:
        raise SystemExit(str(exc)) from exc
    sample = {normalize(line) for line in SAMPLE_MANIFEST.read_text(encoding="utf-8").splitlines()
              if line.strip()}
    if not sample:
        raise SystemExit(f"Empty benchmark sample: {SAMPLE_MANIFEST}")
    data = {key: {problem: row for problem, row in rows.items() if problem in sample}
            for key, rows in data.items()}
    for warning in warnings:
        print(f"Warning: {warning}", file=sys.stderr)
    try:
        import matplotlib  # noqa: F401
    except ImportError as exc:
        raise SystemExit("Plots require matplotlib (see requirements.txt).") from exc
    table_output = OUTPUT / "tables"
    plot_output = OUTPUT / "plots"
    table_output.mkdir(parents=True, exist_ok=True)
    plot_output.mkdir(parents=True, exist_ok=True)
    write_csv(table_output / "grounding-by-encoding.csv",
              grounding_by_encoding([specs[key] for key in sorted(keys)], data))
    grounding_plots(plot_output / "grounding", table_output,
                    [specs[key] for key in sorted(keys)], data)
    reports = []
    for name, suite_keys in suites.items():
        suite_specs = [specs[k] for k in suite_keys]
        if name in COMPARISON_LABELS:
            suite_specs = [replace(spec, label=COMPARISON_LABELS[name][spec.key])
                           for spec in suite_specs]
        report = write_suite(table_output / name, plot_output / name, suite_specs, data, TIMEOUT)
        reports.append(report)
    write_csv(table_output / "comparisons.csv", reports)


if __name__ == "__main__":
    main()
