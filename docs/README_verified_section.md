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
