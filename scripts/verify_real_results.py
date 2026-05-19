#!/usr/bin/env python3
"""
Audit reports/regression_results.json for credibility before publishing.

This script does not prove that a commercial simulator license was valid, but it
checks the evidence chain that matters for a portfolio repo:
  - regression_results.json exists
  - at least one seed result exists
  - every seed has an actual log file
  - each log begins with the command line captured by run_regression.py
  - no preflight-only/missing-tool file is being used as regression evidence
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESULT_JSON = ROOT / "reports" / "regression_results.json"


def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def main() -> int:
    if not RESULT_JSON.exists():
        return fail("reports/regression_results.json does not exist. Run a real simulator regression first.")

    try:
        data = json.loads(RESULT_JSON.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return fail(f"regression_results.json is not valid JSON: {exc}")

    if data.get("artifact_type") != "real_simulator_regression_results":
        return fail("JSON artifact_type is not real_simulator_regression_results.")

    results = data.get("results") or []
    if not results:
        return fail("No seed results are present. This is not usable regression evidence.")

    compile_steps = data.get("compile", [])
    for step in compile_steps:
        log_rel = step.get("log_path")
        if not log_rel:
            return fail("A compile step is missing log_path.")
        log_path = ROOT / log_rel
        if not log_path.exists():
            return fail(f"Compile log is missing: {log_rel}")
        if not log_path.read_text(encoding="utf-8", errors="replace").startswith("$ "):
            return fail(f"Compile log does not start with captured command: {log_rel}")

    valid_statuses = {"PASS", "FAIL"}
    for item in results:
        seed = item.get("seed")
        if item.get("actual_command_executed") is not True:
            return fail(f"Seed {seed} is not marked as actual_command_executed=true.")
        if item.get("status") not in valid_statuses:
            return fail(f"Seed {seed} has invalid status: {item.get('status')}")
        if not isinstance(item.get("returncode"), int):
            return fail(f"Seed {seed} returncode is missing or non-integer.")
        if not isinstance(item.get("duration_s"), (int, float)) or item.get("duration_s") < 0:
            return fail(f"Seed {seed} duration_s is missing or invalid.")
        log_rel = item.get("log_path")
        if not log_rel:
            return fail(f"Seed {seed} is missing log_path.")
        log_path = ROOT / log_rel
        if not log_path.exists():
            return fail(f"Seed {seed} log file is missing: {log_rel}")
        log_text = log_path.read_text(encoding="utf-8", errors="replace")
        if not log_text.startswith("$ "):
            return fail(f"Seed {seed} log does not start with captured command: {log_rel}")
        command = item.get("simulator_command")
        if not isinstance(command, list) or not command:
            return fail(f"Seed {seed} simulator_command is missing.")

    summary = data.get("summary") or {}
    print("PASS: regression evidence chain looks valid.")
    print(f"Simulator: {data.get('simulator')} | Test: {data.get('test')} | Seeds: {len(results)}")
    print(f"Passed: {summary.get('passed')} | Failed: {summary.get('failed')} | Pass rate: {summary.get('pass_rate_pct')}%")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
