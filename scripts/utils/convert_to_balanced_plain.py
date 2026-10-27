#!/usr/bin/env python3
"""Convert existing Plotting instances to the plain balanced numeric encoding.

This converter deliberately DOES NOT precompute action footprints such as
row-prefix, column-prefix, gravity maps or waterfall maps.  It only translates
the state representation to the colleague-style balanced model:

  * numeric colour-of(cell): 0 = empty, >=1 = real colour id
  * numeric hand-colour: -1 = wildcard
  * numeric colour-id(colour)
  * row/col coordinates
  * sparse immediate adjacency right/above
  * islastcol / isbottomrow and blockedrow / blockedcol facts

Supported sources:
  --model direct    pddl/instances-direct-numeric/*.pddl
  --model granular  pddl/instances/*-problem.pddl
  --model balanced  already-balanced problem files
  --model auto      auto-detect

The output is intended for pddl/domains/numeric-balanced-best.pddl, not the
hybrid domain with precompiled geometric footprints.

Examples:
  python3 scripts/convert_to_balanced_plain.py --model direct \
      pddl/instances-direct-numeric --overwrite

  python3 scripts/convert_to_balanced_plain.py --model granular \
      pddl/instances --overwrite
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple


CELL_RE = re.compile(r"^r(\d+)c(\d+)$", re.IGNORECASE)
LOC_RE = re.compile(r"^loc_(\d+)_(\d+)$", re.IGNORECASE)
COLOURED_RE = re.compile(
    r"\(\s*coloured\s+([A-Za-z0-9_-]+)\s+([A-Za-z0-9_-]+)\s*\)",
    re.IGNORECASE,
)
HAND_RE = re.compile(r"\(\s*hand\s+([A-Za-z0-9_-]+)\s*\)", re.IGNORECASE)
ROW_RE = re.compile(r"\(=\s*\(row\s+([A-Za-z0-9_-]+)\)\s*(-?\d+(?:\.\d+)?)\s*\)", re.IGNORECASE)
COL_RE = re.compile(r"\(=\s*\(col\s+([A-Za-z0-9_-]+)\)\s*(-?\d+(?:\.\d+)?)\s*\)", re.IGNORECASE)
COLOUR_OF_RE = re.compile(r"\(=\s*\(colour-of\s+([A-Za-z0-9_-]+)\)\s*(-?\d+(?:\.\d+)?)\s*\)", re.IGNORECASE)
COLOUR_ID_RE = re.compile(r"\(=\s*\(colour-id\s+([A-Za-z0-9_-]+)\)\s*(-?\d+(?:\.\d+)?)\s*\)", re.IGNORECASE)
HAND_COLOUR_RE = re.compile(r"\(=\s*\(hand-colour\)\s*(-?\d+(?:\.\d+)?)\s*\)", re.IGNORECASE)
TOTAL_BLOCK_RE = re.compile(r"\(=\s*\(total-block\)\s*(-?\d+(?:\.\d+)?)\s*\)", re.IGNORECASE)
GOAL_TOTAL_RE = re.compile(r"\(<=\s*\(total-block\)\s*(\d+(?:\.\d+)?)\s*\)", re.IGNORECASE)
BLOCKED_ROW_RE = re.compile(r"\(\s*blockedrow\s+([A-Za-z0-9_-]+)\s*\)", re.IGNORECASE)
BLOCKED_COL_RE = re.compile(r"\(\s*blockedcol\s+([A-Za-z0-9_-]+)\s*\)", re.IGNORECASE)
PROBLEM_NAME_RE = re.compile(r"\(define\s*\(problem\s+([^\s\)]+)\)", re.IGNORECASE)


@dataclass(frozen=True)
class Cell:
    name: str
    row: int
    col: int


@dataclass
class NormalizedProblem:
    name: str
    rows: int
    cols: int
    cells: List[Cell]
    colours: List[str]
    colour_ids: Dict[str, int]
    cell_colours: Dict[str, int]
    hand_colour: int
    goal_total: int
    total_block: int
    blocked_rows: List[int]
    blocked_cols: List[int]


def strip_comments(text: str) -> str:
    return "\n".join(line.split(";", 1)[0] for line in text.splitlines())


def balanced_parentheses(text: str) -> bool:
    bal = 0
    for line in text.splitlines():
        for ch in line.split(";", 1)[0]:
            if ch == "(":
                bal += 1
            elif ch == ")":
                bal -= 1
                if bal < 0:
                    return False
    return bal == 0


def extract_section(text: str, marker: str) -> str:
    """Return the full parenthesized section beginning with e.g. '(:goal'."""
    low = text.lower()
    start = low.find(marker.lower())
    if start < 0:
        raise ValueError(f"Cannot find section {marker}")
    paren = text.rfind("(", 0, start + 1)
    if paren < 0:
        paren = start
    depth = 0
    in_comment = False
    for i in range(paren, len(text)):
        ch = text[i]
        if in_comment:
            if ch == "\n":
                in_comment = False
            continue
        if ch == ";":
            in_comment = True
            continue
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return text[paren : i + 1]
    raise ValueError(f"Unterminated section {marker}")


def extract_problem_name(text: str, source: str) -> str:
    m = PROBLEM_NAME_RE.search(text)
    if not m:
        raise ValueError(f"Cannot read problem name from {source}")
    return m.group(1)


def extract_typed_objects(text: str) -> Dict[str, List[str]]:
    section = extract_section(text, "(:objects")
    body = re.sub(r"^\s*\(:objects\b", "", strip_comments(section), flags=re.IGNORECASE)
    body = body.rsplit(")", 1)[0]
    tokens = re.findall(r"[A-Za-z0-9_-]+|-", body)
    out: Dict[str, List[str]] = {}
    pending: List[str] = []
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if tok == "-":
            if i + 1 >= len(tokens):
                raise ValueError("Dangling '-' in :objects")
            typ = tokens[i + 1].lower()
            out.setdefault(typ, []).extend(pending)
            pending = []
            i += 2
        else:
            pending.append(tok)
            i += 1
    if pending:
        raise ValueError(f"Untyped objects at end of :objects: {pending}")
    return out


def canonical_lookup(mapping: Dict[str, int], token: str) -> Optional[int]:
    low = token.lower()
    for key, value in mapping.items():
        if key.lower() == low:
            return value
    return None


def normalize_direct(text: str, source: str) -> NormalizedProblem:
    objects = extract_typed_objects(text)
    raw_cells = objects.get("cell", [])
    colours = objects.get("colour", [])
    if not raw_cells or not colours:
        raise ValueError(f"{source}: direct model requires cell and colour objects")

    cells: List[Cell] = []
    for name in raw_cells:
        m = CELL_RE.fullmatch(name)
        if not m:
            raise ValueError(f"{source}: unsupported direct cell name {name!r}")
        cells.append(Cell(name, int(m.group(1)), int(m.group(2))))

    rows = max(c.row for c in cells)
    cols = max(c.col for c in cells)
    expected = {(r, c) for r in range(1, rows + 1) for c in range(1, cols + 1)}
    actual = {(c.row, c.col) for c in cells}
    if actual != expected:
        missing = sorted(expected - actual)
        raise ValueError(f"{source}: grid is not rectangular; missing {missing[:10]}")

    # Preserve c1,c2,... numbering when available; otherwise object order.
    def colour_key(item: Tuple[int, str]) -> Tuple[int, int, str]:
        idx, name = item
        m = re.fullmatch(r"c(\d+)", name, re.IGNORECASE)
        return (0, int(m.group(1)), name.lower()) if m else (1, idx, name.lower())

    colours = [name for _, name in sorted(enumerate(colours), key=colour_key)]
    colour_ids = {name: i + 1 for i, name in enumerate(colours)}

    cell_colours = {c.name: 0 for c in cells}
    for cell, colour in COLOURED_RE.findall(text):
        if cell not in cell_colours:
            continue
        low = colour.lower()
        if low in ("null", "none"):
            cell_colours[cell] = 0
        elif low in ("wildcard", "wall"):
            if low == "wall":
                raise ValueError(f"{source}: wall colour found inside direct cell grid at {cell}")
            cell_colours[cell] = 0
        else:
            cid = canonical_lookup(colour_ids, colour)
            if cid is None:
                raise ValueError(f"{source}: unknown colour {colour!r}")
            cell_colours[cell] = cid

    hand_matches = HAND_RE.findall(text)
    if len(hand_matches) != 1:
        raise ValueError(f"{source}: expected exactly one (hand ...), found {len(hand_matches)}")
    hand_tok = hand_matches[0]
    if hand_tok.lower() == "wildcard":
        hand_colour = -1
    elif hand_tok.lower() in ("null", "none"):
        hand_colour = 0
    else:
        cid = canonical_lookup(colour_ids, hand_tok)
        if cid is None:
            raise ValueError(f"{source}: unknown hand colour {hand_tok!r}")
        hand_colour = cid

    gm = GOAL_TOTAL_RE.search(text)
    if not gm:
        raise ValueError(f"{source}: cannot find (<= (total-block) K) goal")
    goal_total = int(float(gm.group(1)))

    tm = TOTAL_BLOCK_RE.search(text)
    counted = sum(v > 0 for v in cell_colours.values())
    total_block = int(float(tm.group(1))) if tm else counted
    if total_block != counted:
        raise ValueError(f"{source}: total-block={total_block}, but counted {counted} real blocks")

    by_name = {c.name: c for c in cells}
    blocked_rows = sorted({by_name[x].row for x in BLOCKED_ROW_RE.findall(text) if x in by_name})
    blocked_cols = sorted({by_name[x].col for x in BLOCKED_COL_RE.findall(text) if x in by_name})

    return NormalizedProblem(
        name=extract_problem_name(text, source),
        rows=rows,
        cols=cols,
        cells=sorted(cells, key=lambda c: (c.row, c.col)),
        colours=colours,
        colour_ids=colour_ids,
        cell_colours=cell_colours,
        hand_colour=hand_colour,
        goal_total=goal_total,
        total_block=total_block,
        blocked_rows=blocked_rows,
        blocked_cols=blocked_cols,
    )


def normalize_balanced(text: str, source: str) -> NormalizedProblem:
    objects = extract_typed_objects(text)
    raw_cells = objects.get("cell", [])
    colours = objects.get("colour", [])
    if not raw_cells or not colours:
        raise ValueError(f"{source}: balanced model requires cell and colour objects")

    cells: List[Cell] = []
    for name in raw_cells:
        m = CELL_RE.fullmatch(name)
        if not m:
            raise ValueError(f"{source}: unsupported balanced cell name {name!r}")
        cells.append(Cell(name, int(m.group(1)), int(m.group(2))))
    rows = max(c.row for c in cells)
    cols = max(c.col for c in cells)

    parsed_ids = {name: int(round(float(v))) for name, v in COLOUR_ID_RE.findall(text)}
    colour_ids: Dict[str, int] = {}
    for i, colour in enumerate(colours, 1):
        cid = canonical_lookup(parsed_ids, colour)
        colour_ids[colour] = cid if cid is not None else i

    cell_colours = {c.name: 0 for c in cells}
    for cell, value in COLOUR_OF_RE.findall(text):
        if cell in cell_colours:
            cell_colours[cell] = int(round(float(value)))

    hm = HAND_COLOUR_RE.search(text)
    if not hm:
        raise ValueError(f"{source}: missing hand-colour")
    hand_colour = int(round(float(hm.group(1))))

    gm = GOAL_TOTAL_RE.search(text)
    if not gm:
        raise ValueError(f"{source}: missing numeric total-block goal")
    goal_total = int(float(gm.group(1)))

    tm = TOTAL_BLOCK_RE.search(text)
    counted = sum(v > 0 for v in cell_colours.values())
    total_block = int(float(tm.group(1))) if tm else counted
    if total_block != counted:
        raise ValueError(f"{source}: total-block={total_block}, but counted {counted}")

    by_name = {c.name: c for c in cells}
    blocked_rows = sorted({by_name[x].row for x in BLOCKED_ROW_RE.findall(text) if x in by_name})
    blocked_cols = sorted({by_name[x].col for x in BLOCKED_COL_RE.findall(text) if x in by_name})

    return NormalizedProblem(
        name=extract_problem_name(text, source),
        rows=rows,
        cols=cols,
        cells=sorted(cells, key=lambda c: (c.row, c.col)),
        colours=colours,
        colour_ids=colour_ids,
        cell_colours=cell_colours,
        hand_colour=hand_colour,
        goal_total=goal_total,
        total_block=total_block,
        blocked_rows=blocked_rows,
        blocked_cols=blocked_cols,
    )


def normalize_granular(text: str, source: str) -> NormalizedProblem:
    objects = extract_typed_objects(text)
    locations = objects.get("location", [])
    raw_colours = objects.get("colour", [])
    if not locations:
        raise ValueError(f"{source}: no location objects found")

    coords: Dict[str, Tuple[int, int]] = {}
    for name in locations:
        m = LOC_RE.fullmatch(name)
        if not m:
            raise ValueError(f"{source}: unsupported granular location {name!r}")
        coords[name] = (int(m.group(1)), int(m.group(2)))

    xs = [x for x, _ in coords.values()]
    ys = [y for _, y in coords.values()]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    if min_x != 1 or min_y != 1 or max_x < 3 or max_y < 3:
        raise ValueError(f"{source}: expected granular grid with one-cell border")

    cols = max_x - 2
    rows = max_y - 2

    # Keep real colour names from the original granular problem.  Identity is
    # all that matters; none/wall/wildcard are reserved and not real colours.
    reserved = {"none", "wall", "null", "wildcard"}
    colours = [c for c in raw_colours if c.lower() not in reserved]
    if not colours:
        # Some granular domains may declare colours as constants rather than
        # problem objects.  Infer them from coloured facts in encounter order.
        seen: List[str] = []
        for _, colour in COLOURED_RE.findall(text):
            if colour.lower() not in reserved and colour not in seen:
                seen.append(colour)
        colours = seen
    colour_ids = {name: i + 1 for i, name in enumerate(colours)}

    loc_colour: Dict[str, str] = {}
    for loc, colour in COLOURED_RE.findall(text):
        if loc in coords:
            loc_colour[loc] = colour

    cells: List[Cell] = []
    cell_colours: Dict[str, int] = {}
    for y in range(max_y - 1, 1, -1):  # top interior -> bottom interior
        row = max_y - y
        for x in range(2, max_x):
            col = x - 1
            loc = f"loc_{x}_{y}"
            if loc not in coords:
                raise ValueError(f"{source}: missing interior location {loc}")
            cell = f"r{row}c{col}"
            cells.append(Cell(cell, row, col))
            colour = loc_colour.get(loc, "none")
            low = colour.lower()
            if low in ("none", "null"):
                cell_colours[cell] = 0
            elif low == "wall":
                raise ValueError(f"{source}: wall found in playable interior at {loc}")
            else:
                cid = canonical_lookup(colour_ids, colour)
                if cid is None:
                    raise ValueError(f"{source}: unknown real colour {colour!r} at {loc}")
                cell_colours[cell] = cid

    hand_matches = HAND_RE.findall(text)
    if len(hand_matches) != 1:
        raise ValueError(f"{source}: expected exactly one hand fact")
    hand_tok = hand_matches[0]
    if hand_tok.lower() == "wildcard":
        hand_colour = -1
    elif hand_tok.lower() in ("none", "null"):
        hand_colour = 0
    else:
        cid = canonical_lookup(colour_ids, hand_tok)
        if cid is None:
            raise ValueError(f"{source}: unknown hand colour {hand_tok!r}")
        hand_colour = cid

    goal_section = extract_section(text, "(:goal")
    ks = [int(v) for v in re.findall(r"\(\s*blocks_remaining\s+n(\d+)\s*\)", goal_section, re.IGNORECASE)]
    if not ks:
        raise ValueError(f"{source}: cannot infer granular goal threshold")
    goal_total = max(ks)
    total_block = sum(v > 0 for v in cell_colours.values())

    # The repository's granular encoding has no blockedrow/blockedcol facts.
    # If future granular generators add them with rNcM-style cells this parser
    # can be extended; for the current benchmark both sets are empty.
    return NormalizedProblem(
        name=extract_problem_name(text, source),
        rows=rows,
        cols=cols,
        cells=sorted(cells, key=lambda c: (c.row, c.col)),
        colours=colours,
        colour_ids=colour_ids,
        cell_colours=cell_colours,
        hand_colour=hand_colour,
        goal_total=goal_total,
        total_block=total_block,
        blocked_rows=[],
        blocked_cols=[],
    )


def detect_model(text: str) -> str:
    low = text.lower()
    if "(colour-of " in low or "(colour-id " in low:
        return "balanced"
    if "loc_" in low and "(blocks_remaining " in low:
        return "granular"
    if "(coloured " in low and re.search(r"\br\d+c\d+\b", low):
        return "direct"
    raise ValueError("Cannot auto-detect source model")


def cell_name(row: int, col: int) -> str:
    return f"r{row}c{col}"


def footprint_facts(p: NormalizedProblem) -> List[str]:
    # Intentionally empty: the plain balanced encoding does not precompute
    # row prefixes, gravity maps or waterfall maps.
    return []


def render_problem(p: NormalizedProblem) -> str:
    lines: List[str] = []
    lines.append(f"(define (problem {p.name})")
    lines.append("  (:domain plotting)")
    lines.append("")
    lines.append("  (:objects")

    # Compact but readable rows of cells.
    for r in range(1, p.rows + 1):
        names = " ".join(cell_name(r, c) for c in range(1, p.cols + 1))
        suffix = " - cell" if r == p.rows else ""
        lines.append(f"    {names}{suffix}")
    lines.append("")
    lines.append("    " + " ".join(p.colours) + " - colour")
    lines.append("  )")
    lines.append("")
    lines.append("  (:init")

    lines.append("    ; ── Static numeric coordinates ───────────────────────────────")
    for r in range(1, p.rows + 1):
        lines.append("    " + "  ".join(f"(= (row {cell_name(r,c)}) {r})" for c in range(1, p.cols + 1)))
    for c in range(1, p.cols + 1):
        lines.append("    " + "  ".join(f"(= (col {cell_name(r,c)}) {c})" for r in range(1, p.rows + 1)))

    lines.append("    ; ── Sparse immediate adjacency ───────────────────────────────")
    for r in range(1, p.rows + 1):
        for c in range(1, p.cols):
            lines.append(f"    (right {cell_name(r,c)} {cell_name(r,c+1)})")
    for r in range(1, p.rows):
        for c in range(1, p.cols + 1):
            lines.append(f"    (above {cell_name(r,c)} {cell_name(r+1,c)})")

    lines.append("    ; ── Borders ──────────────────────────────────────────────────")
    for c in range(1, p.cols + 1):
        lines.append(f"    (istoprow {cell_name(1,c)})")
        lines.append(f"    (isbottomrow {cell_name(p.rows,c)})")
    for r in range(1, p.rows + 1):
        lines.append(f"    (islastcol {cell_name(r,p.cols)})")

    if p.blocked_rows or p.blocked_cols:
        lines.append("    ; ── Blocked lines (expanded to every cell on the line) ──────")
        for r in p.blocked_rows:
            for c in range(1, p.cols + 1):
                lines.append(f"    (blockedrow {cell_name(r,c)})")
        for c in p.blocked_cols:
            for r in range(1, p.rows + 1):
                lines.append(f"    (blockedcol {cell_name(r,c)})")

    lines.append("    ; ── Colour IDs ───────────────────────────────────────────────")
    for colour in p.colours:
        lines.append(f"    (= (colour-id {colour}) {p.colour_ids[colour]})")

    lines.append("    ; ── Cell colours (0 = empty) ────────────────────────────────")
    for r in range(1, p.rows + 1):
        chunks = []
        for c in range(1, p.cols + 1):
            n = cell_name(r, c)
            chunks.append(f"(= (colour-of {n}) {p.cell_colours.get(n, 0)})")
        lines.append("    " + "  ".join(chunks))

    lines.append("    ; ── Hand and block counter ───────────────────────────────────")
    lines.append(f"    (= (hand-colour) {p.hand_colour})")
    lines.append(f"    (= (total-block) {p.total_block})")
    lines.append("  )")
    lines.append("")
    lines.append("  (:goal")
    lines.append(f"    (<= (total-block) {p.goal_total})")
    lines.append("  )")
    lines.append(")")
    lines.append("")
    return "\n".join(lines)


def normalize(text: str, source: str, model: str) -> NormalizedProblem:
    if not balanced_parentheses(text):
        raise ValueError(f"{source}: unbalanced parentheses")
    effective = detect_model(text) if model == "auto" else model
    if effective == "direct":
        return normalize_direct(text, source)
    if effective == "granular":
        return normalize_granular(text, source)
    if effective == "balanced":
        return normalize_balanced(text, source)
    raise ValueError(f"Unsupported model {effective}")


def iter_sources(inputs: Sequence[Path], model: str) -> Iterable[Path]:
    for p in inputs:
        if p.is_file():
            yield p
            continue
        if not p.is_dir():
            raise FileNotFoundError(p)
        if model == "granular":
            yield from sorted(p.glob("*-problem.pddl"))
        elif model == "auto":
            # Avoid per-instance granular domains; include direct/balanced files
            # and granular *-problem files.
            for q in sorted(p.glob("*.pddl")):
                if q.name.endswith("-domain.pddl"):
                    continue
                yield q
        else:
            for q in sorted(p.glob("*.pddl")):
                if not q.name.endswith("-domain.pddl") and not q.name.endswith("-problem.pddl"):
                    yield q


def destination_name(source: Path) -> str:
    name = source.name
    if name.endswith("-problem.pddl"):
        return name[: -len("-problem.pddl")] + ".pddl"
    return name


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("inputs", nargs="+", type=Path, help="Input PDDL files/directories")
    ap.add_argument(
        "-o",
        "--output-dir",
        type=Path,
        default=Path("pddl/instances-direct-numeric-opt"),
        help="Output directory (default: pddl/instances-direct-numeric-opt)",
    )
    ap.add_argument("--model", choices=["auto", "direct", "granular", "balanced"], default="auto")
    ap.add_argument("--overwrite", action="store_true")
    ap.add_argument("--fail-fast", action="store_true", help="Stop on first conversion error")
    args = ap.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    ok = 0
    failed = 0

    for source in iter_sources(args.inputs, args.model):
        dest = args.output_dir / destination_name(source)
        try:
            if dest.exists() and not args.overwrite:
                raise FileExistsError(f"{dest} exists; use --overwrite")
            text = source.read_text(encoding="utf-8")
            p = normalize(text, str(source), args.model)
            rendered = render_problem(p)
            if not balanced_parentheses(rendered):
                raise AssertionError("internal error: generated PDDL is unbalanced")
            dest.write_text(rendered, encoding="utf-8")
            ok += 1
            print(
                f"converted [{detect_model(text) if args.model == 'auto' else args.model}] "
                f"{source} -> {dest}  ({p.rows}x{p.cols}, colours={len(p.colours)}, "
                f"blocks={p.total_block}, goal={p.goal_total})"
            )
        except Exception as exc:
            failed += 1
            print(f"ERROR {source}: {exc}")
            if args.fail_fast:
                raise

    print(f"done: converted={ok}, failed={failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
