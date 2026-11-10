#!/usr/bin/env python3
"""Generate the four retained 3D comparisons on common solved instances.

Use exactly 3 colours, 3–6 rows and 3–6 columns. All four plots have a linear
vertical axis; runtimes exclude PDDL plan validation with VAL.
"""

from __future__ import annotations

import argparse
import re
from collections import defaultdict
from pathlib import Path
from statistics import mean

import matplotlib
import numpy as np
from matplotlib.colors import LinearSegmentedColormap, to_rgb
from matplotlib.tri import LinearTriInterpolator, Triangulation

if __package__:
    from .global_comparison import (
        ROOT, SAMPLE_MANIFEST, TIMEOUT, Row, RunSpec, normalize, read_run,
    )
else:
    from global_comparison import (
        ROOT, SAMPLE_MANIFEST, TIMEOUT, Row, RunSpec, normalize, read_run,
    )


RESULTS = ROOT / "results/pddl/enhsp"
OUTPUT = ROOT / "results/comparisons/plots/planning-time-3d"
RUNS = {
    "base-hadd": RunSpec("base-hadd", r"Base–$h^{add}$",
                         RESULTS / "direct-base/greedy-hadd-base", "direct-base"),
    "new-hadd": RunSpec("new-hadd", r"New–$h^{add}$",
                        RESULTS / "direct-new/greedy-hadd-new", "direct-new"),
    "new-colour": RunSpec("new-colour", r"New–$h^{colour}$",
                          RESULTS / "direct-new/greedy-colour-new", "direct-new"),
    "granular-hadd": RunSpec("granular-hadd", r"Granular–$h^{add}$",
                             RESULTS / "granular/greedy-hadd", "granular"),
    "sat": RunSpec("sat", "Kissat - sa-deadend-v5", ROOT / "results/eprime/sat/sat-finetune/sa-deadend-v5",
                   "eprime", "eprime"),
}
# New and Kissat match planner-comparison/planner_cumulative_instances.pdf.
# Base and Granular use distinct, fixed colours from the same tab10 palette.
COLORS = {
    "base-hadd": "#1f77b4",
    "new-hadd": "#2ca02c",
    "new-colour": "#d62728",
    "granular-hadd": "#17becf",
    "sat": "#e377c2",
}
# Relative output stem, panel, first run, second run, total-runtime view.
COMPARISONS = (
    ("3d_a_encoding_base_vs_new_hadd", "(a)", "base-hadd", "new-hadd", False),
    ("3d_b_heuristic_new_hadd_vs_hcolour", "(b)", "new-hadd", "new-colour", False),
    ("3d_c_new_hcolour_vs_granular_hadd", "", "new-colour", "granular-hadd", False),
    ("3d_new_vs_sat", "", "new-colour", "sat", True),
)


def parse_problem_name(name: str) -> dict[str, int]:
    """Accept Direct names and Granular's '-problem.pddl' suffix."""
    match = re.fullmatch(r"plt(\d+)_(\d+)_(\d+)_(\d+)_(\d+)", normalize(name))
    if match is None:
        raise ValueError(f"Nome di istanza non riconosciuto: {name}")
    return dict(zip(("gen", "dim_x", "dim_y", "n_colori", "goal"),
                    map(int, match.groups())))


def load_and_prepare() -> tuple[set[str], dict[str, dict[str, Row]]]:
    """Use the fixed sample filter and the existing reports' solved policy."""
    sample = set()
    for line in SAMPLE_MANIFEST.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        problem = normalize(line)
        fields = parse_problem_name(problem)
        if (fields["n_colori"] == 3 and 3 <= fields["dim_x"] <= 6
                and 3 <= fields["dim_y"] <= 6):
            sample.add(problem)
    if not sample:
        raise ValueError("Nessuna istanza nel campione per il filtro richiesto.")

    data = {}
    warnings: list[str] = []
    for key, spec in RUNS.items():
        rows = read_run(spec, TIMEOUT, warnings)
        data[key] = {problem: row for problem, row in rows.items() if problem in sample}
        if not data[key]:
            raise ValueError(f"Nessun risultato del campione in {spec.path / 'stats.csv'}")
    for warning in warnings:
        print(f"Avviso: {warning}")
    return sample, data


def average_times(rows: dict[str, Row], problems: set[str]) -> dict[tuple[int, int], float]:
    """Group by ordered (rows, columns): 5×6 and 6×5 stay separate."""
    grouped = defaultdict(list)
    for problem in sorted(problems):
        fields = parse_problem_name(problem)
        grouped[fields["dim_x"], fields["dim_y"]].append(rows[problem].runtime)
    return {size: mean(values) for size, values in sorted(grouped.items())}


