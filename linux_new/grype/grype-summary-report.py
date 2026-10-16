#!/usr/bin/env python3
"""
grype-summary-report.py — Consolidated Vulnerability Report Generator for Grype Scans

Parses per-package Grype JSON reports (*.json, excluding *.sarif.json) and generates
consolidated summary reports in Markdown (for CI job summaries/pull requests)
and Plain Text formats.
"""

import argparse
import json
import os
import sys
from datetime import datetime
from pathlib import Path

SEVERITY_LEVELS = ["Critical", "High", "Medium", "Low", "Negligible"]
SEVERITY_WEIGHT = {
    "critical": 5,
    "high": 4,
    "medium": 3,
    "low": 2,
    "negligible": 1,
    "unknown": 0,
}


def parse_grype_json(file_path):
    """Parse a single Grype JSON output file and extract key metrics."""
    with open(file_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    matches = data.get("matches", [])
    descriptor = data.get("descriptor", {})
    distro = data.get("distro", {})
    db_raw = descriptor.get("db", {})
    db_status = db_raw.get("status", {}) if isinstance(db_raw, dict) else {}
    db_built = db_status.get("built") or db_raw.get("built", "Unknown")
    db_schema = db_status.get("schemaVersion") or db_raw.get("schemaVersion", "Unknown")
    config = descriptor.get("configuration", {})

    counts = {s: 0 for s in SEVERITY_LEVELS}
    counts["Suppressed"] = 0
    counts["Total"] = 0

    cve_details = []

    for m in matches:
        vuln = m.get("vulnerability", {})
        artifact = m.get("artifact", {})
        suppressed = m.get("suppressed", False)
        severity = vuln.get("severity", "Unknown").capitalize()

        if suppressed:
            counts["Suppressed"] += 1
            continue

        counts["Total"] += 1
        if severity in counts:
            counts[severity] += 1
        else:
            counts[severity] = counts.get(severity, 0) + 1

        fix = vuln.get("fix", {})
        fix_versions = fix.get("versions", []) if isinstance(fix, dict) else []

        cve_details.append({
            "id": vuln.get("id", "Unknown"),
            "severity": severity,
            "package": artifact.get("name", "Unknown"),
            "installed_version": artifact.get("version", "Unknown"),
            "fixed_in": ", ".join(fix_versions) if fix_versions else "None",
            "data_source": vuln.get("dataSource", ""),
        })

    # Derive package name / version from file stem or artifact
    stem = Path(file_path).stem
    if stem.endswith(".sarif"):
        return None  # Ignore sarif files

    distro_str = f"{distro.get('name', '')}:{distro.get('version', '')}".strip(":")
    if not distro_str and config.get("distro"):
        distro_str = str(config.get("distro"))

    return {
        "file": str(file_path),
        "stem": stem,
        "counts": counts,
        "cves": cve_details,
        "distro": distro_str,
        "scanner_version": descriptor.get("version", "Unknown"),
        "scan_time": descriptor.get("timestamp", ""),
        "db_built": db_built,
        "db_schema": db_schema,
        "fail_on": config.get("fail-on-severity", "high"),
    }


def collect_reports(input_paths):
    """Collect and parse all valid Grype JSON files from directories or files."""
    json_files = []
    for p in input_paths:
        path_obj = Path(p)
        if path_obj.is_dir():
            for f in sorted(path_obj.rglob("*.json")):
                if not f.name.endswith(".sarif.json"):
                    json_files.append(f)
        elif path_obj.is_file():
            if path_obj.name.endswith(".json") and not path_obj.name.endswith(".sarif.json"):
                json_files.append(path_obj)

    reports = []
    for f in sorted(set(json_files)):
        try:
            res = parse_grype_json(f)
            if res:
                reports.append(res)
        except Exception as e:
            print(f"Warning: Failed to parse {f}: {e}", file=sys.stderr)

    return reports


def calculate_totals(reports):
    """Aggregate severity counts across all parsed reports."""
    totals = {s: 0 for s in SEVERITY_LEVELS}
    totals["Suppressed"] = 0
    totals["Total"] = 0

    for r in reports:
        for k in totals:
            totals[k] += r["counts"].get(k, 0)
    return totals


def evaluate_verdict(reports, fail_on="high"):
    """Evaluate whether any report breaches the fail-on threshold."""
    threshold = SEVERITY_WEIGHT.get(fail_on.lower(), 4)
    has_failure = False

    for r in reports:
        for cve in r["cves"]:
            cve_weight = SEVERITY_WEIGHT.get(cve["severity"].lower(), 0)
            if cve_weight >= threshold:
                has_failure = True
                break
        if has_failure:
            break

    return not has_failure


def generate_markdown(reports, title="Eclipse Temurin Linux Package Vulnerability Scan Summary", fail_on="high"):
    """Generate Markdown report suitable for GitHub Step Summaries or PRs."""
    totals = calculate_totals(reports)
    passed = evaluate_verdict(reports, fail_on)

    db_built = reports[0]["db_built"] if reports else "Unknown"
    db_schema = reports[0]["db_schema"] if reports else "Unknown"
    scanner_ver = reports[0]["scanner_version"] if reports else "Unknown"

    lines = []
    lines.append(f"## {title}")
    lines.append("")
    verdict_badge = ":white_check_mark: **PASSED**" if passed else ":x: **FINDINGS DETECTED**"
    lines.append(f"**Overall Verdict:** {verdict_badge} (Threshold: `{fail_on.upper()}`)")
    lines.append(f"- **Scanner:** Grype `{scanner_ver}` | **DB Built:** `{db_built}` (Schema `{db_schema}`)")
    lines.append(f"- **Packages Scanned:** {len(reports)}")
    lines.append("")
    lines.append("### Results Summary")
    lines.append("")
    lines.append("| Package / Artifact | Distro Context | Critical | High | Medium | Low | Negligible | Total | Status |")
    lines.append("| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |")

    threshold = SEVERITY_WEIGHT.get(fail_on.lower(), 4)

    for r in reports:
        counts = r["counts"]
        pkg_failed = any(SEVERITY_WEIGHT.get(c["severity"].lower(), 0) >= threshold for c in r["cves"])
        status = ":x: FAIL" if pkg_failed else ":white_check_mark: PASS"
        lines.append(
            f"| `{r['stem']}` | {r['distro'] or 'N/A'} | {counts['Critical']} | {counts['High']} | "
            f"{counts['Medium']} | {counts['Low']} | {counts['Negligible']} | {counts['Total']} | {status} |"
        )

    lines.append(
        f"| **TOTAL** | — | **{totals['Critical']}** | **{totals['High']}** | "
        f"**{totals['Medium']}** | **{totals['Low']}** | **{totals['Negligible']}** | **{totals['Total']}** | {verdict_badge} |"
    )
    lines.append("")

    # CVE details if any
    all_cves = []
    for r in reports:
        for c in r["cves"]:
            all_cves.append({**c, "source_pkg": r["stem"]})

    if all_cves:
        lines.append("### Detected Vulnerabilities")
        lines.append("")
        lines.append("| CVE ID | Severity | Artifact | Installed Version | Fixed In | Package |")
        lines.append("| :--- | :--- | :--- | :--- | :--- | :--- |")
        for c in all_cves:
            lines.append(f"| {c['id']} | **{c['severity']}** | `{c['package']}` | {c['installed_version']} | {c['fixed_in']} | `{c['source_pkg']}` |")
        lines.append("")
    else:
        lines.append("### Findings Detail")
        lines.append("")
        lines.append("No vulnerabilities found across scanned packages.")
        lines.append("")

    return "\n".join(lines)


def generate_text(reports, title="GRYPE VULNERABILITY SCAN REPORT", fail_on="high"):
    """Generate Plain Text report matching the prototype format."""
    totals = calculate_totals(reports)
    passed = evaluate_verdict(reports, fail_on)

    db_built = reports[0]["db_built"] if reports else "Unknown"
    db_schema = reports[0]["db_schema"] if reports else "Unknown"
    scanner_ver = reports[0]["scanner_version"] if reports else "Unknown"
    scan_date = datetime.now().strftime("%Y-%m-%d")

    lines = []
    lines.append("=" * 80)
    lines.append(f"{title}")
    lines.append("=" * 80)
    lines.append("")
    lines.append(f"SCAN DATE        {scan_date}")
    lines.append(f"SCANNER          grype {scanner_ver}")
    lines.append(f"VULNERABILITY DB Built {db_built}  |  Schema {db_schema}")
    lines.append(f"FAIL THRESHOLD   {fail_on.upper()} and above")
    lines.append("")
    lines.append("PACKAGES SCANNED")
    for r in reports:
        lines.append(f"  - {r['stem']} (Distro: {r['distro'] or 'generic'})")
    lines.append("")
    lines.append("RESULTS SUMMARY")
    lines.append("  " + "┌" + "─" * 42 + "┬" + "──────" + "┬" + "──────" + "┬" + "────────" + "┬" + "──────" + "┬" + "────────────" + "┬" + "────────┐")
    lines.append("  " + f"│ {'Package':<40} │ {'CRIT':<4} │ {'HIGH':<4} │ {'MEDIUM':<6} │ {'LOW':<4} │ {'NEGLIGIBLE':<10} │ {'TOTAL':<6} │")
    lines.append("  " + "├" + "─" * 42 + "┼" + "──────" + "┼" + "──────" + "┼" + "────────" + "┼" + "──────" + "┼" + "────────────" + "┼" + "────────┤")

    for r in reports:
        c = r["counts"]
        pkg_name = (r["stem"][:38] + "..") if len(r["stem"]) > 40 else r["stem"]
        lines.append(
            "  " + f"│ {pkg_name:<40} │ {c['Critical']:<4} │ {c['High']:<4} │ {c['Medium']:<6} │ {c['Low']:<4} │ {c['Negligible']:<10} │ {c['Total']:<6} │"
        )

    lines.append("  " + "├" + "─" * 42 + "┼" + "──────" + "┼" + "──────" + "┼" + "────────" + "┼" + "──────" + "┼" + "────────────" + "┼" + "────────┤")
    lines.append(
        "  " + f"│ {'TOTAL':<40} │ {totals['Critical']:<4} │ {totals['High']:<4} │ {totals['Medium']:<6} │ {totals['Low']:<4} │ {totals['Negligible']:<10} │ {totals['Total']:<6} │"
    )
    lines.append("  " + "└" + "─" * 42 + "┴" + "──────" + "┴" + "──────" + "┴" + "────────" + "┴" + "──────" + "┴" + "────────────" + "┴" + "────────┘")
    lines.append("")

    verdict_text = "✓ PASSED — no vulnerabilities at or above threshold found" if passed else "✗ FAILED — vulnerabilities found at or above threshold"
    lines.append(f"VERDICT:  {verdict_text}")
    lines.append("")

    all_cves = []
    for r in reports:
        for c in r["cves"]:
            all_cves.append({**c, "source_pkg": r["stem"]})

    lines.append("DETAIL")
    if all_cves:
        for c in all_cves:
            lines.append(f"  [{c['severity']}] {c['id']} in {c['package']} ({c['installed_version']}) — Fixed in: {c['fixed_in']} (Package: {c['source_pkg']})")
    else:
        lines.append("  No CVEs matched against scanned packages.")
    lines.append("")
    lines.append("=" * 80)

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Generate consolidated summary reports from Grype JSON files.")
    parser.add_argument("inputs", nargs="*", default=["."], help="Input directories or Grype JSON files (default: current directory)")
    parser.add_argument("--input-dir", "-i", action="append", help="Directory containing Grype JSON reports")
    parser.add_argument("--output", "-o", help="Output file path (default: stdout)")
    parser.add_argument("--format", "-f", choices=["markdown", "text", "both"], default="markdown", help="Report format (default: markdown)")
    parser.add_argument("--fail-on", default="high", help="Severity threshold (critical, high, medium, low; default: high)")
    parser.add_argument("--title", default="Eclipse Temurin Linux Package Vulnerability Scan Summary", help="Report title")
    parser.add_argument("--no-exit-code", action="store_true", help="Always exit 0 regardless of vulnerability findings")

    args = parser.parse_args()

    input_paths = []
    if args.input_dir:
        input_paths.extend(args.input_dir)
    if args.inputs:
        input_paths.extend(args.inputs)

    reports = collect_reports(input_paths)

    if not reports:
        print("No Grype JSON scan reports found in specified paths.", file=sys.stderr)
        sys.exit(0 if args.no_exit_code else 1)

    if args.format == "markdown":
        output_content = generate_markdown(reports, title=args.title, fail_on=args.fail_on)
    elif args.format == "text":
        output_content = generate_text(reports, title=args.title, fail_on=args.fail_on)
    else:  # both
        md = generate_markdown(reports, title=args.title, fail_on=args.fail_on)
        txt = generate_text(reports, title=args.title, fail_on=args.fail_on)
        output_content = f"{md}\n\n```text\n{txt}\n```"

    if args.output:
        out_path = Path(args.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(output_content + "\n")
        print(f"Summary report written to {args.output}")
    else:
        print(output_content)

    passed = evaluate_verdict(reports, args.fail_on)
    if not args.no_exit_code and not passed:
        sys.exit(2)
    sys.exit(0)


if __name__ == "__main__":
    main()
