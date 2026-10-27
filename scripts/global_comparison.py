#!/usr/bin/env python3
"""Generate all global comparisons for the completed Plotting runs.

Inspired by old/scripts/global_comparison.py; uses validated solutions and
explicit intersections instead of treating absent results as failed runs.
"""

from __future__ import annotations

import csv
import json
import math
import re
import statistics
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "results/comparisons"
TIMEOUT = 900.0
# Exclude the historical full-suite run and the superseded direct-opt blind run.
EXCLUDED_PDDL_RUNS = {
    "enhsp/direct/greedy-colour-opt",
    "enhsp/direct/wastar-optblind-opt",
}
ACTION = re.compile(r"^\s*(?:\d+(?:\.\d+)?\s*:\s*)?\(([\w-]+)\b", re.M)
METRICS = ("runtime", "search_time_ms", "expanded_nodes", "visited_nodes", "shots", "actions")
TITLES = {"runtime": "Runtime (s)", "expanded_nodes": "Expanded nodes",
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


def defaults() -> tuple[dict[str, RunSpec], dict[str, list[str]]]:
    results = ROOT / "results/pddl"
    known = {
        "enhsp/granular/greedy-colour": ("granular-colour", "Granular GBFS colour", "granular"),
        "enhsp/granular/greedy-hadd": ("granular-hadd", "Granular GBFS hadd", "granular"),
        "enhsp/granular/wastar-optblind": ("granular-wastar-blind", "Granular WA* opt-blind", "granular"),
        "enhsp/direct/greedy-colour": ("direct-colour", "Direct GBFS colour", "direct"),
        "enhsp/direct/greedy-hadd": ("direct-hadd", "Direct GBFS hadd", "direct"),
        "enhsp/direct/wastar-colour": ("direct-wastar-colour", "Direct WA* colour", "direct"),
        "enhsp/direct/wastar-optblind": ("direct-wastar-blind", "Direct WA* opt-blind", "direct"),
        "enhsp/direct/wastar-colour-opt": ("direct-wastar-colour-opt", "Direct WA* colour-opt", "direct"),
        "enhsp/direct/wastar-capacity-opt": ("direct-wastar-capacity-opt", "Direct WA* capacity-opt", "direct"),
        "enhsp/direct/greedy-capacity-opt": ("direct-greedy-capacity-opt", "Direct GBFS capacity-opt", "direct"),
        "enhsp/direct/greedy-hadd-opt": ("direct-greedy-hadd-opt", "Direct GBFS hadd-opt", "direct"),
        "fast-downward/fdm-opt-blind": ("fdm", "FD(m) opt-blind", "granular"),
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
            "direct" if relative.startswith("enhsp/direct/")
            else "granular" if relative.startswith("enhsp/granular/")
            else "unknown"
        )
        key, label, encoding = known.get(
            relative,
            (relative.replace("/", "-"), relative.replace("/", " / ").replace("-", " "), default_encoding),
        )
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
    greedy = [key for key in ("granular-colour", "granular-hadd", "direct-colour", "direct-hadd") if key in by_key]
    suites = {
        "greedy": greedy,
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


def median(values: list[float]) -> float | None:
    return statistics.median(values) if values else None


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
        if valid == "false":
            status = "invalid_plan"
        elif status == "ok" and runtime is not None and runtime > timeout:
            status = "timeout"
        solved = status == "ok" and valid == "true"
        if status == "ok" and not solved:
            status = "unvalidated"
        plan = local_artifact(directory, item.get("plan_file", ""), "plans", f"{problem}.plan")
        actions, shots, cost_source = plan_metrics(plan) if solved else (None, None, "")
        if actions is None:
            actions = number(item.get("actions"))
        expanded = number(item.get("expanded_nodes"))
        visited = number(item.get("states_evaluated"))
        if visited is None:
            visited = number(item.get("visited_nodes"))
        search_time_ms = number(item.get("search_time_ms"))
        if search_time_ms is None:
            search_time_sec = number(item.get("search_time_sec"))
            search_time_ms = search_time_sec * 1000 if search_time_sec is not None else None
        log = local_artifact(directory, item.get("planner_log", ""), "logs", f"{problem}.planner.log")
        log_text = log.read_text(encoding="utf-8", errors="replace") if log else ""
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
        if solved and shots is None:
            shots = number(item.get("metric"))
            cost_source = "csv_metric" if shots is not None else ""
            if shots is None:
                shots = last_metric(log_text, (r"^Metric \(Search\):\s*([\d.eE+-]+)", r"\] Plan cost:\s*([\d.eE+-]+)"))
                cost_source = "log_metric" if shots is not None else ""
        result[problem] = Row(problem, status, valid, runtime, expanded, shots, actions,
                              cost_source, source_status, solved, visited, search_time_ms, peak_memory_kb)
    return result


def read_eprime_run(spec: RunSpec, timeout: float, warnings: list[str]) -> dict[str, Row]:
    """Collapse increasing-horizon attempts into one result per problem.

    The runner's cumulative time includes all earlier unsatisfiable horizons,
    Savile Row translation and container overhead, not just the final solve.
    Solver satisfiability is the success criterion; VAL only applies to PDDL.
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
        # An UNSAT horizon does not establish failure while later horizons remain.
        if source_status == "unsolved":
            match = re.fullmatch(r"plt\d+_(\d+)_(\d+)_(\d+)_\d+", problem)
            if match and step is not None:
                rows, cols, goal = map(int, match.groups())
                if step < rows * cols - goal:
                    warnings.append(f"Unfinished EPrime horizon search: {problem} in {path}")
                    continue
        solved = source_status == "solved" and runtime <= timeout
        status = "ok" if solved else "timeout" if source_status == "solved" else source_status
        solver_times = [number(entry.get("solver_runtime_sec")) for entry in entries]
        search_time_ms = sum(solver_times) * 1000 if all(t is not None for t in solver_times) else None
        result[problem] = Row(
            problem=problem, status=status, valid="solver" if solved else "",
            runtime=runtime, expanded_nodes=None, shots=step if solved else None,
            actions=None, cost_source="eprime_horizon" if solved else "",
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


def summary(spec: RunSpec, data: dict[str, Row], cohort: set[str], shared: set[str], timeout: float) -> dict:
    rows = [data[p] for p in sorted(cohort) if p in data]
    solved = [r for r in rows if r.solved]
    matched = [data[p] for p in sorted(shared)]
    penalties = [min(r.runtime, timeout) if r.solved and r.runtime is not None
                 else 2 * timeout if not r.solved else None for r in rows]
    complete_times = all(p is not None for p in penalties)
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
    output = {
        "run": spec.label, "encoding": spec.encoding, "cohort": len(cohort),
        "completed": len(rows), "missing": len(cohort) - len(rows),
        "solved": len(solved), "failed": len(rows) - len(solved),
        "coverage_completed_pct": 100 * len(solved) / len(rows) if rows else None,
        "par2_mean_sec": average(penalties) if complete_times else None,
        "par2_sum_sec": sum(penalties) if complete_times else None,
        "timeout_sec": timeout,
        "statuses": json.dumps(dict(sorted(Counter(r.status for r in rows).items()))),
        "jointly_solved": len(matched),
        "best_runtime_sec": min(solved_times) if solved_times else None,
        "worst_solved_runtime_sec": max(solved_times) if solved_times else None,
        "expanded_nodes_per_sec": average(expanded_rates),
        "states_evaluated_per_sec": average(evaluated_rates),
        "mean_peak_memory_mb": average(memory_mb),
    }
    for field in METRICS:
        for scope, chosen in (("solved", solved), ("joint", matched)):
            values = metric_values(chosen, field)
            output[f"{scope}_{field}_n"] = len(values)
            output[f"{scope}_{field}_mean"] = average(values)
            output[f"{scope}_{field}_median"] = median(values)
    timed_nodes = [(r.search_time_ms, r.expanded_nodes) for r in solved
                   if r.search_time_ms is not None and r.expanded_nodes is not None
                   and r.expanded_nodes > 0]
    output["solved_ms_per_node"] = (
        sum(time for time, _ in timed_nodes) / sum(nodes for _, nodes in timed_nodes)
        if timed_nodes else None
    )
    return output


def compact_summary(item: dict) -> dict:
    """Use the same columns and ordering as old/results/comparison/summary.csv."""
    return {
        "run": item["run"],
        "instances": item["completed"],
        "solved": f"{item['solved']}/{item['completed']}",
        "coverage_percent": item["coverage_completed_pct"],
        "par2_timeout_sec": item["timeout_sec"],
        "par2_score": item["par2_sum_sec"],
        "best_runtime_sec": item["best_runtime_sec"],
        "median_solved_runtime_sec": item["solved_runtime_median"],
        "mean_solved_runtime_sec": item["solved_runtime_mean"],
        "worst_solved_runtime_sec": item["worst_solved_runtime_sec"],
        "mean_expanded_nodes": item["solved_expanded_nodes_mean"],
        "median_expanded_nodes": item["solved_expanded_nodes_median"],
        "mean_states_evaluated": item["solved_visited_nodes_mean"],
        "expanded_nodes_per_sec": item["expanded_nodes_per_sec"],
        "states_evaluated_per_sec": item["states_evaluated_per_sec"],
        "mean_peak_memory_mb": item["mean_peak_memory_mb"],
    }


def group_key(problem: str) -> tuple[int, int, int]:
    match = re.match(r"plt\d+_(\d+)_(\d+)_(\d+)_", problem)
    return tuple(map(int, match.groups())) if match else (0, 0, 0)


def plots(directory: Path, specs: list[RunSpec], data: dict[str, dict[str, Row]], common: set[str], timeout: float, all_tested: bool = False) -> list[str]:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    plt.rcParams.update({"font.size": 10, "axes.spines.top": False, "axes.spines.right": False})
    files = []
    prefix = "all-tested-" if all_tested else ""

    def style(index):
        return {"color": plt.get_cmap("tab20")(index % 20),
                "linestyle": ("-", "--", "-.", ":")[(index // 20) % 4]}

    def save(fig, name):
        fig.tight_layout()
        for suffix in ("svg", "png"):
            fig.savefig(directory / f"{prefix}{name}.{suffix}", dpi=160, bbox_inches="tight")
        plt.close(fig)
        files.append(name)

    log_base = 3
    fig, ax = plt.subplots(figsize=(10, 5))
    for index, spec in enumerate(specs):
        times = sorted(data[spec.key][p].runtime for p in common
                       if p in data[spec.key] and data[spec.key][p].solved
                       and data[spec.key][p].runtime is not None)
        ax.step([0, *times, timeout], [0, *range(1, len(times) + 1), len(times)],
                where="post", label=spec.label, **style(index))
    ticks = [0, 1]
    ticks.extend(log_base ** exponent for exponent in range(1, math.floor(math.log(timeout / log_base, log_base)) + 1))
    if timeout not in ticks:
        ticks.append(timeout)
    ax.set_xscale("symlog", base=log_base, linthresh=1)
    ax.set_xticks(ticks, [f"{tick:g}" for tick in ticks])
    instance_count = len(common)
    y_ticks = list(range(0, instance_count, 50))
    if instance_count not in y_ticks:
        y_ticks.append(instance_count)
    ax.set_ylim(0, max(1, instance_count))
    ax.set_yticks(y_ticks)
    ax.set(xlabel="Runtime per instance (s, log3 scale)", ylabel="Number of instances solved",
           title=(f"All tested models — {instance_count} observed instances (partial runs included)" if all_tested
                  else f"Coverage over time — {instance_count} common completed instances"))
    ax.grid(alpha=.2)
    ax.legend(fontsize=8, loc="upper left", bbox_to_anchor=(1.02, 1))
    save(fig, "solved-over-time")

    groups = sorted({group_key(p) for p in common}, key=lambda g: (g[0] * g[1], *g))
    fig, ax = plt.subplots(figsize=(max(11, len(groups) * .38), 5))
    for index, spec in enumerate(specs):
        rates = []
        for group in groups:
            members = [p for p in common if p in data[spec.key] and group_key(p) == group]
            rates.append(100 * sum(data[spec.key][p].solved for p in members) / len(members) if members else math.nan)
        ax.plot(range(len(groups)), rates, marker=".", label=spec.label, **style(index))
    ax.set_xticks(range(len(groups)), [f"{r}×{c}, {k}c" for r, c, k in groups], rotation=70, ha="right")
    ax.set(ylabel="Coverage (%)", ylim=(-3, 103),
           title=("All tested models — coverage on each run's completed instances" if all_tested
                  else "Coverage by grid size and colours — common completed cohort"))
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
    if common:
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
    specs, suites = defaults()
    keys = {key for values in suites.values() for key in values}
    warnings = []
    try:
        data = {key: read_run(specs[key], TIMEOUT, warnings) for key in sorted(keys)}
    except ValueError as exc:
        raise SystemExit(str(exc)) from exc
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
    reports = []
    for name, suite_keys in suites.items():
        report = write_suite(table_output / name, plot_output / name, [specs[k] for k in suite_keys], data, TIMEOUT)
        reports.append(report)
    write_csv(table_output / "comparisons.csv", reports)


if __name__ == "__main__":
    main()
