SIM ?= questa
TEST ?= random_test
SEEDS ?= 20
SEED_START ?= 1
TIMEOUT ?=

RUN_ARGS = --sim $(SIM) --test $(TEST) --seeds $(SEEDS) --seed-start $(SEED_START)
ifneq ($(strip $(TIMEOUT)),)
RUN_ARGS += --timeout $(TIMEOUT)
endif

.PHONY: regression random corner base verify clean preflight-note

regression:
	python3 scripts/run_regression.py $(RUN_ARGS)

random:
	python3 scripts/run_regression.py --sim $(SIM) --test random_test --seeds $(SEEDS) --seed-start $(SEED_START)

corner:
	python3 scripts/run_regression.py --sim $(SIM) --test corner_case_test --seeds $(SEEDS) --seed-start $(SEED_START)

base:
	python3 scripts/run_regression.py --sim $(SIM) --test base_test --seeds $(SEEDS) --seed-start $(SEED_START)

verify:
	python3 scripts/verify_real_results.py

clean:
	rm -rf build work transcript vsim.wlf simv simv.daidir csrc *.log *.key \
	       reports/logs reports/ucdb reports/vcs_cov.vdb reports/vcs_urg_report \
	       reports/xcelium_cov reports/questa_coverage_html \
	       reports/regression_results.json reports/regression_snapshot.html reports/preflight_status.json
