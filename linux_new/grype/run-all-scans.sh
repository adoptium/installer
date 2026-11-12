#!/usr/bin/env bash
# run-all-scans.sh — Run Grype vulnerability scans across all discovered packages (.apk, .deb, .rpm)
#
# Scans APK, DEB, RHEL RPM, and SUSE RPM packages found in search paths,
# generating per-package reports and an aggregated summary.
#
# Usage:
#   ./run-all-scans.sh [OPTIONS] [SEARCH_DIR]
#
# Options:
#   --output-dir DIR    Directory for reports (default: ./build/grype-results or $GRYPE_OUTPUT_DIR)
#   --fail-on SEVERITY  Exit 2 if severity >= this (default: high or $GRYPE_FAIL_ON)
#   --search-dir DIR    Directory to search for packages (default: . or first positional arg)
#   --help, -h          Show this help message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FAIL_ON="${GRYPE_FAIL_ON:-high}"
OUTPUT_DIR="${GRYPE_OUTPUT_DIR:-./build/grype-results}"
SEARCH_DIR="."

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --fail-on)
            FAIL_ON="$2"
            shift 2
            ;;
        --search-dir)
            SEARCH_DIR="$2"
            shift 2
            ;;
        --help|-h)
            sed -n '2,14p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        -*)
            echo "ERROR: Unknown option: $1" >&2
            exit 1
            ;;
        *)
            SEARCH_DIR="$1"
            shift
            ;;
    esac
done

mkdir -p "$OUTPUT_DIR"

echo "==========================================================="
echo "  Eclipse Temurin Grype Package Vulnerability Scanner"
echo "==========================================================="
echo "  Search root: $SEARCH_DIR"
echo "  Output dir:  $OUTPUT_DIR"
echo "  Fail on:     >= $FAIL_ON"
echo "==========================================================="

FINAL_EXIT=0

# 1. Discover and scan Alpine APKs
mapfile -t APK_FILES < <(find "$SEARCH_DIR" -type f -not -path "*/packageTest/*" -name "*.apk" ! -name "*.src.apk" 2>/dev/null | sort || true)
if [[ ${#APK_FILES[@]} -gt 0 ]]; then
    echo ""
    echo ">> Scanning ${#APK_FILES[@]} Alpine APK package(s)..."
    set +e
    "$SCRIPT_DIR/grype-apk-scan.sh" \
        --fail-on "$FAIL_ON" \
        --output-dir "$OUTPUT_DIR/apk" \
        "${APK_FILES[@]}"
    APK_EXIT=$?
    set -e
    [[ $APK_EXIT -gt $FINAL_EXIT ]] && FINAL_EXIT=$APK_EXIT
fi

# 2. Discover and scan Debian/Ubuntu DEBs
mapfile -t DEB_FILES < <(find "$SEARCH_DIR" -type f -not -path "*/packageTest/*" -name "*.deb" 2>/dev/null | sort || true)
if [[ ${#DEB_FILES[@]} -gt 0 ]]; then
    echo ""
    echo ">> Scanning ${#DEB_FILES[@]} Debian/Ubuntu DEB package(s)..."
    set +e
    "$SCRIPT_DIR/grype-linux-scan.sh" \
        --distro "ubuntu:24.04" \
        --fail-on "$FAIL_ON" \
        --output-dir "$OUTPUT_DIR/deb" \
        "${DEB_FILES[@]}"
    DEB_EXIT=$?
    set -e
    [[ $DEB_EXIT -gt $FINAL_EXIT ]] && FINAL_EXIT=$DEB_EXIT
fi

# 3. Discover and scan RHEL RPMs (exclude SUSE subdirectories)
mapfile -t RHEL_RPM_FILES < <(find "$SEARCH_DIR" -type f -not -path "*/packageTest/*" -name "*.rpm" ! -name "*.src.rpm" 2>/dev/null | grep -v "/suse/" | grep -v "sles" | sort || true)
if [[ ${#RHEL_RPM_FILES[@]} -gt 0 ]]; then
    echo ""
    echo ">> Scanning ${#RHEL_RPM_FILES[@]} RHEL RPM package(s)..."
    set +e
    "$SCRIPT_DIR/grype-linux-scan.sh" \
        --distro "rhel:9" \
        --fail-on "$FAIL_ON" \
        --output-dir "$OUTPUT_DIR/rhel" \
        "${RHEL_RPM_FILES[@]}"
    RHEL_EXIT=$?
    set -e
    [[ $RHEL_EXIT -gt $FINAL_EXIT ]] && FINAL_EXIT=$RHEL_EXIT
fi

# 4. Discover and scan SUSE RPMs
mapfile -t SUSE_RPM_FILES < <(find "$SEARCH_DIR" -type f -not -path "*/packageTest/*" -name "*.rpm" ! -name "*.src.rpm" 2>/dev/null | grep -E "(/suse/|sles)" | sort || true)
if [[ ${#SUSE_RPM_FILES[@]} -gt 0 ]]; then
    echo ""
    echo ">> Scanning ${#SUSE_RPM_FILES[@]} SUSE RPM package(s)..."
    set +e
    "$SCRIPT_DIR/grype-linux-scan.sh" \
        --distro "sles:15" \
        --fail-on "$FAIL_ON" \
        --output-dir "$OUTPUT_DIR/suse" \
        "${SUSE_RPM_FILES[@]}"
    SUSE_EXIT=$?
    set -e
    [[ $SUSE_EXIT -gt $FINAL_EXIT ]] && FINAL_EXIT=$SUSE_EXIT
fi

# 5. Global aggregated summary report across all subdirectories
echo ""
echo "==========================================================="
echo "  Generating Global Aggregated Vulnerability Summary..."
echo "==========================================================="
if [[ -f "$SCRIPT_DIR/grype-summary-report.py" ]] && command -v python3 >/dev/null 2>&1; then
    python3 "$SCRIPT_DIR/grype-summary-report.py" \
        "$OUTPUT_DIR" \
        --format text \
        --output "$OUTPUT_DIR/global-summary.txt" \
        --fail-on "$FAIL_ON" \
        --no-exit-code || true

    python3 "$SCRIPT_DIR/grype-summary-report.py" \
        "$OUTPUT_DIR" \
        --format markdown \
        --output "$OUTPUT_DIR/global-summary.md" \
        --fail-on "$FAIL_ON" \
        --no-exit-code || true

    if [[ -f "$OUTPUT_DIR/global-summary.txt" ]]; then
        cat "$OUTPUT_DIR/global-summary.txt"
    fi
fi

case $FINAL_EXIT in
    0) echo "  Overall Status: PASSED — no vulnerabilities at or above '$FAIL_ON'" ;;
    2) echo "  Overall Status: FAILED — vulnerabilities at or above '$FAIL_ON' found" ;;
    *) echo "  Overall Status: ERROR  — scanner exited with code $FINAL_EXIT" ;;
esac
echo "==========================================================="
exit $FINAL_EXIT
