#!/usr/bin/env python3
"""Compare two problems across all discovered PDDL and Essence Prime runs."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

from global_comparison import ROOT, TIMEOUT, defaults, normalize, read_run


PROBLEMS = ("plt4_6_5_5_5", "plt1_4_4_4_3")
DEFAULT_OUTPUT = ROOT / "results/comparisons/tables/problem-status-comparison.csv"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--problems", nargs=2, default=PROBLEMS, metavar=("FIRST", "SECOND"),
        help="problem names to compare (default: %(default)s)",
    )
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="output CSV path")
    args = parser.parse_args()
    problems = tuple(normalize(problem) for problem in args.problems)
    if not all(problems) or problems[0] == problems[1]:
        parser.error("provide two distinct, nonempty problem names")

    # Share discovery, horizon aggregation and status rules with the plots.
    specs, _ = defaults()
    rows = []
    warnings: list[str] = []
    for spec in specs.values():
        results = read_run(spec, TIMEOUT, warnings)
        row = {
            "run": spec.path.relative_to(ROOT / "results").as_posix(),
            "configuration": spec.label,
        }
        for problem in problems:
            result = results.get(problem)
            row[problem] = result.status if result is not None else "missing"
        rows.append(row)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=["run", "configuration", *problems])
        writer.writeheader()
        writer.writerows(rows)
    for warning in warnings:
        print(f"Warning: {warning}", file=sys.stderr)
    print(f"Created {args.output}: {len(rows)} runs.")


if __name__ == "__main__":
    main()
