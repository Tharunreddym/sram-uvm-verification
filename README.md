# Project 3: SRAM Subsystem Verification

This repository implements a UVM-based SRAM subsystem verification environment with RTL, interface clocking blocks, a constrained-random transaction layer, driver, monitor, scoreboard, functional coverage, SVA assertions, directed/random/corner sequences, and a real regression script.

## Design behavior

The DUT is a synchronous SRAM controller with:

- configurable data width, address width, and depth
- chip enable
- independent write enable and read enable
- one write address/data path
- one read address/data path
- registered read data
- `rvalid` asserted one cycle after a sampled read request
- legal simultaneous read/write only when read and write addresses are different

## Main tree

```text
sram_verification/
├── rtl/
│   └── sram_ctrl.sv
├── tb/
│   ├── interfaces/
│   │   └── sram_if.sv
│   ├── uvm/
│   │   ├── sram_defines.svh
│   │   ├── sram_pkg.sv
│   │   ├── sram_seq_item.sv
│   │   ├── sram_driver.sv
│   │   ├── sram_monitor.sv
│   │   ├── sram_scoreboard.sv
│   │   ├── sram_coverage.sv
│   │   ├── sram_agent.sv
│   │   ├── sram_env.sv
│   │   └── sram_sequences.sv
│   ├── tests/
│   │   ├── base_test.sv
│   │   ├── random_test.sv
│   │   └── corner_case_test.sv
│   └── top.sv
├── assertions/
│   └── sram_assertions.sv
├── scripts/
│   ├── run_regression.py
│   └── verify_real_results.py
├── filelists/
│   └── sim.f
└── reports/
    └── coverage_dashboard.html
```

## Run real regressions

The regression script intentionally does not fabricate results. It requires a real simulator installation. It now deletes stale dashboard inputs at the start of a run and writes `reports/regression_results.json` only after at least one real seed simulation command has executed.

If tools are missing or compile/elaboration fails before any seed simulation, the script writes `reports/preflight_status.json` instead of `reports/regression_results.json`.

### Questa

```bash
make regression SIM=questa TEST=random_test SEEDS=20
```

Equivalent direct command:

```bash
python3 scripts/run_regression.py --sim questa --test random_test --seeds 20
```

### VCS

```bash
make regression SIM=vcs TEST=random_test SEEDS=20
```

### Xcelium

```bash
make regression SIM=xcelium TEST=random_test SEEDS=20
```

## Proof workflow

Use this when generating credible portfolio evidence:

```bash
make clean
make regression SIM=questa TEST=random_test SEEDS=20
make verify
```

`make verify` checks that `reports/regression_results.json` exists, contains seed results, and points to real log files captured by the regression script.

More details are in `docs/REAL_SIMULATION_RUNBOOK.md`.

## Outputs

After a real seed simulation run, the script writes:

- `reports/logs/*.log` — compile and per-seed simulator logs
- `reports/regression_results.json` — machine-readable pass/fail/coverage results, created only after real seed execution
- `reports/regression_snapshot.html` — static HTML snapshot
- `reports/coverage_dashboard.html` — dynamic dashboard that loads the JSON results
- simulator coverage databases/reports where supported

## Tests

- `base_test` writes every address and reads every address back.
- `random_test` combines full-memory initialization, constrained-random traffic, simultaneous read/write traffic, and full-memory readback.
- `corner_case_test` stresses boundary addresses, back-to-back same-address operations, write-then-immediate-read behavior, and legal simultaneous read/write operations.

## Assertions

`sram_assertions.sv` contains 25 assertions covering:

- write enable and read enable timing under chip enable
- no same-address read/write conflict
- read latency and `rvalid` behavior
- reset behavior
- X/Z detection
- address range checks
- output stability when no read is requested
- simultaneous read/write signal legality



# Verified Simulation Evidence

The SRAM subsystem was compiled and simulated on **QuestaSim using EDA Playground**.

This evidence is based on real simulator logs captured from EDA Playground. It is **not** a UCDB/VDB merged coverage database report.

## Regression Summary

| Category | Result |
|---|---:|
| Total simulations | 22 |
| Directed base tests | 1 |
| Corner-case tests | 1 |
| Random regression seeds | 20 |
| Passing simulations | 22 |
| UVM warnings | 0 |
| UVM errors | 0 |
| UVM fatals | 0 |
| Protocol errors | 0 |
| Scoreboard data mismatches | 0 |
| Total random writes | 17,888 |
| Total random reads | 12,838 |
| Total random matched reads | 12,838 |
| Highest observed functional coverage | 84.30% |
| Average random functional coverage | 79.11% |

## Detailed Results

| Test | Seed | Result | Writes | Reads | Matched Reads | Functional Coverage |
|---|---:|---|---:|---:|---:|---:|
| `base_test` | 1 | PASS | 256 | 256 | 256 | 40.28% |
| `corner_case_test` | 1 | PASS | 355 | 611 | 611 | 81.60% |
| `random_test` | 1 | PASS | 861 | 589 | 589 | 83.82% |
| `random_test` | 2 | PASS | 904 | 663 | 663 | 71.60% |
| `random_test` | 3 | PASS | 848 | 602 | 602 | 83.87% |
| `random_test` | 4 | PASS | 918 | 655 | 655 | 84.14% |
| `random_test` | 5 | PASS | 894 | 629 | 629 | 71.55% |
| `random_test` | 6 | PASS | 851 | 580 | 580 | 71.41% |
| `random_test` | 7 | PASS | 877 | 623 | 623 | 84.03% |
| `random_test` | 8 | PASS | 896 | 644 | 644 | 71.70% |
| `random_test` | 9 | PASS | 897 | 656 | 656 | 84.17% |
| `random_test` | 10 | PASS | 873 | 603 | 603 | 84.03% |
| `random_test` | 11 | PASS | 837 | 586 | 586 | 71.40% |
| `random_test` | 12 | PASS | 897 | 633 | 633 | 84.05% |
| `random_test` | 13 | PASS | 980 | 723 | 723 | 72.08% |
| `random_test` | 14 | PASS | 959 | 700 | 700 | 71.92% |
| `random_test` | 15 | PASS | 921 | 704 | 704 | 84.17% |
| `random_test` | 16 | PASS | 827 | 601 | 601 | 84.09% |
| `random_test` | 17 | PASS | 873 | 635 | 635 | 71.50% |
| `random_test` | 18 | PASS | 953 | 698 | 698 | 84.26% |
| `random_test` | 19 | PASS | 938 | 696 | 696 | 84.30% |
| `random_test` | 20 | PASS | 884 | 618 | 618 | 84.18% |

## Verification Notes

- The UVM scoreboard maintained a shadow memory model.
- Every checked read compared RTL read data against expected shadow memory contents.
- All 20 constrained-random seeds passed.
- No UVM warnings, UVM errors, UVM fatals, protocol errors, or scoreboard data mismatches were observed in the collected logs.
- UCDB/VDB merge is intentionally not claimed here.


## Important honesty note

This repository includes real EDA Playground QuestaSim simulation evidence generated from manually executed runs.

The checked-in EDA evidence includes:
- 1 passing `base_test`
- 1 passing `corner_case_test`
- 20 passing `random_test` seeds
- 0 UVM warnings
- 0 UVM errors
- 0 UVM fatals
- 0 protocol errors
- 0 scoreboard data mismatches

