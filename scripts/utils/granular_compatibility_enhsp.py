#!/usr/bin/env python3
"""
v3 - source-to-source converter for the granular Plotting PDDL instances.

It DOES NOT replace every domain with one fixed template.

For each pair:
    <name>-domain.pddl
    <name>-problem.pddl

the converter reads the actual domain of that instance, preserves its actions
(including the instance-specific shooting_row_N / shooting_column_N actions),
and only performs the transformations needed to remove the derived predicate
`falling_flag` and make the pair standard/ENHSP-friendly.

Defaults:
    source: benchmarks/pddl/instances
    dest:   benchmarks/pddl/instances-granular-enhsp-compatible

The source files are never modified.
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = PROJECT_ROOT / "benchmarks/pddl/instances"
DEFAULT_DEST = PROJECT_ROOT / "benchmarks/pddl/instances-granular-enhsp-compatible"

DEFINE_DOMAIN_RE = re.compile(
    r"\(\s*define\s*\(\s*domain\s+([^\s()]+)\s*\)",
    re.IGNORECASE,
)
DEFINE_PROBLEM_RE = re.compile(
    r"\(\s*define\s*\(\s*problem\s+([^\s()]+)\s*\)",
    re.IGNORECASE,
)

NEG_FALLING_RE = re.compile(
    r"\(\s*not\s*\(\s*falling_flag\s*\)\s*\)",
    re.IGNORECASE,
)
POS_FALLING_RE = re.compile(
    r"\(\s*falling_flag\s*\)",
    re.IGNORECASE,
)

LOC_NAME_RE = re.compile(r"^loc_(\d+)_(\d+)$", re.IGNORECASE)
LOC_ANY_RE = re.compile(r"\bloc_\d+_\d+\b", re.IGNORECASE)

NEXT_LINE_RE = re.compile(
    r"^(?P<indent>\s*)"
    r"\(next\s+"
    r"(?P<src>loc_\d+_\d+)\s+"
    r"(?P<dst>loc_\d+_\d+)\s+"
    r"(?P<direction>up|down|left|right)"
    r"\)\s*$",
    re.IGNORECASE,
)

TOTAL_COST_INIT_RE = re.compile(
    r"\(=\s*\(total-cost\)\s*[-+]?(?:\d+(?:\.\d*)?|\.\d+)\s*\)",
    re.IGNORECASE,
)

REQUIRED_REQUIREMENTS = [
    ":typing",
    ":equality",
    ":negative-preconditions",
    ":disjunctive-preconditions",
    ":existential-preconditions",
    ":universal-preconditions",
    ":conditional-effects",
    ":fluents",
    ":action-costs",
]


# ---------------------------------------------------------------------------
# Generic text / PDDL helpers
# ---------------------------------------------------------------------------

def strip_comments(text: str) -> str:
    return re.sub(r";[^\n]*", "", text)


def check_balanced(text: str) -> None:
    """Check parentheses while ignoring comments."""
    depth = 0
    in_comment = False

    for i, ch in enumerate(text):
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
            if depth < 0:
                raise ValueError(f"Unexpected ')' at character {i}")

    if depth != 0:
        raise ValueError(f"Unbalanced parentheses: final depth = {depth}")


def find_matching_paren(text: str, start: int) -> int:
    if start < 0 or start >= len(text) or text[start] != "(":
        raise ValueError("find_matching_paren must start on '('")

    depth = 0
    in_comment = False

    for i in range(start, len(text)):
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
                return i

    raise ValueError("No matching ')' found")


def find_section(text: str, keyword: str) -> tuple[int, int]:
    m = re.search(
        r"\(\s*:" + re.escape(keyword) + r"\b",
        text,
        re.IGNORECASE,
    )
    if not m:
        raise ValueError(f"Missing (:{keyword} ...) section")
    start = m.start()
    return start, find_matching_paren(text, start)


def classify_pddl(text: str) -> tuple[str, str]:
    uncommented = strip_comments(text)
    md = DEFINE_DOMAIN_RE.search(uncommented)
    mp = DEFINE_PROBLEM_RE.search(uncommented)

    if md and not mp:
        return "domain", md.group(1)
    if mp and not md:
        return "problem", mp.group(1)

    raise ValueError("Cannot classify file as a PDDL domain or problem")


def canonical_key(path: Path, kind: str) -> str:
    stem = path.stem
    lower = stem.lower()

    suffixes = (
        ["-domain", "_domain", ".domain"]
        if kind == "domain"
        else ["-problem", "_problem", ".problem"]
    )

    for suffix in suffixes:
        if lower.endswith(suffix):
            return stem[: -len(suffix)]

    # Also support a problem named simply <key>.pddl.
    return stem


def replace_section(text: str, keyword: str, replacement: str) -> str:
    start, end = find_section(text, keyword)
    return text[:start] + replacement + text[end + 1:]


def insert_after_section(text: str, keyword: str, insertion: str) -> str:
    _, end = find_section(text, keyword)
    return text[: end + 1] + insertion + text[end + 1:]


# ---------------------------------------------------------------------------
# Small S-expression parser, used only for the derived formula
# ---------------------------------------------------------------------------

TOKEN_RE = re.compile(r"\(|\)|[^\s()]+")


def tokenize_sexpr(text: str) -> list[str]:
    return TOKEN_RE.findall(strip_comments(text))


def parse_one(tokens: list[str], pos: int = 0) -> tuple[Any, int]:
    if pos >= len(tokens):
        raise ValueError("Unexpected end of S-expression")

    tok = tokens[pos]

    if tok != "(":
        return tok, pos + 1

    result = []
    pos += 1

    while True:
        if pos >= len(tokens):
            raise ValueError("Unclosed S-expression")
        if tokens[pos] == ")":
            return result, pos + 1

        item, pos = parse_one(tokens, pos)
        result.append(item)


def parse_sexpr(text: str) -> Any:
    tokens = tokenize_sexpr(text)
    expr, pos = parse_one(tokens, 0)

    if pos != len(tokens):
        raise ValueError("Extra tokens after S-expression")

    return expr


def sexpr_to_pddl(expr: Any) -> str:
    if isinstance(expr, str):
        return expr
    return "(" + " ".join(sexpr_to_pddl(x) for x in expr) + ")"


def negate_nnf(expr: Any) -> Any:
    """
    Return the logical negation of expr in negation-normal form.

    Supported connectives are enough for ordinary PDDL precondition formulae:
    and, or, not, exists, forall, imply. Any other list is treated as an
    atomic formula.
    """
    if isinstance(expr, str):
        # A bare symbol should not normally be a complete PDDL formula, but
        # treating it atomically is the safest fallback.
        return ["not", expr]

    if not expr:
        return ["not", expr]

    head = expr[0].lower() if isinstance(expr[0], str) else None

    if head == "not":
        if len(expr) != 2:
            raise ValueError("Malformed (not ...) formula")
        return expr[1]

    if head == "and":
        return ["or"] + [negate_nnf(x) for x in expr[1:]]

    if head == "or":
        return ["and"] + [negate_nnf(x) for x in expr[1:]]

    if head == "exists":
        if len(expr) != 3:
            raise ValueError("Malformed (exists (...) ...) formula")
        return ["forall", expr[1], negate_nnf(expr[2])]

    if head == "forall":
        if len(expr) != 3:
            raise ValueError("Malformed (forall (...) ...) formula")
        return ["exists", expr[1], negate_nnf(expr[2])]

    if head == "imply":
        if len(expr) != 3:
            raise ValueError("Malformed (imply A B) formula")
        # not(A -> B) == A and not B
        return ["and", expr[1], negate_nnf(expr[2])]

    # Atomic formula, including equality/comparison predicates.
    return ["not", expr]


# ---------------------------------------------------------------------------
# Typed-list parsing for :constants and :objects
# ---------------------------------------------------------------------------

def parse_typed_items(section_text: str, keyword: str) -> list[tuple[str, str | None]]:
    """
    Parse a PDDL typed list such as:
        a b - colour
        x y - location

    Returns [(name, type_or_None), ...].
    """
    clean = strip_comments(section_text)
    clean = re.sub(
        r"^\(\s*:" + re.escape(keyword) + r"\b",
        "",
        clean,
        flags=re.IGNORECASE,
    )
    clean = re.sub(r"\)\s*$", "", clean)

    tokens = re.findall(r"[^\s()]+", clean)

    result: list[tuple[str, str | None]] = []
    pending: list[str] = []
    i = 0

    while i < len(tokens):
        tok = tokens[i]

        if tok == "-":
            if not pending or i + 1 >= len(tokens):
                raise ValueError(f"Malformed typed list in :{keyword}")
            typ = tokens[i + 1]
            result.extend((name, typ) for name in pending)
            pending = []
            i += 2
        else:
            pending.append(tok)
            i += 1

    result.extend((name, None) for name in pending)
    return result


def render_typed_section(
    keyword: str,
    items: list[tuple[str, str | None]],
    indent: str = "    ",
) -> str:
    lines = [f"{indent}(:{keyword}"]

    for name, typ in items:
        if typ is None:
            lines.append(f"{indent}    {name}")
        else:
            lines.append(f"{indent}    {name} - {typ}")

    lines.append(f"{indent})")
    return "\n".join(lines)


def get_typed_section_items(
    text: str,
    keyword: str,
) -> tuple[list[tuple[str, str | None]], tuple[int, int] | None]:
    try:
        start, end = find_section(text, keyword)
    except ValueError:
        return [], None

    section = text[start:end + 1]
    return parse_typed_items(section, keyword), (start, end)


# ---------------------------------------------------------------------------
# Derived predicate extraction
# ---------------------------------------------------------------------------

@dataclass
class DerivedInfo:
    start: int
    end: int
    body_expr: Any
    body_pddl: str
    negated_body_pddl: str


def find_falling_derived(text: str) -> DerivedInfo:
    """
    Locate exactly one:
        (:derived (falling_flag) BODY)
    and return BODY plus the exact block range.
    """
    candidates: list[tuple[int, int, Any]] = []

    for m in re.finditer(r"\(\s*:derived\b", text, re.IGNORECASE):
        start = m.start()
        end = find_matching_paren(text, start)
        block = text[start:end + 1]

        try:
            expr = parse_sexpr(block)
        except Exception:
            continue

        if (
            isinstance(expr, list)
            and len(expr) >= 3
            and isinstance(expr[0], str)
            and expr[0].lower() == ":derived"
            and isinstance(expr[1], list)
            and len(expr[1]) == 1
            and isinstance(expr[1][0], str)
            and expr[1][0].lower() == "falling_flag"
        ):
            candidates.append((start, end, expr[2]))

    if len(candidates) != 1:
        raise ValueError(
            "Expected exactly one zero-arity "
            "(:derived (falling_flag) ...) rule; "
            f"found {len(candidates)}"
        )

    start, end, body_expr = candidates[0]
    body_pddl = sexpr_to_pddl(body_expr)
    negated = sexpr_to_pddl(negate_nnf(body_expr))

    return DerivedInfo(
        start=start,
        end=end,
        body_expr=body_expr,
        body_pddl=body_pddl,
        negated_body_pddl=negated,
    )


# ---------------------------------------------------------------------------
# Domain conversion
# ---------------------------------------------------------------------------

def convert_requirements(text: str) -> str:
    start, end = find_section(text, "requirements")
    section = strip_comments(text[start:end + 1])
    tokens = re.findall(r":[A-Za-z0-9_-]+", section)

    out = []
    seen = set()

    for token in tokens:
        tl = token.lower()

        # The regexp also sees the section keyword itself in
        # "(:requirements ...)".  It must NOT be copied as a requirement.
        if tl in {":requirements", ":derived-predicates"}:
            continue

        if tl not in seen:
            out.append(token)
            seen.add(tl)

    for token in REQUIRED_REQUIREMENTS:
        if token.lower() not in seen:
            out.append(token)
            seen.add(token.lower())

    replacement = "    (:requirements " + " ".join(out) + ")"
    return text[:start] + replacement + text[end + 1:]


def remove_falling_predicate_declaration(text: str) -> str:
    start, end = find_section(text, "predicates")
    section = text[start:end + 1]

    # The benchmark uses a zero-arity declaration. This regex allows arbitrary
    # whitespace and an optional trailing comment on the same line.
    updated, count = re.subn(
        r"(?im)^[ \t]*\(\s*falling_flag\s*\)[ \t]*(?:;[^\n]*)?\r?\n?",
        "",
        section,
    )

    if count != 1:
        # Fallback for unusual formatting: remove the exact atom once.
        updated2, count2 = re.subn(
            r"\(\s*falling_flag\s*\)",
            "",
            section,
            count=1,
            flags=re.IGNORECASE,
        )
        if count2 != 1:
            raise ValueError(
                "Could not remove the (falling_flag) predicate declaration"
            )
        updated = updated2

    return text[:start] + updated + text[end + 1:]


def replace_falling_uses(
    text: str,
    positive_body: str,
    negative_body: str,
) -> str:
    # Negative first so the positive regexp does not replace its inner atom.
    text = NEG_FALLING_RE.sub(negative_body, text)
    text = POS_FALLING_RE.sub(positive_body, text)
    return text


def loc_sort_key(name: str) -> tuple[int, int, str]:
    m = LOC_NAME_RE.match(name)
    if not m:
        return (10**9, 10**9, name.lower())
    return (int(m.group(1)), int(m.group(2)), name.lower())


def hardcoded_locations_in_domain(text: str) -> list[str]:
    """
    All explicit loc_X_Y symbols occurring in the domain are instance-specific
    constants (e.g. in shooting_row_5 effects).
    """
    names = {m.group(0).lower() for m in LOC_ANY_RE.finditer(strip_comments(text))}
    return sorted(names, key=loc_sort_key)


def ensure_domain_constants(
    text: str,
    hardcoded_locations: list[str],
) -> tuple[str, list[tuple[str, str | None]]]:
    items, bounds = get_typed_section_items(text, "constants")

    existing = {name.lower() for name, _ in items}

    additions: list[tuple[str, str | None]] = []

    for name in ("none", "wall"):
        if name not in existing:
            additions.append((name, "colour"))
            existing.add(name)

    for loc in hardcoded_locations:
        if loc.lower() not in existing:
            additions.append((loc, "location"))
            existing.add(loc.lower())

    all_items = items + additions
    replacement = render_typed_section("constants", all_items)

    if bounds is not None:
        start, end = bounds
        text = text[:start] + replacement + text[end + 1:]
    else:
        # Insert after :types if the original domain had no :constants block.
        try:
            text = insert_after_section(text, "types", "\n\n" + replacement)
        except ValueError:
            text = insert_after_section(text, "requirements", "\n\n" + replacement)

    return text, all_items


def ensure_total_cost_function(text: str) -> str:
    items_bounds = None
    try:
        start, end = find_section(text, "functions")
        items_bounds = (start, end)
    except ValueError:
        pass

    if items_bounds is not None:
        start, end = items_bounds
        section = text[start:end + 1]
        if re.search(r"\(\s*total-cost\s*\)", strip_comments(section), re.IGNORECASE):
            return text

        # Insert immediately before the closing ')' of :functions.
        insertion = "\n        (total-cost)\n    "
        return text[:end] + insertion + text[end:]

    functions = "    (:functions\n        (total-cost)\n    )"
    return insert_after_section(text, "predicates", "\n\n" + functions)


@dataclass
class DomainConversion:
    text: str
    body_pddl: str
    negated_body_pddl: str
    domain_constants: dict[str, str | None]
    hardcoded_locations: list[str]


def convert_domain(text: str) -> DomainConversion:
    kind, _ = classify_pddl(text)
    if kind != "domain":
        raise ValueError("convert_domain called on a non-domain file")

    check_balanced(text)

    derived = find_falling_derived(text)

    # Remove the derived rule first.
    text = text[:derived.start] + text[derived.end + 1:]

    text = convert_requirements(text)
    text = remove_falling_predicate_declaration(text)

    # Preserve all instance-specific actions. Only replace their references
    # to falling_flag with the actual formula from THIS domain file.
    text = replace_falling_uses(
        text,
        positive_body=derived.body_pddl,
        negative_body=derived.negated_body_pddl,
    )

    # Explicit object names used inside a domain action must be domain
    # constants in standard PDDL.
    hardcoded_locs = hardcoded_locations_in_domain(text)
    text, constants = ensure_domain_constants(text, hardcoded_locs)

    # The benchmark increments total-cost; declare it if the generator omitted
    # the :functions section.
    text = ensure_total_cost_function(text)

    # Validation.
    clean = strip_comments(text)

    if ":derived-predicates" in clean.lower():
        raise ValueError(":derived-predicates remains in converted domain")
    if re.search(r"\(\s*:derived\b", clean, re.IGNORECASE):
        raise ValueError("A :derived rule remains in converted domain")
    if re.search(r"\bfalling_flag\b", clean, re.IGNORECASE):
        raise ValueError("falling_flag remains in converted domain")

    check_balanced(text)

    const_map = {name.lower(): typ for name, typ in constants}

    return DomainConversion(
        text=text,
        body_pddl=derived.body_pddl,
        negated_body_pddl=derived.negated_body_pddl,
        domain_constants=const_map,
        hardcoded_locations=hardcoded_locs,
    )


# ---------------------------------------------------------------------------
# Problem conversion
# ---------------------------------------------------------------------------

def rewrite_problem_objects(
    text: str,
    domain_constants: dict[str, str | None],
) -> tuple[str, set[str]]:
    start, end = find_section(text, "objects")
    section = text[start:end + 1]
    items = parse_typed_items(section, "objects")

    kept: list[tuple[str, str | None]] = []
    removed = []

    for name, typ in items:
        if name.lower() in domain_constants:
            removed.append(name)
        else:
            kept.append((name, typ))

    replacement = render_typed_section("objects", kept)
    text = text[:start] + replacement + text[end + 1:]

    valid_locations = {
        name.lower()
        for name, typ in kept
        if typ is not None and typ.lower() == "location"
    }

    # Location-valued domain constants are valid locations too.
    valid_locations.update(
        name.lower()
        for name, typ in domain_constants.items()
        if typ is not None and typ.lower() == "location"
    )

    return text, valid_locations


def remove_invalid_next_facts(
    text: str,
    valid_locations: set[str],
) -> tuple[str, list[str]]:
    """
    Remove only the generator's known invalid boundary facts:
        (next <declared-top-cell> <undeclared-cell-above> up)

    Any other dangling `next` fact is reported as an error.
    """
    output = []
    removed = []

    for line in text.splitlines(keepends=True):
        raw = line.rstrip("\r\n")
        m = NEXT_LINE_RE.match(raw)

        if not m:
            output.append(line)
            continue

        src = m.group("src").lower()
        dst = m.group("dst").lower()
        direction = m.group("direction").lower()

        src_ok = src in valid_locations
        dst_ok = dst in valid_locations

        if src_ok and dst_ok:
            output.append(line)
            continue

        if src_ok and not dst_ok and direction == "up":
            removed.append(raw.strip())
            continue

        raise ValueError(
            "Unexpected dangling (next ...) fact: "
            f"{raw.strip()} "
            f"[src declared={src_ok}, dst declared={dst_ok}]"
        )

    return "".join(output), removed


def ensure_total_cost_init(text: str) -> str:
    if TOTAL_COST_INIT_RE.search(strip_comments(text)):
        return text

    _, end = find_section(text, "init")
    insertion = "\n        (= (total-cost) 0)\n    "
    return text[:end] + insertion + text[end:]


@dataclass
class ProblemConversion:
    text: str
    removed_domain_constant_objects: list[str]
    removed_invalid_next_facts: list[str]


def convert_problem(
    text: str,
    domain: DomainConversion,
) -> ProblemConversion:
    kind, _ = classify_pddl(text)
    if kind != "problem":
        raise ValueError("convert_problem called on a non-problem file")

    check_balanced(text)

    # Compile away any goal/problem occurrence using the definition extracted
    # from the paired domain, not a hard-coded template.
    text = replace_falling_uses(
        text,
        positive_body=domain.body_pddl,
        negative_body=domain.negated_body_pddl,
    )

    before_objects = parse_typed_items(
        text[find_section(text, "objects")[0] : find_section(text, "objects")[1] + 1],
        "objects",
    )
    before_names = [name for name, _ in before_objects]

    text, valid_locations = rewrite_problem_objects(
        text,
        domain.domain_constants,
    )

    after_objects = parse_typed_items(
        text[find_section(text, "objects")[0] : find_section(text, "objects")[1] + 1],
        "objects",
    )
    after_names = {name.lower() for name, _ in after_objects}

    removed_constants = [
        name for name in before_names if name.lower() not in after_names
    ]

    text, removed_next = remove_invalid_next_facts(
        text,
        valid_locations,
    )

    text = ensure_total_cost_init(text)

    clean = strip_comments(text)

    if re.search(r"\bfalling_flag\b", clean, re.IGNORECASE):
        raise ValueError("falling_flag remains in converted problem")

    check_balanced(text)

    return ProblemConversion(
        text=text,
        removed_domain_constant_objects=removed_constants,
        removed_invalid_next_facts=removed_next,
    )



def is_granular_domain_text(text: str) -> bool:
    """True only for the granular encoding we want to convert."""
    clean = strip_comments(text)
    return (
        bool(re.search(r"\(\s*:types\b[^)]*\blocation\b", clean, re.I))
        and bool(re.search(r"\(\s*next\b", clean, re.I))
        and bool(re.search(
            r"\(\s*:derived\s*\(\s*falling_flag\s*\)",
            clean,
            re.I,
        ))
    )


# ---------------------------------------------------------------------------
# Pair discovery and batch conversion
# ---------------------------------------------------------------------------

@dataclass
class InputFile:
    path: Path
    kind: str
    name: str
    key: str


def discover_files(source: Path, pattern: str) -> tuple[list[InputFile], list[Path]]:
    """
    Discover ONLY files whose names explicitly end with:
        -domain.pddl
        -problem.pddl

    Any other .pddl file is ignored even if its contents define a valid
    PDDL domain/problem.
    """
    result: list[InputFile] = []
    ignored: list[Path] = []

    for path in sorted(source.rglob(pattern)):
        if not path.is_file():
            continue

        lname = path.name.lower()

        if lname.endswith("-domain.pddl"):
            expected_kind = "domain"
        elif lname.endswith("-problem.pddl"):
            expected_kind = "problem"
        else:
            ignored.append(path)
            continue

        file_text = path.read_text(encoding="utf-8")
        kind, name = classify_pddl(file_text)

        if kind != expected_kind:
            raise ValueError(
                f"Filename/content mismatch for {path}: "
                f"name implies {expected_kind}, contents define {kind}"
            )

        result.append(
            InputFile(
                path=path,
                kind=kind,
                name=name,
                key=canonical_key(path, kind),
            )
        )

    return result, ignored


def choose_domain_for_problem(
    problem: InputFile,
    domains_by_key: dict[str, list[InputFile]],
) -> InputFile:
    candidates = domains_by_key.get(problem.key, [])

    if len(candidates) == 1:
        return candidates[0]

    if len(candidates) > 1:
        raise ValueError(
            f"Multiple domain files match problem {problem.path.name}: "
            + ", ".join(x.path.name for x in candidates)
        )

    # Fallback: if the problem explicitly says (:domain X), try domains whose
    # declared domain name is X. This is only safe if unique.
    ptext = problem.path.read_text(encoding="utf-8")
    m = re.search(
        r"\(\s*:domain\s+([^\s()]+)\s*\)",
        strip_comments(ptext),
        re.IGNORECASE,
    )

    if m:
        requested_name = m.group(1).lower()
        all_domains = [
            d
            for ds in domains_by_key.values()
            for d in ds
            if d.name.lower() == requested_name
        ]

        if len(all_domains) == 1:
            return all_domains[0]

    raise ValueError(
        f"No unique paired domain found for problem {problem.path.name}. "
        f"Expected a domain with key {problem.key!r}."
    )


def output_path(source_root: Path, dest_root: Path, path: Path) -> Path:
    return dest_root / path.relative_to(source_root)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Source-to-source conversion of granular Plotting PDDL pairs "
            "to ENHSP-compatible PDDL without derived predicates."
        )
    )

    parser.add_argument(
        "--source",
        type=Path,
        default=DEFAULT_SOURCE,
        help=f"Source directory (default: {DEFAULT_SOURCE})",
    )
    parser.add_argument(
        "--dest",
        type=Path,
        default=DEFAULT_DEST,
        help=f"Destination directory (default: {DEFAULT_DEST})",
    )
    parser.add_argument(
        "--pattern",
        default="*.pddl",
        help="PDDL glob, recursive (default: *.pddl)",
    )
    parser.add_argument(
        "--clean-dest",
        action="store_true",
        help="Delete the destination directory before conversion",
    )

    args = parser.parse_args()

    if not args.source.is_dir():
        raise SystemExit(f"Source directory does not exist: {args.source}")

    files, ignored_pddl_files = discover_files(args.source, args.pattern)

    if not files:
        raise SystemExit(
            f"No *-domain.pddl / *-problem.pddl files found below {args.source}"
        )

    all_domains = [f for f in files if f.kind == "domain"]
    all_problems = [f for f in files if f.kind == "problem"]

    if not all_domains:
        raise SystemExit("No domain files found")
    if not all_problems:
        raise SystemExit("No problem files found")

    # Convert ONLY the granular encoding. Other Plotting encodings can live
    # in the same source directory and must not be copied to the output.
    granular_domains = []
    skipped_domains = []

    for d in all_domains:
        dtext = d.path.read_text(encoding="utf-8")
        if is_granular_domain_text(dtext):
            granular_domains.append(d)
        else:
            skipped_domains.append(d)

    if not granular_domains:
        raise SystemExit("No granular domains found")

    domains_by_key: dict[str, list[InputFile]] = {}
    for d in granular_domains:
        domains_by_key.setdefault(d.key, []).append(d)

    pairs: list[tuple[InputFile, InputFile]] = []
    skipped_problems = []

    for problem in all_problems:
        candidates = domains_by_key.get(problem.key, [])
        if len(candidates) == 1:
            pairs.append((candidates[0], problem))
        elif len(candidates) > 1:
            raise SystemExit(
                f"Multiple granular domains match {problem.path.name}: "
                + ", ".join(x.path.name for x in candidates)
            )
        else:
            skipped_problems.append(problem)

    if not pairs:
        raise SystemExit("No granular domain/problem pairs found")

    # Prevent stale files from previous runs from remaining in the generated
    # directory. A non-empty destination requires an explicit clean rebuild.
    if args.dest.exists():
        existing = [p for p in args.dest.rglob("*") if p.is_file()]
        if args.clean_dest:
            import shutil
            shutil.rmtree(args.dest)
        elif existing:
            raise SystemExit(
                f"Destination {args.dest} is not empty. "
                "Run with --clean-dest to avoid stale files."
            )

    args.dest.mkdir(parents=True, exist_ok=True)

    print(
        f"Granular domains selected: {len(granular_domains)}; "
        f"non-granular domains skipped: {len(skipped_domains)}"
    )
    print(
        f"Granular problems selected: {len(pairs)}; "
        f"non-granular/unpaired problems skipped: {len(skipped_problems)}"
    )
    print(
        f"Other .pddl files ignored by filename: {len(ignored_pddl_files)}"
    )
    print()

    # A domain can theoretically be referenced by multiple problems. Convert
    # it once and cache the result.
    domain_cache: dict[Path, DomainConversion] = {}

    converted_domains: set[Path] = set()
    converted_problems = 0
    removed_next_total = 0

    for domain_file, problem_file in pairs:
        if domain_file.path not in domain_cache:
            domain_text = domain_file.path.read_text(encoding="utf-8")

            try:
                domain_conv = convert_domain(domain_text)
            except Exception as exc:
                raise SystemExit(
                    f"ERROR converting domain {domain_file.path}: {exc}"
                ) from exc

            domain_cache[domain_file.path] = domain_conv

            dst_domain = output_path(
                args.source,
                args.dest,
                domain_file.path,
            )
            dst_domain.parent.mkdir(parents=True, exist_ok=True)
            dst_domain.write_text(domain_conv.text, encoding="utf-8")
            converted_domains.add(domain_file.path)

            print(f"[DOMAIN ] {domain_file.path.name}")
            print(
                "          hard-coded location constants preserved: "
                + str(len(domain_conv.hardcoded_locations))
            )

        domain_conv = domain_cache[domain_file.path]

        problem_text = problem_file.path.read_text(encoding="utf-8")

        try:
            problem_conv = convert_problem(
                problem_text,
                domain_conv,
            )
        except Exception as exc:
            raise SystemExit(
                f"ERROR converting problem {problem_file.path}: {exc}"
            ) from exc

        dst_problem = output_path(
            args.source,
            args.dest,
            problem_file.path,
        )
        dst_problem.parent.mkdir(parents=True, exist_ok=True)
        dst_problem.write_text(problem_conv.text, encoding="utf-8")

        converted_problems += 1
        removed_next_total += len(
            problem_conv.removed_invalid_next_facts
        )

        print(f"[PROBLEM] {problem_file.path.name}")
        if problem_conv.removed_domain_constant_objects:
            print(
                "          moved from problem objects to domain constants: "
                + ", ".join(
                    problem_conv.removed_domain_constant_objects
                )
            )
        if problem_conv.removed_invalid_next_facts:
            print(
                "          removed invalid top 'up' facts: "
                + str(
                    len(problem_conv.removed_invalid_next_facts)
                )
            )

    print()
    print("Conversion complete.")
    print(f"Domains converted:  {len(converted_domains)}")
    print(f"Problems converted: {converted_problems}")
    print(f"Domains skipped:    {len(skipped_domains)}")
    print(f"Problems skipped:   {len(skipped_problems)}")
    print(f"Other .pddl ignored:{len(ignored_pddl_files):>5}")
    print(f"Destination:        {args.dest}")
    print(f"Invalid top-up facts removed: {removed_next_total}")


if __name__ == "__main__":
    main()
