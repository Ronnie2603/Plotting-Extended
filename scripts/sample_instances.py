#!/usr/bin/env python3

from pathlib import Path
from random import Random

SEED = 42
REPLICAS_PER_CONFIGURATION = 3
SAMPLES_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SAMPLES_DIR.parent
PDDL_DIR = PROJECT_ROOT / "benchmarks/pddl"
DIRECT_SOURCE = PDDL_DIR / "instances-direct-numeric"
GRANULAR_SOURCE = PDDL_DIR / "instances-granular-enhsp-compatible"
SAMPLE_MANIFEST = PROJECT_ROOT / "benchmarks/manifests/sample-instances.txt"

configurations = sorted(path.stem.split("_", 1)[1] for path in DIRECT_SOURCE.glob("plt0_*.pddl"))
if len(configurations) != 87:
    raise RuntimeError("Expected 87 configurations")

random = Random(SEED)
sample_instances = []

for configuration in configurations:
    for replica in range(6):
        stem = f"plt{replica}_{configuration}"
        if not (DIRECT_SOURCE / f"{stem}.pddl").is_file() \
                or not (GRANULAR_SOURCE / f"{stem}-domain.pddl").is_file() \
                or not (GRANULAR_SOURCE / f"{stem}-problem.pddl").is_file():
            raise FileNotFoundError(stem)

    for replica in random.sample(range(6), REPLICAS_PER_CONFIGURATION):
        stem = f"plt{replica}_{configuration}"
        sample_instances.append(stem)

SAMPLE_MANIFEST.write_text("\n".join(sorted(sample_instances)) + "\n")
