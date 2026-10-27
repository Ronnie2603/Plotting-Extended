# Plotting Planning Benchmarks

Extended workspace per eseguire e confrontare esperimenti sul dominio **Plotting** con:

- ENHSP sui modelli PDDL direct, direct-opt e granular;
- Savile Row + Chuffed sui modelli Essence Prime;
- VAL per la validazione dei piani PDDL;
- script Python per generare il campione comune e confrontare i risultati.

## Avvio ENHSP

### Eseguire esperimenti su più istanze

_Sintassi_:

```bash
./scripts/enhsp/run-all.sh [MODELLO] [ISTANZE] [opzioni]
```

_Modelli disponibili_:

| Modello | Dominio | Directory delle istanze |
| --- | --- | --- |
| `direct` | `benchmarks/pddl/domains/numeric.pddl` | `instances-direct-numeric` |
| `direct-opt` | `benchmarks/pddl/domains/numeric-opt.pddl` | `instances-direct-numeric-opt` |
| `granular` | un dominio per istanza | `instances-granular-enhsp-compatible` |

_Selezioni delle istanze_:

- `samples`: usa i 261 samples scelti all'interno `benchmarks/manifests/sample-instances.txt`;
- `all`: usa tutte le istanze compatibili presenti nella directory del modello.

Se utilizzato senza argomenti usa `direct samples` come default.

_Opzioni_:

- `--build`: costruisce l'immagine `pddl-plotting` prima dell'esecuzione;

_Esempi_:

```bash
./scripts/enhsp/run-all.sh direct samples
./scripts/enhsp/run-all.sh direct-opt all
./scripts/enhsp/run-all.sh granular samples
./scripts/enhsp/run-all.sh granular all --build
```

### Eseguire una singola istanza

Il runner singolo usa `direct` come modello predefinito:

```bash
./scripts/enhsp/run-one.sh \
  benchmarks/pddl/instances-direct-numeric/plt0_2_4_2_1.pddl
```

Per scegliere un altro modello usa `PDDL_MODEL`.

_Esempi_:

```bash
PDDL_MODEL=direct-opt \
  ./scripts/enhsp/run-one.sh \
  benchmarks/pddl/instances-direct-numeric-opt/plt0_2_4_2_1.pddl

PDDL_MODEL=granular \
  ./scripts/enhsp/run-one.sh \
  benchmarks/pddl/instances-granular-enhsp-compatible/plt0_2_4_2_1-problem.pddl
```

Anche `run-one.sh` accetta `--build`.

### Configurazione ENHSP

Le opzioni principali si possono impostare tramite variabili d'ambiente:

| Variabile | Default | Descrizione |
| --- | --- | --- |
| `TIME_LIMIT` | `900` | timeout per ogni istanza, in secondi |
| `JAVA_OPTS` | `-Xmx24G` | opzioni della JVM |
| `VALIDATE_PLANS` | `1` | valida ogni piano con VAL; usa `0` per saltare |
| `SKIP_EXISTING_RESULTS` | `1` | riusa i log esistenti; usa `0` per rieseguire |
| `OUTPUT_DIR` | `results/pddl/enhsp/<encoding>/<configurazione>/` | percorso di output dei risultati |
| `PLANNER` | dipende dal modello | configurazione ENHSP |
| `HEURISTIC` | derivata da `PLANNER` | euristica |
| `SEARCH` | `WAStar` o `gbfs` | strategia di ricerca |
| `WH` | `1` | peso dell'euristica |
| `TIES` | dipende dalla ricerca | criterio di tie-breaking |

_Esempi_:

```bash
TIME_LIMIT=300 ./scripts/enhsp/run-all.sh direct samples

JAVA_OPTS=-Xmx8G VALIDATE_PLANS=0 \
  ./scripts/enhsp/run-all.sh granular samples

SKIP_EXISTING_RESULTS=0 OUTPUT_DIR=results/pddl/enhsp/direct/test \
  ./scripts/enhsp/run-all.sh direct samples
```

### Risultati ENHSP

I risultati predefiniti vengono salvati sotto:

```text
results/pddl/enhsp/<encoding>/<configurazione>/
├── stats.csv
├── plans/
├── logs/
└── validation/
```

`stats.csv` contiene, per ogni istanza, stato, validità, runtime, numero di azioni, nodi espansi, exit code e percorsi degli artefatti.

I principali stati sono `ok`, `timeout`, `unsolved`, `invalid_plan`, `planner_not_found` e `planner_error`. Con `VALIDATE_PLANS=0`, una soluzione riuscita viene registrata con `valid=skipped`.

