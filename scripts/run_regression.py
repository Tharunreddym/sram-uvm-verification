#!/usr/bin/env python3
"""
Real SRAM UVM regression runner.

This script intentionally does not fabricate pass/fail, coverage, UCDB/VDB,
or simulator logs. The dashboard input file, reports/regression_results.json,
is written only after at least one real seed simulation command has executed.

If required tools are missing, or compile/elaboration fails before any seed is
run, the script writes reports/preflight_status.json instead. That prevents old
or fake dashboard data from being mistaken for real regression evidence.

Supported commercial simulators:
  --sim questa   : Siemens Questa/ModelSim with UVM + coverage
  --sim vcs      : Synopsys VCS with UVM + coverage
  --sim xcelium  : Cadence Xcelium with UVM + coverage
"""

from __future__ import annotations

import argparse
import datetime as dt
import html
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Iterable, Optional

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "reports"
LOGS = REPORTS / "logs"
BUILDS = ROOT / "build"
FILELIST = ROOT / "filelists" / "sim.f"
RESULT_JSON = REPORTS / "regression_results.json"
PREFLIGHT_JSON = REPORTS / "preflight_status.json"
SNAPSHOT_HTML = REPORTS / "regression_snapshot.html"


def rel(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT)).replace(os.sep, "/")
    except ValueError:
        return str(path).replace(os.sep, "/")


def now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")


def require_tools(tools: Iterable[str]) -> tuple[list[str], dict[str, str]]:
    missing: list[str] = []
    resolved: dict[str, str] = {}
    for tool in tools:
        path = shutil.which(tool)
        if path is None:
            missing.append(tool)
        else:
            resolved[tool] = path
    return missing, resolved


def remove_stale_dashboard_inputs() -> None:
    """Remove stale result files before a new run attempt.

    This is important for portfolio credibility: if preflight/compile fails, the
    dashboard should not keep displaying results from an older run.
    """
    for path in [RESULT_JSON, SNAPSHOT_HTML]:
        if path.exists():
            path.unlink()


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def write_preflight(payload: dict) -> None:
    payload["artifact_type"] = "preflight_status_not_regression_results"
    payload["generated_at"] = now_iso()
    write_json(PREFLIGHT_JSON, payload)


def run_cmd(cmd: list[str], log_path: Path, cwd: Path = ROOT, timeout_s: Optional[int] = None) -> tuple[int, float, str]:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    start = time.monotonic()
    header = "$ " + " ".join(cmd) + "\n\n"
    with log_path.open("w", encoding="utf-8", errors="replace") as log:
        log.write(header)
        log.flush()
        try:
            proc = subprocess.Popen(
                cmd,
                cwd=str(cwd),
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                errors="replace",
            )
            assert proc.stdout is not None
            chunks: list[str] = []
            for line in proc.stdout:
                log.write(line)
                chunks.append(line)
            rc = proc.wait(timeout=timeout_s)
            output = "".join(chunks)
        except subprocess.TimeoutExpired:
            proc.kill()
            rc = 124
            output = "TIMEOUT: command exceeded timeout\n"
            log.write(output)
        except FileNotFoundError as exc:
            rc = 127
            output = f"ERROR: {exc}\n"
            log.write(output)
    duration = time.monotonic() - start
    return rc, duration, header + output


def parse_uvm_counts(text: str) -> tuple[int, int]:
    error_count = 0
    fatal_count = 0

    for pat, which in [
        (r"UVM_ERROR\s*:\s*(\d+)", "error"),
        (r"UVM_FATAL\s*:\s*(\d+)", "fatal"),
    ]:
        matches = re.findall(pat, text)
        if matches:
            value = int(matches[-1])
            if which == "error":
                error_count = value
            else:
                fatal_count = value

    if re.search(r"UVM_ERROR\s+@", text):
        error_count = max(error_count, 1)
    if re.search(r"UVM_FATAL\s+@", text):
        fatal_count = max(fatal_count, 1)

    return error_count, fatal_count


