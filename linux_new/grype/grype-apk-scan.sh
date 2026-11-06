#!/usr/bin/env bash
# grype-apk-scan.sh — Scan locally-built Alpine APK packages for CVEs
#
# Extracts each .apk and scans its installed contents with grype.
# Grype's java-jvm-cataloger reads the bundled `release` file and emits a CPE
# (cpe:2.3:a:oracle:openjdk:<version>:...) matched against NVD/Oracle advisories.
# Also catalogues any bundled JARs and ELF binaries via java-archive-cataloger
# and binary-classifier-cataloger.
#
# Note: these are privately-built packages not registered in the Alpine advisory
# database, so PURL-based package lookups are not used. Only installed content
# (what ships inside the .apk) is scanned.
#
# Usage:
#   ./grype-apk-scan.sh [OPTIONS] *.apk
#
# Options:
#   --distro DISTRO     Alpine version hint (default: alpine:3.24 or $GRYPE_DISTRO)
#   --fail-on SEVERITY  Exit 2 if severity >= this  (default: high or $GRYPE_FAIL_ON)
#   --config FILE       Grype config file           (default: .grype.yaml in script dir or CWD)
#   --output-dir DIR    Directory for reports       (default: ./grype-results)
#   --show-suppressed   Include suppressed findings in table output
#   --only-fixed        Only report vulnerabilities with a known fix
#
# Environment variable overrides:
#   GRYPE_DISTRO          e.g. alpine:3.24
#   GRYPE_FAIL_ON         e.g. high
#   GRYPE_CONFIG          path to .grype.yaml
#   GRYPE_OUTPUT_DIR      output directory for reports
#
# Exit codes:
#   0 — no vulnerabilities at or above --fail-on threshold
#   1 — setup/extraction error or no APK files provided
#   2 — vulnerabilities found at or above threshold

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Helpers ────────────────────────────────────────────────────────────────────
ensure_grype() {
    if command -v grype >/dev/null 2>&1; then
        return 0
    fi

    for candidate in "$HOME/.local/bin" "/usr/local/bin" "/tmp/bin"; do
        if [[ -x "$candidate/grype" ]]; then
            export PATH="$candidate:$PATH"
            return 0
        fi
    done

    echo "grype not found in PATH. Attempting automatic installation..." >&2
    local install_dir="${GRYPE_INSTALL_DIR:-$HOME/.local/bin}"
    mkdir -p "$install_dir"

    local installed=false
    if command -v curl >/dev/null 2>&1; then
        curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b "$install_dir" && installed=true
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b "$install_dir" && installed=true
    fi

    if [[ "$installed" == true && -x "$install_dir/grype" ]]; then
        export PATH="$install_dir:$PATH"
        echo "grype successfully installed to $install_dir/grype" >&2
        return 0
    fi

    echo "ERROR: grype is required but not installed and automatic installation failed." >&2
    echo "Please install grype (e.g., 'curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin') or ensure it is in PATH." >&2
    return 1
}

# ── Defaults ──────────────────────────────────────────────────────────────────
DISTRO="${GRYPE_DISTRO:-alpine:3.24}"
FAIL_ON="${GRYPE_FAIL_ON:-high}"
OUTPUT_DIR="${GRYPE_OUTPUT_DIR:-./grype-results}"
SHOW_SUPPRESSED=false
ONLY_FIXED=false
APK_FILES=()

if [[ -n "${GRYPE_CONFIG:-}" ]]; then
    CONFIG="$GRYPE_CONFIG"
elif [[ -f "$SCRIPT_DIR/.grype.yaml" ]]; then
    CONFIG="$SCRIPT_DIR/.grype.yaml"
elif [[ -f ".grype.yaml" ]]; then
    CONFIG=".grype.yaml"
else
    CONFIG=""
fi

# ── Argument parsing ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --distro)          DISTRO="$2"; shift 2 ;;
        --fail-on)         FAIL_ON="$2"; shift 2 ;;
        --config)          CONFIG="$2"; shift 2 ;;
        --output-dir)      OUTPUT_DIR="$2"; shift 2 ;;
        --show-suppressed) SHOW_SUPPRESSED=true; shift ;;
        --only-fixed)      ONLY_FIXED=true; shift ;;
        --help|-h)
            sed -n '2,35p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *.apk)
            [[ -f "$1" ]] || { echo "ERROR: File not found: $1" >&2; exit 1; }
            APK_FILES+=("$1"); shift ;;
        *)
            echo "ERROR: Unknown argument: $1 (try --help)" >&2; exit 1 ;;
    esac