## Essence Prime e Chuffed

Lo script esegue tutti i nomi presenti nel manifest comune e, per ogni nome, tutti i file `.param` corrispondenti:

```bash
./scripts/eprime/solve-261-instances.sh [MODELLO] [VINCOLI] [opzioni]
```

_Modelli_:

- `s`;
- `sa` (default).

_Configurazioni dei vincoli_:

- `deadend`;
- `empty`;
- `monochrome`;
- `nosymm` (default);
- `symm`.

_Opzioni_:

- `--build`: ricostruisce l'immagine `chuffed-plotting`;
- `--fail-fast`: interrompe l'esperimento al primo problema fallito;
- `--model-family NAME`: seleziona una directory sotto `benchmarks/eprime/models`;
- `--model PATH`: usa un modello `.eprime` esplicito, relativo a `benchmarks/eprime`;
- `-h`, `--help`: mostra l'help completo.

Le stesse scelte si possono impostare con `EPRIME_MODEL`, `EPRIME_CONSTRAINTS`, `EPRIME_MODEL_FAMILY`, `CHUFFED_MODEL` e `OUTPUT_DIR`.

I risultati predefiniti vengono salvati sotto:

```text
results/eprime/chuffed/<famiglia>/<configurazione>/<problema>/
```

Ogni directory contiene gli stream standard del solver, l'exit code, i dati di timing, il file informativo prodotto da Savile Row e una copia dei parametri usati.

_Esempi_:

```bash
./scripts/eprime/solve-261-instances.sh sa nosymm
./scripts/eprime/solve-261-instances.sh s symm
./scripts/eprime/solve-261-instances.sh \
  s deadend --model-family no-searchorder
./scripts/eprime/solve-261-instances.sh \
  --model models/sat-finetune/plotting_sa_deadend_v5.eprime
```

## Campione comune di 261 istanze

Il file `benchmarks/manifests/sample-instances.txt` contiene tre repliche, scelte deterministicamente con seed `42`, per ognuna delle 87 configurazioni disponibili.

Per rigenerarlo:

```bash
python3 scripts/sample_instances.py
```

## Confrontare i risultati

Installa le dipendenze Python se vuoi generare tabelle e grafici dalla macchina host:

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
```

Per generare tutti i confronti predefiniti:

```bash
python3 scripts/global_comparison.py
```

Lo script non accetta opzioni: individua automaticamente tutti gli `stats.csv` sotto `results/pddl/` e `results/eprime/` e genera le comparazioni `greedy`, `enhsp`, `eprime` e `all-runs`, quando disponibili.

La run storica su 522 istanze in `results/pddl/enhsp/direct/greedy-colour-opt/` è esclusa da tutte le comparazioni; i suoi dati originali restano conservati.

I risultati direct sono salvati direttamente sotto `results/pddl/enhsp/direct/<configurazione>/`, inclusa la run WA* opt-blind in `wastar-optblind/`.

Gli output vengono scritti in `results/comparisons/`.

Il grafico `results/comparisons/plots/all-runs/all-tested-solved-over-time.png` (disponibile anche in SVG) include tutte le configurazioni considerate nel confronto, sia PDDL sia Essence Prime con Chuffed o SAT. Usa tutti i risultati completati disponibili per ciascuna configurazione; le esecuzioni parziali possono quindi avere campioni diversi. La tabella corrispondente è `tables/all-runs/all-tested-summary.csv` e riporta il numero di istanze per configurazione. Gli altri grafici di confronto usano le istanze completate comuni alle configurazioni della suite.

Per Essence Prime, i tentativi con `noSteps` crescente vengono aggregati per istanza: il runtime è il tempo cumulativo fino alla soluzione o alla conclusione della ricerca, comprensivo dei tentativi precedenti. Una soluzione è riconosciuta dallo stato `solved` registrato dal runner sulla base di `SolverSatisfiable`; per i piani PDDL continua a essere richiesta la validazione VAL. La soglia di confronto è 900 secondi.

## Struttura del repository

```text
benchmarks/
├── eprime/
│   ├── instances/
│   └── models/
├── manifests/
└── pddl/
    ├── domains/
    ├── instances-direct-numeric/
    ├── instances-direct-numeric-opt/
    └── instances-granular-enhsp-compatible/
docker/
enhsp-heuristics/
results/
scripts/
├── enhsp/
├── eprime/
└── utils/
```