def parse_coverage_percent(text: str) -> Optional[float]:
    patterns = [
        r"functional_coverage\s*=\s*([0-9]+(?:\.[0-9]+)?)\s*%",
        r"Total\s+Coverage\s*[:=]\s*([0-9]+(?:\.[0-9]+)?)\s*%",
        r"TOTAL\s+COVERAGE\s*[:=]?\s*([0-9]+(?:\.[0-9]+)?)\s*%",
        r"Coverage\s+summary.*?([0-9]+(?:\.[0-9]+)?)\s*%",
    ]
    found: list[float] = []
    for pat in patterns:
        for match in re.findall(pat, text, flags=re.IGNORECASE | re.DOTALL):
            try:
                found.append(float(match))
            except ValueError:
                pass
    return found[-1] if found else None


def status_from_log(returncode: int, text: str) -> tuple[str, int, int]:
    uvm_errors, uvm_fatals = parse_uvm_counts(text)
    assertion_error = bool(re.search(r"\$error|Assertion.*failed|assertion.*failed", text, flags=re.IGNORECASE))
    sim_fatal = bool(re.search(r"\*\*\s+Fatal|Fatal:\s|xmsim:\s*\*F|Error-\[", text, flags=re.IGNORECASE))
    if returncode == 0 and uvm_errors == 0 and uvm_fatals == 0 and not assertion_error and not sim_fatal:
        return "PASS", uvm_errors, uvm_fatals
    return "FAIL", uvm_errors, uvm_fatals


def compile_questa(args: argparse.Namespace) -> tuple[bool, list[dict]]:
    cmds = [
        ["vlib", "work"],
        ["vlog", "-sv", "-timescale", "1ns/1ps", "-cover", "bcesft", "-f", rel(FILELIST)],
    ]
    compile_steps: list[dict] = []
    ok = True
    for idx, cmd in enumerate(cmds, start=1):
        log = LOGS / f"questa_compile_step{idx}.log"
        rc, duration, _ = run_cmd(cmd, log, timeout_s=args.timeout)
        step = {
            "command": cmd,
            "returncode": rc,
            "duration_s": round(duration, 3),
            "log_path": rel(log),
            "actual_command_executed": True,
        }
        compile_steps.append(step)
        if rc != 0:
            ok = False
            break
    return ok, compile_steps


def run_questa_seed(seed: int, test: str, args: argparse.Namespace) -> dict:
    ucdb_dir = REPORTS / "ucdb"
    ucdb_dir.mkdir(parents=True, exist_ok=True)
    log = LOGS / f"questa_{test}_seed_{seed}.log"
    ucdb = ucdb_dir / f"{test}_seed_{seed}.ucdb"
    cmd = [
        "vsim", "-c", "-coverage", "-sv_seed", str(seed), "work.tb_top",
        f"+UVM_TESTNAME={test}",
        "-do", f"run -all; coverage save -onexit {rel(ucdb)}; quit -f",
    ]
    rc, duration, text = run_cmd(cmd, log, timeout_s=args.timeout)
    status, uvm_errors, uvm_fatals = status_from_log(rc, text)
    cov = parse_coverage_percent(text)
    return {
        "seed": seed,
        "test": test,
        "status": status,
        "returncode": rc,
        "uvm_errors": uvm_errors,
        "uvm_fatals": uvm_fatals,
        "coverage_pct": cov,
        "duration_s": round(duration, 3),
        "log_path": rel(log),
        "coverage_db": rel(ucdb) if ucdb.exists() else None,
        "simulator_command": cmd,
        "actual_command_executed": True,
        "result_source": "parsed from actual simulator stdout/stderr log",
    }


def merge_questa(args: argparse.Namespace) -> dict:
    ucdbs = sorted((REPORTS / "ucdb").glob("*.ucdb"))
    if not ucdbs:
        return {"status": "SKIPPED", "reason": "No UCDB files found"}
    merged = REPORTS / "ucdb" / "merged.ucdb"
    merge_log = LOGS / "questa_vcover_merge.log"
    cmd = ["vcover", "merge", rel(merged)] + [rel(p) for p in ucdbs]
    rc, duration, _ = run_cmd(cmd, merge_log, timeout_s=args.timeout)
    report_info = {
        "status": "PASS" if rc == 0 else "FAIL",
        "command": cmd,
        "returncode": rc,
        "duration_s": round(duration, 3),
        "log_path": rel(merge_log),
        "merged_db": rel(merged) if merged.exists() else None,
        "actual_command_executed": True,
    }
    if rc == 0:
        html_dir = REPORTS / "questa_coverage_html"
        report_log = LOGS / "questa_vcover_html.log"
        report_cmd = ["vcover", "report", "-html", "-output", rel(html_dir), rel(merged)]
        r_rc, r_duration, _ = run_cmd(report_cmd, report_log, timeout_s=args.timeout)
        report_info["html_report"] = rel(html_dir) if html_dir.exists() else None
        report_info["html_report_returncode"] = r_rc
        report_info["html_report_duration_s"] = round(r_duration, 3)
        report_info["html_report_log_path"] = rel(report_log)
    return report_info