done

[[ ${#APK_FILES[@]} -gt 0 ]] || {
    echo "ERROR: No .apk files specified" >&2
    echo "Usage: $0 [OPTIONS] *.apk" >&2
    exit 1
}

# ── Setup ──────────────────────────────────────────────────────────────────────
ensure_grype || exit 1

WORK_DIR="$(mktemp -d /tmp/grype-apk-scan.XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT
mkdir -p "$OUTPUT_DIR"

GRYPE_COMMON=(
    "--fail-on"  "$FAIL_ON"
    "--distro"   "$DISTRO"
    "--sort-by"  "risk"
    "--by-cve"
    "--add-cpes-if-none"
)
[[ -n "$CONFIG" ]]               && GRYPE_COMMON+=("--config" "$CONFIG")
[[ "$SHOW_SUPPRESSED" == true ]] && GRYPE_COMMON+=("--show-suppressed")
[[ "$ONLY_FIXED"      == true ]] && GRYPE_COMMON+=("--only-fixed")

FINAL_EXIT=0

echo "grype APK Content Scan"
echo "═══════════════════════════════════════════════════════════"
echo "  APKs:    ${#APK_FILES[@]} file(s)"
echo "  Distro:  $DISTRO"
echo "  Fail on: >= $FAIL_ON severity"
echo "  Config:  ${CONFIG:-<none>}"
echo "  Output:  $OUTPUT_DIR"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# Per-APK: extract and scan
# ══════════════════════════════════════════════════════════════════════════════
for APK_FILE in "${APK_FILES[@]}"; do
    APK_BASE="$(basename "$APK_FILE" .apk)"
    echo "── $APK_BASE ──────────────────────────────────────"

    # Read package name from .PKGINFO for --name flag
    PKG_NAME="$(tar -xOf "$APK_FILE" .PKGINFO 2>/dev/null | awk '/^pkgname =/ {print $3}')"
    [[ -z "$PKG_NAME" ]] && PKG_NAME="$APK_BASE"

    EXTRACT_DIR="$WORK_DIR/$APK_BASE"
    mkdir -p "$EXTRACT_DIR"
    tar -xzf "$APK_FILE" -C "$EXTRACT_DIR" 2>/dev/null || true

    REPORT_TXT="$OUTPUT_DIR/${APK_BASE}.txt"
    REPORT_JSON="$OUTPUT_DIR/${APK_BASE}.json"
    REPORT_SARIF="$OUTPUT_DIR/${APK_BASE}.sarif.json"

    set +e
    grype "dir:$EXTRACT_DIR" \
        "${GRYPE_COMMON[@]}" \
        "--name"   "$PKG_NAME" \
        "--output" "table" \
        "--output" "json=$REPORT_JSON" \
        "--output" "sarif=$REPORT_SARIF" \
        2>&1 | tee "$REPORT_TXT"
    PKG_EXIT=$?
    set -e

    [[ $PKG_EXIT -gt $FINAL_EXIT ]] && FINAL_EXIT=$PKG_EXIT
done

# ── Summary Report Generation ──────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Generating summary report in $OUTPUT_DIR/ ..."
if [[ -f "$SCRIPT_DIR/grype-summary-report.py" ]] && command -v python3 >/dev/null 2>&1; then
    python3 "$SCRIPT_DIR/grype-summary-report.py" \
        "$OUTPUT_DIR" \
        --format text \
        --output "$OUTPUT_DIR/summary.txt" \
        --fail-on "$FAIL_ON" \
        --no-exit-code || true

    python3 "$SCRIPT_DIR/grype-summary-report.py" \
        "$OUTPUT_DIR" \
        --format markdown \
        --output "$OUTPUT_DIR/summary.md" \
        --fail-on "$FAIL_ON" \
        --no-exit-code || true

    cat "$OUTPUT_DIR/summary.txt"
fi

case $FINAL_EXIT in
    0) echo "  Status: PASSED — no vulnerabilities at or above '$FAIL_ON'" ;;
    2) echo "  Status: FAILED — vulnerabilities at or above '$FAIL_ON' found" ;;
    *) echo "  Status: ERROR  — grype exited with code $FINAL_EXIT" ;;
esac
echo "═══════════════════════════════════════════════════════════"
exit $FINAL_EXIT
