#!/usr/bin/env bash
# grype-linux-scan.sh — Scan locally-built Linux packages (DEB/RPM) for CVEs
#
# Supports: Debian/Ubuntu .deb, RHEL/CentOS/Fedora .rpm, SUSE/SLES .rpm
#
# Extracts each package and scans its installed contents with grype.
# Grype's java-jvm-cataloger reads the bundled `release` file and emits a CPE
# (cpe:2.3:a:oracle:openjdk:<version>:...) matched against NVD/Oracle advisories.
# Also catalogues any bundled JARs and ELF binaries.
#
# Note: these are privately-built packages not registered in any distro advisory
# database, so PURL-based package lookups are not used. Only installed content
# (what ships inside the package) is scanned.
#
# Usage:
#   ./grype-linux-scan.sh [OPTIONS] <package-file(s)>
#
# Package type is detected by file extension: *.deb or *.rpm
#
# Options:
#   --distro DISTRO     Target distro for CVE matching (default: auto-detect from path,
#                       or $GRYPE_DISTRO). Examples: ubuntu:24.04  rhel:9  sles:15
#   --fail-on SEVERITY  Exit 2 if severity >= this (default: high or $GRYPE_FAIL_ON)
#   --config FILE       Grype config file (default: .grype-<distro>.yaml or .grype.yaml)
#   --output-dir DIR    Directory for reports (default: ./grype-results)
#   --show-suppressed   Include suppressed findings in table output
#   --only-fixed        Only report vulnerabilities with a known fix
#
# Environment variable overrides:
#   GRYPE_DISTRO        e.g. rhel:9
#   GRYPE_FAIL_ON       e.g. high
#   GRYPE_CONFIG        path to a config file
#   GRYPE_OUTPUT_DIR    output directory
#
# Exit codes:
#   0 — no vulnerabilities at or above --fail-on threshold
#   1 — setup/extraction error or no package files provided
#   2 — vulnerabilities found at or above threshold

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Defaults ──────────────────────────────────────────────────────────────────
DISTRO_OVERRIDE="${GRYPE_DISTRO:-}"
FAIL_ON="${GRYPE_FAIL_ON:-high}"
OUTPUT_DIR="${GRYPE_OUTPUT_DIR:-./grype-results}"
CONFIG_OVERRIDE="${GRYPE_CONFIG:-}"
SHOW_SUPPRESSED=false
ONLY_FIXED=false
PKG_FILES=()

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

pkg_type()      { case "$1" in *.deb) echo "deb" ;; *.rpm) echo "rpm" ;; esac; }

default_distro() {
    case "$(pkg_type "$1")" in
        deb) echo "ubuntu:24.04" ;;
        rpm)
            if echo "$1" | grep -qi "suse\|sles"; then echo "sles:15"
            else echo "rhel:9"; fi ;;
    esac
}

resolve_config() {
    local distro="$1"
    if [[ -n "$CONFIG_OVERRIDE" ]]; then echo "$CONFIG_OVERRIDE"; return; fi
    local base="${distro%%:*}"
    if   [[ -f "$SCRIPT_DIR/.grype-${base}.yaml" ]]; then echo "$SCRIPT_DIR/.grype-${base}.yaml"
    elif [[ -f ".grype-${base}.yaml" ]];            then echo ".grype-${base}.yaml"
    elif [[ -f "$SCRIPT_DIR/.grype.yaml" ]];        then echo "$SCRIPT_DIR/.grype.yaml"
    elif [[ -f ".grype.yaml" ]];                    then echo ".grype.yaml"
    else echo ""; fi
}

extract_deb() {
    local deb="$1" work="$2" dest="$3"
    mkdir -p "$work" "$dest"
    ar x "$deb" --output "$work" 2>/dev/null || (cd "$work" && ar x "$deb" 2>/dev/null)
    local data_tar
    data_tar="$(ls "$work"/data.tar.* 2>/dev/null | head -1)"
    [[ -n "$data_tar" ]] || { echo "ERROR: no data archive in $deb" >&2; return 1; }
    tar -xf "$data_tar" -C "$dest" 2>/dev/null
}

extract_rpm() {
    local rpm="$1" dest="$2"
    mkdir -p "$dest"
    rpm2cpio "$rpm" | cpio -idm -D "$dest" 2>/dev/null || \
        (cd "$dest" && rpm2cpio "$rpm" | cpio -idm 2>/dev/null)
}

pkg_name_deb() {
    local work="$1"
    local ctrl_tar
    ctrl_tar="$(ls "$work"/control.tar.* 2>/dev/null | head -1)"
    [[ -n "$ctrl_tar" ]] || { echo ""; return; }
    tar -xOf "$ctrl_tar" ./control 2>/dev/null | grep "^Package:" | awk '{print $2}'
}