def compile_vcs(args: argparse.Namespace) -> tuple[bool, list[dict]]:
    build_dir = BUILDS / "vcs"
    build_dir.mkdir(parents=True, exist_ok=True)
    simv = build_dir / "simv"
    log = LOGS / "vcs_compile.log"
    cmd = [
        "vcs", "-full64", "-sverilog", "-ntb_opts", "uvm",
        "-timescale=1ns/1ps", "-cm", "line+cond+tgl+branch+fsm+assert",
        "-f", rel(FILELIST), "-o", rel(simv), "-lca",
    ]
    rc, duration, _ = run_cmd(cmd, log, timeout_s=args.timeout)
    return rc == 0, [{
        "command": cmd,
        "returncode": rc,
        "duration_s": round(duration, 3),
        "log_path": rel(log),
        "actual_command_executed": True,
    }]


def run_vcs_seed(seed: int, test: str, args: argparse.Namespace) -> dict:
    simv = BUILDS / "vcs" / "simv"
    cov_dir = REPORTS / "vcs_cov.vdb"
    log = LOGS / f"vcs_{test}_seed_{seed}.log"
    cmd = [
        str(simv), f"+ntb_random_seed={seed}", f"+UVM_TESTNAME={test}",
        "-cm", "line+cond+tgl+branch+fsm+assert",
        "-cm_name", f"{test}_seed_{seed}",
        "-cm_dir", rel(cov_dir),
    ]
    rc, duration, text = run_cmd(cmd, log, timeout_s=args.timeout)
    status, uvm_errors, uvm_fatals = status_from_log(rc, text)
    cov = parse_coverage_percent(text)
    return {
        "seed": seed,
        "test": test,
        "status": status,
        "returncode": rc,
        "uvm_errors": uvm_errors,
        "uvm_fatals": uvm_fatals,
        "coverage_pct": cov,
        "duration_s": round(duration, 3),
        "log_path": rel(log),
        "coverage_db": rel(cov_dir) if cov_dir.exists() else None,
        "simulator_command": cmd,
        "actual_command_executed": True,
        "result_source": "parsed from actual simulator stdout/stderr log",
    }


def merge_vcs(args: argparse.Namespace) -> dict:
    cov_dir = REPORTS / "vcs_cov.vdb"
    if not cov_dir.exists():
        return {"status": "SKIPPED", "reason": "No VCS coverage database found"}
    report_dir = REPORTS / "vcs_urg_report"
    log = LOGS / "vcs_urg.log"
    cmd = ["urg", "-dir", rel(cov_dir), "-report", rel(report_dir)]
    rc, duration, _ = run_cmd(cmd, log, timeout_s=args.timeout)
    return {
        "status": "PASS" if rc == 0 else "FAIL",
        "command": cmd,
        "returncode": rc,
        "duration_s": round(duration, 3),
        "log_path": rel(log),
        "html_report": rel(report_dir) if report_dir.exists() else None,
        "actual_command_executed": True,
    }


def compile_xcelium(args: argparse.Namespace) -> tuple[bool, list[dict]]:
    # Xcelium compiles/elaborates/runs through xrun per seed. Keeping this empty
    # preserves one common JSON schema across all simulator modes.
    return True, []