def build_surface_grid(data, x_unique, y_unique):
    """Interpolate only inside the observed grid sizes' convex hull for display."""
    x_grid, y_grid = np.meshgrid(x_unique, y_unique)
    points = np.array(list(data), dtype=float)
    values = np.array(list(data.values()), dtype=float)
    if len(points) >= 3 and np.linalg.matrix_rank(points - points[0]) == 2:
        triangulation = Triangulation(points[:, 0], points[:, 1])
        interpolator = LinearTriInterpolator(triangulation, values)
        return x_grid, y_grid, interpolator(x_grid, y_grid).filled(np.nan)
    z_grid = np.full(x_grid.shape, np.nan)
    for j, columns in enumerate(y_unique):
        for i, rows in enumerate(x_unique):
            z_grid[j, i] = data.get((rows, columns), np.nan)
    return x_grid, y_grid, z_grid


def plot_3d_pair(panel, key_a, key_b, data, sample, total_time=False):
    """Plot arithmetic runtime means over the same solved instances in each pair."""
    import matplotlib.pyplot as plt

    keys = (key_a, key_b)
    solved = {key: {p for p, row in data[key].items() if row.solved} for key in keys}
    shared = solved[key_a] & solved[key_b]
    if not shared:
        raise ValueError(f"Nessuna istanza risolta in comune: {key_a}, {key_b}")
    sizes = {p: parse_problem_name(p) for p in sample}
    all_x = sorted({fields["dim_x"] for fields in sizes.values()})
    all_y = sorted({fields["dim_y"] for fields in sizes.values()})

    fig = plt.figure(figsize=(11, 9))
    ax = fig.add_axes((0.015, 0.085, 0.9, 0.9), projection="3d")
    ax.patch.set_alpha(0)
    markers = ("o", "s") if total_time else ("s", "o")
    for key, marker in zip(keys, markers):
        averages = average_times(data[key], shared)
        x_grid, y_grid, z_grid = build_surface_grid(averages, all_x, all_y)
        rgb = np.array(to_rgb(COLORS[key]))
        edge = tuple(0.5 * rgb)
        cmap = LinearSegmentedColormap.from_list(
            f"surface_{key}", ["white", tuple(0.65 + 0.35 * rgb), COLORS[key], tuple(0.7 * rgb)],
        )
        valid = np.isfinite(z_grid)
        surface_points = np.column_stack((x_grid[valid], y_grid[valid]))
        if (len(surface_points) >= 3
                and np.linalg.matrix_rank(surface_points - surface_points[0]) == 2):
            ax.plot_trisurf(x_grid[valid], y_grid[valid], z_grid[valid], cmap=cmap,
                            edgecolor=edge, linewidth=0.55, alpha=0.65, antialiased=True)
        x = [size[0] for size in averages]
        y = [size[1] for size in averages]
        z = list(averages.values())
        label = r"New GBFS-$h^{colour}$" if total_time and key == "new-colour" else RUNS[key].label
        ax.scatter(x, y, z, color=COLORS[key], marker=marker, s=58,
                   edgecolors=edge, linewidths=0.9, depthshade=False, label=label)

    ax.set_xlabel("Rows", labelpad=20, fontweight="bold", fontsize=16)
    ax.set_ylabel("Columns", labelpad=20, fontweight="bold", fontsize=16)
    z_label = "Avg Total Time (s)" if total_time else "Avg Planning Time (s)"
    ax.set_zlabel(z_label, labelpad=20, fontweight="bold", fontsize=16)
    ax.set_xticks(all_x)
    ax.set_yticks(all_y)
    ax.set_zlim(bottom=0)
    ax.view_init(elev=15, azim=-60)
    ax.set_box_aspect((1.05, 1.05, 0.9), zoom=1.07)
    ax.tick_params(labelsize=13, pad=3)
    for axis in (ax.xaxis, ax.yaxis, ax.zaxis):
        axis.pane.fill = False
        axis.pane.set_edgecolor("#dddddd")
        axis.line.set_color("#cccccc")
        axis._axinfo["grid"].update({"linestyle": ":", "linewidth": 0.5, "color": "#b7b7b7"})
    ax.legend(loc="upper left", bbox_to_anchor=(0, 0.91), fontsize=21,
              framealpha=0.92, edgecolor="#cccccc", fancybox=True,
              handletextpad=0.6, borderpad=0.5)
    if panel:
        ax.text2D(0.5, 0.035, panel, transform=ax.transAxes,
                  ha="center", va="top", fontsize=25)
    return fig


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=OUTPUT,
                        help="Cartella di destinazione dei quattro grafici")
    parser.add_argument("--show", action="store_true", help="Mostra anche le finestre interattive")
    args = parser.parse_args()
    if not args.show:
        matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 11})
    try:
        sample, data = load_and_prepare()
    except (OSError, ValueError) as error:
        parser.error(str(error))
    for filename, panel, key_a, key_b, total_time in COMPARISONS:
        fig = plot_3d_pair(panel, key_a, key_b, data, sample, total_time)
        stem = args.output_dir / filename
        stem.parent.mkdir(parents=True, exist_ok=True)
        for suffix in ("png", "pdf"):
            path = stem.with_suffix(f".{suffix}")
            fig.savefig(path, dpi=200, bbox_inches="tight")
            print(f"Grafico salvato in: {path}")
        if not args.show:
            plt.close(fig)
    if args.show:
        plt.show()
        plt.close("all")


if __name__ == "__main__":
    main()
