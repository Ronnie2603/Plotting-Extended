# Plotting Planning Benchmarks

Extended workspace for running and comparing experiments on the **Plotting** domain using:

- ENHSP with the direct, direct-opt, and granular PDDL models;
- Savile Row + Chuffed with Essence Prime models;
- VAL for PDDL plan validation;
- Python scripts to generate the shared sample and compare results.

## Running ENHSP

### Running experiments on multiple instances

_Syntax_:

```bash
./scripts/enhsp/run-all.sh [MODEL] [INSTANCES] [options]
```

_Available models_:

| Model | Domain | Instance directory |
| --- | --- | --- |
| `direct` | `benchmarks/pddl/domains/numeric.pddl` | `instances-direct-numeric` |
| `direct-opt` | `benchmarks/pddl/domains/numeric-opt.pddl` | `instances-direct-numeric-opt` |
| `granular` | one domain per instance | `instances-granular-enhsp-compatible` |

_Instance selections_:

- `samples`: uses the 261 instances listed in `benchmarks/manifests/sample-instances.txt`;
- `all`: uses all compatible instances in the model's directory.

When called without arguments, the default is `direct samples`.

_Options_:

- `--build`: builds the `pddl-plotting` image before running;

_Examples_:

```bash
./scripts/enhsp/run-all.sh direct samples
./scripts/enhsp/run-all.sh direct-opt all
./scripts/enhsp/run-all.sh granular samples
./scripts/enhsp/run-all.sh granular all --build
```

### Running a single instance

The single-instance runner uses `direct` as its default model:

```bash
./scripts/enhsp/run-one.sh \
  benchmarks/pddl/instances-direct-numeric/plt0_2_4_2_1.pddl
```

Use `PDDL_MODEL` to select a different model.

_Examples_:

```bash
PDDL_MODEL=direct-opt \
  ./scripts/enhsp/run-one.sh \
  benchmarks/pddl/instances-direct-numeric-opt/plt0_2_4_2_1.pddl

PDDL_MODEL=granular \
  ./scripts/enhsp/run-one.sh \
  benchmarks/pddl/instances-granular-enhsp-compatible/plt0_2_4_2_1-problem.pddl
```

`run-one.sh` also accepts `--build`.

### ENHSP configuration

The main options can be set through environment variables:

| Variable | Default | Description |
| --- | --- | --- |
| `TIME_LIMIT` | `900` | timeout per instance, in seconds |
| `JAVA_OPTS` | `-Xmx24G` | JVM options |
| `VALIDATE_PLANS` | `1` | validates each plan with VAL; use `0` to skip validation |
| `SKIP_EXISTING_RESULTS` | `1` | reuses existing logs; use `0` to rerun |
| `OUTPUT_DIR` | `results/pddl/enhsp/<encoding>/<configuration>/` | output path for results |
| `PLANNER` | depends on the model | ENHSP configuration |
| `HEURISTIC` | derived from `PLANNER` | heuristic |
| `SEARCH` | `WAStar` or `gbfs` | search strategy |
| `WH` | `1` | heuristic weight |
| `TIES` | depends on the search strategy | tie-breaking criterion |

_Examples_:

```bash
TIME_LIMIT=300 ./scripts/enhsp/run-all.sh direct samples

JAVA_OPTS=-Xmx8G VALIDATE_PLANS=0 \
  ./scripts/enhsp/run-all.sh granular samples

SKIP_EXISTING_RESULTS=0 OUTPUT_DIR=results/pddl/enhsp/direct/test \
  ./scripts/enhsp/run-all.sh direct samples
```

### ENHSP results

By default, results are saved under:

```text
results/pddl/enhsp/<encoding>/<configuration>/
├── stats.csv
├── plans/
├── logs/
└── validation/
```

For each instance, `stats.csv` contains the status, validity, runtime, number of actions, expanded nodes, exit code, and artifact paths.

The main statuses are `ok`, `timeout`, `unsolved`, `invalid_plan`, `planner_not_found`, and `planner_error`. With `VALIDATE_PLANS=0`, a successful solution is recorded with `valid=skipped`.

## Essence Prime and Chuffed

The script runs every name in the shared manifest and, for each name, all matching `.param` files:

```bash
./scripts/eprime/solve-261-instances.sh [MODEL] [CONSTRAINTS] [options]
```

_Models_:

- `s`;
- `sa` (default).

_Constraint configurations_:

- `deadend`;
- `empty`;
- `monochrome`;
- `nosymm` (default);
- `symm`.

_Options_:

- `--build`: rebuilds the `chuffed-plotting` image;
- `--fail-fast`: stops the experiment at the first failed problem;
- `--model-family NAME`: selects a directory under `benchmarks/eprime/models`;
- `--model PATH`: uses an explicit `.eprime` model, relative to `benchmarks/eprime`;
- `-h`, `--help`: displays the full help message.

The same settings can be configured through `EPRIME_MODEL`, `EPRIME_CONSTRAINTS`, `EPRIME_MODEL_FAMILY`, `CHUFFED_MODEL`, and `OUTPUT_DIR`.

By default, results are saved under:

```text
results/eprime/chuffed/<family>/<configuration>/<problem>/
```

Each directory contains the solver's standard output and error streams, exit code, timing data, the information file produced by Savile Row, and a copy of the parameters used.

_Examples_:

```bash
./scripts/eprime/solve-261-instances.sh sa nosymm
./scripts/eprime/solve-261-instances.sh s symm
./scripts/eprime/solve-261-instances.sh \
  s deadend --model-family no-searchorder
./scripts/eprime/solve-261-instances.sh \
  --model models/sat-finetune/plotting_sa_deadend_v5.eprime
```

## Shared sample of 261 instances

The file `benchmarks/manifests/sample-instances.txt` contains three replicates, selected deterministically with seed `42`, for each of the 87 available configurations.

To regenerate it:

```bash
python3 scripts/sample_instances.py
```

## Comparing results

Install the Python dependencies to generate tables and plots on the host machine:

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
```

To generate all default comparisons:

```bash
python3 scripts/global_comparison.py
```

The script accepts no options: it automatically discovers all `stats.csv` files under `results/pddl/` and `results/eprime/` and generates the `greedy`, `enhsp`, `eprime`, and `all-runs` comparisons when available.