def run_xcelium_seed(seed: int, test: str, args: argparse.Namespace) -> dict:
    cov_dir = REPORTS / "xcelium_cov"
    cov_dir.mkdir(parents=True, exist_ok=True)
    log = LOGS / f"xcelium_{test}_seed_{seed}.log"
    cmd = [
        "xrun", "-64bit", "-uvm", "-sv", "-f", rel(FILELIST),
        "-top", "tb_top", "-coverage", "all", "-covworkdir", rel(cov_dir),
        "-covtest", f"{test}_seed_{seed}", "-svseed", str(seed),
        f"+UVM_TESTNAME={test}", "-access", "+rwc",
    ]
    rc, duration, text = run_cmd(cmd, log, timeout_s=args.timeout)
    status, uvm_errors, uvm_fatals = status_from_log(rc, text)
    cov = parse_coverage_percent(text)
    return {
        "seed": seed,
        "test": test,
        "status": status,
        "returncode": rc,
        "uvm_errors": uvm_errors,
        "uvm_fatals": uvm_fatals,
        "coverage_pct": cov,
        "duration_s": round(duration, 3),
        "log_path": rel(log),
        "coverage_db": rel(cov_dir) if cov_dir.exists() else None,
        "simulator_command": cmd,
        "actual_command_executed": True,
        "result_source": "parsed from actual simulator stdout/stderr log",
    }


def merge_xcelium(args: argparse.Namespace) -> dict:
    cov_dir = REPORTS / "xcelium_cov"
    if not cov_dir.exists():
        return {"status": "SKIPPED", "reason": "No Xcelium coverage directory found"}
    return {
        "status": "MANUAL",
        "reason": "Use Cadence IMC to merge/report coverage from reports/xcelium_cov. Example: imc -load reports/xcelium_cov",
        "coverage_db": rel(cov_dir),
    }


def render_html_table(payload: dict) -> str:
    rows = []
    for item in payload.get("results", []):
        cov = item.get("coverage_pct")
        cov_text = "N/A" if cov is None else f"{cov:.2f}%"
        status = item.get("status", "UNKNOWN")
        rows.append(
            "<tr>"
            f"<td>{html.escape(str(item.get('seed')))}</td>"
            f"<td class='{status.lower()}'>{html.escape(status)}</td>"
            f"<td>{cov_text}</td>"
            f"<td>{html.escape(str(item.get('uvm_errors')))}</td>"
            f"<td>{html.escape(str(item.get('uvm_fatals')))}</td>"
            f"<td>{html.escape(str(item.get('duration_s')))}</td>"
            f"<td><a href='../{html.escape(item.get('log_path', ''))}'>log</a></td>"
            "</tr>"
        )
    return "\n".join(rows)