pkg_name_rpm() { rpm -qp --qf "%{NAME}" "$1" 2>/dev/null; }

# ── Argument parsing ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --distro)          DISTRO_OVERRIDE="$2"; shift 2 ;;
        --fail-on)         FAIL_ON="$2"; shift 2 ;;
        --config)          CONFIG_OVERRIDE="$2"; shift 2 ;;
        --output-dir)      OUTPUT_DIR="$2"; shift 2 ;;
        --show-suppressed) SHOW_SUPPRESSED=true; shift ;;
        --only-fixed)      ONLY_FIXED=true; shift ;;
        --help|-h)
            sed -n '2,38p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *.deb|*.rpm)
            [[ -f "$1" ]] || { echo "ERROR: File not found: $1" >&2; exit 1; }
            PKG_FILES+=("$1"); shift ;;
        *)
            echo "ERROR: Unknown argument: $1 (try --help)" >&2; exit 1 ;;
    esac
done

[[ ${#PKG_FILES[@]} -gt 0 ]] || {
    echo "ERROR: No .deb or .rpm files specified" >&2
    echo "Usage: $0 [OPTIONS] <pkg.deb|pkg.rpm> ..." >&2
    exit 1
}

# ── Setup ──────────────────────────────────────────────────────────────────────
ensure_grype || exit 1

WORK_DIR="$(mktemp -d /tmp/grype-linux-scan.XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT
mkdir -p "$OUTPUT_DIR"

FINAL_EXIT=0

echo "grype Linux Package Content Scan"
echo "═══════════════════════════════════════════════════════════"
echo "  Packages: ${#PKG_FILES[@]} file(s)"
echo "  Fail on:  >= $FAIL_ON severity"
echo "  Output:   $OUTPUT_DIR"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# Per-package: extract and scan
# ══════════════════════════════════════════════════════════════════════════════
for PKG_FILE in "${PKG_FILES[@]}"; do
    PKG_BASE="$(basename "$PKG_FILE")"
    PKG_STEM="${PKG_BASE%.deb}"; PKG_STEM="${PKG_STEM%.rpm}"
    FMT="$(pkg_type "$PKG_FILE")"

    DISTRO="${DISTRO_OVERRIDE:-$(default_distro "$PKG_FILE")}"
    CONFIG="$(resolve_config "$DISTRO")"

    echo "── $PKG_STEM"
    echo "   Format: $FMT   Distro: $DISTRO   Config: ${CONFIG:-<none>}"

    # ── Extract ───────────────────────────────────────────────────────────────
    PKG_WORK="$WORK_DIR/meta/$PKG_STEM"
    EXTRACT_DIR="$WORK_DIR/content/$PKG_STEM"

    if [[ "$FMT" == "deb" ]]; then
        extract_deb "$PKG_FILE" "$PKG_WORK" "$EXTRACT_DIR"
        PKG_NAME="$(pkg_name_deb "$PKG_WORK")"
    else
        extract_rpm "$PKG_FILE" "$EXTRACT_DIR"
        PKG_NAME="$(pkg_name_rpm "$PKG_FILE")"
    fi
    [[ -z "$PKG_NAME" ]] && PKG_NAME="$PKG_STEM"

    # ── Scan ──────────────────────────────────────────────────────────────────
    GRYPE_ARGS=(
        "dir:$EXTRACT_DIR"
        "--fail-on"  "$FAIL_ON"
        "--distro"   "$DISTRO"
        "--name"     "$PKG_NAME"
        "--sort-by"  "risk"
        "--by-cve"
        "--add-cpes-if-none"
        "--output"   "table"
        "--output"   "json=$OUTPUT_DIR/${PKG_STEM}.json"
        "--output"   "sarif=$OUTPUT_DIR/${PKG_STEM}.sarif.json"
    )
    [[ -n "$CONFIG" ]]               && GRYPE_ARGS+=("--config" "$CONFIG")
    [[ "$SHOW_SUPPRESSED" == true ]] && GRYPE_ARGS+=("--show-suppressed")
    [[ "$ONLY_FIXED"      == true ]] && GRYPE_ARGS+=("--only-fixed")

    set +e
    grype "${GRYPE_ARGS[@]}" 2>&1 | tee "$OUTPUT_DIR/${PKG_STEM}.txt"
    PKG_EXIT=$?
    set -e

    [[ $PKG_EXIT -gt $FINAL_EXIT ]] && FINAL_EXIT=$PKG_EXIT
    echo ""
done

# ── Summary Report Generation ──────────────────────────────────────────────────
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