def write_static_snapshot(payload: dict) -> None:
    rows = render_html_table(payload)
    SNAPSHOT_HTML.write_text(f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>SRAM Regression Snapshot</title>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 32px; background: #f7f8fb; color: #1f2937; }}
    h1 {{ margin-bottom: 4px; }}
    .meta {{ color: #4b5563; margin-bottom: 24px; }}
    table {{ border-collapse: collapse; width: 100%; background: white; box-shadow: 0 8px 24px rgba(0,0,0,0.08); }}
    th, td {{ border-bottom: 1px solid #e5e7eb; padding: 10px 12px; text-align: left; }}
    th {{ background: #111827; color: white; }}
    .pass {{ color: #047857; font-weight: 700; }}
    .fail {{ color: #b91c1c; font-weight: 700; }}
  </style>
</head>
<body>
  <h1>SRAM Regression Snapshot</h1>
  <div class="meta">Generated: {html.escape(payload.get('generated_at', ''))} | Simulator: {html.escape(payload.get('simulator', ''))} | Test: {html.escape(payload.get('test', ''))}</div>
  <table>
    <thead><tr><th>Seed</th><th>Status</th><th>Coverage</th><th>UVM Errors</th><th>UVM Fatals</th><th>Duration s</th><th>Log</th></tr></thead>
    <tbody>{rows}</tbody>
  </table>
</body>
</html>
""", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Run real SRAM UVM regressions and generate JSON/HTML reports")
    parser.add_argument("--sim", choices=["questa", "vcs", "xcelium"], required=True)
    parser.add_argument("--test", default="random_test", choices=["base_test", "random_test", "corner_case_test"])
    parser.add_argument("--seeds", type=int, default=20)
    parser.add_argument("--seed-start", type=int, default=1)
    parser.add_argument("--timeout", type=int, default=None, help="Per-command timeout in seconds")
    parser.add_argument("--no-merge", action="store_true", help="Skip coverage merge/report step")
    args = parser.parse_args()

    if args.seeds < 1:
        print("ERROR: --seeds must be at least 1", file=sys.stderr)
        return 2

    REPORTS.mkdir(parents=True, exist_ok=True)
    LOGS.mkdir(parents=True, exist_ok=True)
    BUILDS.mkdir(parents=True, exist_ok=True)
    remove_stale_dashboard_inputs()

    tool_requirements = {
        "questa": ["vlib", "vlog", "vsim"],
        "vcs": ["vcs"],
        "xcelium": ["xrun"],
    }
    if not args.no_merge:
        if args.sim == "questa":
            tool_requirements[args.sim].append("vcover")
        elif args.sim == "vcs":
            tool_requirements[args.sim].append("urg")

    missing, resolved_tools = require_tools(tool_requirements[args.sim])

    common_payload = {
        "generated_at": now_iso(),
        "simulator": args.sim,
        "test": args.test,
        "seed_start": args.seed_start,
        "seeds_requested": args.seeds,
        "filelist": rel(FILELIST),
        "resolved_tools": resolved_tools,
    }

    if missing:
        write_preflight({
            **common_payload,
            "status": "FAILED",
            "stage": "tool_preflight",
            "missing_tools": missing,
            "message": "Required simulator executables were not found. No regression_results.json was generated.",
        })
        print(f"ERROR: missing required tools for {args.sim}: {', '.join(missing)}", file=sys.stderr)
        print(f"Wrote {rel(PREFLIGHT_JSON)}. Did not write {rel(RESULT_JSON)}.")
        return 2

    payload = {
        **common_payload,
        "artifact_type": "real_simulator_regression_results",
        "results": [],
        "compile": [],
        "coverage_merge": None,
        "notes": [
            "Generated only after actual simulator command execution. No placeholder pass/fail, coverage, or fake logs are inserted."
        ],
    }

    compile_map = {
        "questa": compile_questa,
        "vcs": compile_vcs,
        "xcelium": compile_xcelium,
    }
    run_map = {
        "questa": run_questa_seed,
        "vcs": run_vcs_seed,
        "xcelium": run_xcelium_seed,
    }
    merge_map = {
        "questa": merge_questa,
        "vcs": merge_vcs,
        "xcelium": merge_xcelium,
    }

    compile_ok, compile_steps = compile_map[args.sim](args)
    payload["compile"] = compile_steps
    if not compile_ok:
        write_preflight({
            **common_payload,
            "status": "FAILED",
            "stage": "compile_or_elaboration",
            "compile": compile_steps,
            "message": "Compile/elaboration failed before seed simulations. No regression_results.json was generated.",
        })
        print(f"Compilation/elaboration failed. See logs under {rel(LOGS)}", file=sys.stderr)
        print(f"Wrote {rel(PREFLIGHT_JSON)}. Did not write {rel(RESULT_JSON)}.")
        return 1

    for offset in range(args.seeds):
        seed = args.seed_start + offset
        result = run_map[args.sim](seed, args.test, args)
        payload["results"].append(result)
        # Only now, after at least one real seed command has completed, write dashboard data.
        write_json(RESULT_JSON, payload)
        print(f"seed={seed} status={result['status']} coverage={result['coverage_pct']} log={result['log_path']}")

    if not args.no_merge:
        payload["coverage_merge"] = merge_map[args.sim](args)

    passed = sum(1 for r in payload["results"] if r["status"] == "PASS")
    failed = len(payload["results"]) - passed
    payload["summary"] = {
        "passed": passed,
        "failed": failed,
        "pass_rate_pct": round((passed / len(payload["results"])) * 100, 2) if payload["results"] else 0.0,
    }

    write_json(RESULT_JSON, payload)
    write_static_snapshot(payload)

    print(f"\nSummary: {passed} passed, {failed} failed")
    print(f"JSON: {rel(RESULT_JSON)}")
    print(f"Dashboard: {rel(REPORTS / 'coverage_dashboard.html')}")
    print(f"Static snapshot: {rel(SNAPSHOT_HTML)}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
