#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

REPOSITORY=$(cd "$(dirname "$0")/../../.." && pwd)
BUILDER="${REPOSITORY}/pkgbuild/packagesbuild.sh"
WORK_DIRECTORY=$(mktemp -d "${TMPDIR:-/tmp}/temurin-pkg-tests.XXXXXX")
readonly WORK_DIRECTORY
trap 'rm -rf "$WORK_DIRECTORY"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_xml() {
  local actual
  actual=$(xmllint --xpath "$2" "$1")
  [ "$actual" = "$3" ] || fail "$2: expected '$3', got '$actual'"
}

expect_failure() {
  local expected=$1
  shift
  if "$@" > "${WORK_DIRECTORY}/failure.log" 2>&1; then
    fail "Command unexpectedly succeeded: $*"
  fi
  grep -Fq -- "$expected" "${WORK_DIRECTORY}/failure.log" || {
    cat "${WORK_DIRECTORY}/failure.log" >&2
    fail "Expected diagnostic: $expected"
  }
}

INPUT="${WORK_DIRECTORY}/input with spaces/jdk-17"
mkdir -p "$INPUT/Contents/Home/bin" "$INPUT/Contents/Home/lib" "$INPUT/.git"
cat > "$INPUT/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>net.java.openjdk.jdk</string>
  <key>CFBundleVersion</key><string>7</string>
  <key>CFBundleShortVersionString</key><string>17.0.3</string>
  <key>CFBundlePackageType</key><string>BNDL</string>
</dict></plist>
PLIST
printf '#!/bin/sh\nexit 0\n' > "$INPUT/Contents/Home/bin/java"
chmod 755 "$INPUT/Contents/Home/bin/java"
printf 'fixture payload\n' > "$INPUT/Contents/Home/lib/fixture"
ln -s ../lib/fixture "$INPUT/Contents/Home/bin/fixture-link"
touch "$INPUT/.DS_Store" "$INPUT/.gitignore" "$INPUT/.git/config"
cp "${REPOSITORY}/pkgbuild/Resources/adoptium.png" "${WORK_DIRECTORY}/logo & mark.png"
printf 'keep this package\n' > "${WORK_DIRECTORY}/unrelated.pkg"

PACKAGE_NAME="Native & <Preview> \"Test\" | \\ user's"
(
  cd "$WORK_DIRECTORY"
  bash "$BUILDER" \
    --major_version 17 --full_version 17.0.3+7 \
    --input_directory "$INPUT" --output_directory native.package.17.0.3.pkg \
    --jvm hotspot --architecture arm64 --type jdk \
    --package-name "$PACKAGE_NAME" --logo "${WORK_DIRECTORY}/logo & mark.png"
)
pkgutil --expand-full "${WORK_DIRECTORY}/native.package.17.0.3.pkg" "${WORK_DIRECTORY}/hotspot"
DIST="${WORK_DIRECTORY}/hotspot/Distribution"
INFO="${WORK_DIRECTORY}/hotspot/payload.pkg/PackageInfo"
PAYLOAD="${WORK_DIRECTORY}/hotspot/payload.pkg/Payload"
BUNDLE="${PAYLOAD}/Library/Java/JavaVirtualMachines/temurin-17.jdk"
assert_xml "$DIST" 'string(/installer-gui-script/title)' "$PACKAGE_NAME"
assert_xml "$DIST" 'string(//options/@hostArchitectures)' arm64
assert_xml "$DIST" 'string(//domains/@enable_anywhere)' false
assert_xml "$DIST" 'string(//domains/@enable_currentUserHome)' false
assert_xml "$DIST" 'string(//domains/@enable_localSystem)' true
assert_xml "$DIST" 'string(//background/@file)' 'logo & mark.png'
assert_xml "$DIST" 'string(//background/@alignment)' bottomleft
assert_xml "$DIST" 'string(//background/@scaling)' proportional
assert_xml "$DIST" 'string(//background-darkAqua/@file)' 'logo & mark.png'
assert_xml "$INFO" 'string(/pkg-info/@identifier)' net.temurin.17.jdk
assert_xml "$INFO" 'string(/pkg-info/@version)' 17.0.3+7
assert_xml "$INFO" 'string(/pkg-info/@install-location)' /
assert_xml "$INFO" 'string(/pkg-info/@auth)' root
assert_xml "$INFO" 'string(/pkg-info/@overwrite-permissions)' false
assert_xml "$INFO" 'string(/pkg-info/@relocatable)' false
assert_xml "$INFO" 'count(//relocate/bundle)' 0
assert_xml "$INFO" 'count(//upgrade-bundle/bundle | //update-bundle/bundle)' 0
assert_xml "$INFO" 'count(//bundle-version/bundle)' 1
assert_xml "$INFO" 'string(/pkg-info/bundle/@CFBundleShortVersionString)' 17.0.3
cmp "$INPUT/Contents/Home/lib/fixture" "$BUNDLE/Contents/Home/lib/fixture"
[ -x "$BUNDLE/Contents/Home/bin/java" ] || fail "Executable permission lost"
[ "$(readlink "$BUNDLE/Contents/Home/bin/fixture-link")" = ../lib/fixture ] || fail "Symlink changed"
[ ! -e "$BUNDLE/.DS_Store" ] && [ ! -e "$BUNDLE/.gitignore" ] && [ ! -e "$BUNDLE/.git" ] \
  || fail "Excluded metadata included in payload"
[ -f "$INPUT/.DS_Store" ] && [ -f "$INPUT/.git/config" ] || fail "Source bundle modified"
[ -f "${WORK_DIRECTORY}/unrelated.pkg" ] || fail "Unrelated output deleted"
cmp "${REPOSITORY}/pkgbuild/Resources/preinstall" "${WORK_DIRECTORY}/hotspot/payload.pkg/Scripts/preinstall"
cmp "${REPOSITORY}/pkgbuild/Licenses/license-GPLv2+CE.en-us.rtf" "${WORK_DIRECTORY}/hotspot/Resources/en.lproj/license.rtf"
cmp "${WORK_DIRECTORY}/logo & mark.png" "${WORK_DIRECTORY}/hotspot/Resources/logo & mark.png"
if /usr/bin/lsbom "${WORK_DIRECTORY}/hotspot/payload.pkg/Bom" | grep -q '/\._'; then
  fail "AppleDouble metadata was included in the payload"
fi
grep -Fq 'Native &amp; &lt;Preview&gt;' "${WORK_DIRECTORY}/hotspot/Resources/en.lproj/welcome.html"
grep -Fq '17.0.3+7' "${WORK_DIRECTORY}/hotspot/Resources/en.lproj/conclusion.html"

bash "$BUILDER" \
  --major_version 17 --full_version 17.0.3+7-LTS \
  --input_directory "$INPUT" --output_directory "${WORK_DIRECTORY}/openj9.pkg" \
  --jvm openj9 --architecture x86_64 --type jre --vendor example
pkgutil --expand-full "${WORK_DIRECTORY}/openj9.pkg" "${WORK_DIRECTORY}/openj9"
assert_xml "${WORK_DIRECTORY}/openj9/Distribution" 'string(//options/@hostArchitectures)' x86_64
assert_xml "${WORK_DIRECTORY}/openj9/payload.pkg/PackageInfo" 'string(/pkg-info/@identifier)' net.example.17-openj9.jre
assert_xml "${WORK_DIRECTORY}/openj9/payload.pkg/PackageInfo" 'string(/pkg-info/@version)' 17.0.3+7-LTS
[ -f "${WORK_DIRECTORY}/openj9/payload.pkg/Payload/Library/Java/JavaVirtualMachines/example-17-openj9.jre/Contents/Info.plist" ] \
  || fail "OpenJ9 JRE bundle name changed"
cmp "${REPOSITORY}/pkgbuild/Licenses/license-OpenJ9.en-us.rtf" "${WORK_DIRECTORY}/openj9/Resources/en.lproj/license.rtf"

bash "$BUILDER" \
  --major_version 17 --full_version 17.0.3_7 \
  --input_directory "$INPUT" --output_directory "${WORK_DIRECTORY}/override.pkg" \
  --jvm hotspot --architecture x86_64 --type jre --identifier org.example.custom
pkgutil --expand "${WORK_DIRECTORY}/override.pkg" "${WORK_DIRECTORY}/override"
assert_xml "${WORK_DIRECTORY}/override/payload.pkg/PackageInfo" 'string(/pkg-info/@identifier)' org.example.custom

WRAPPER_WORKSPACE="${WORK_DIRECTORY}/workspace with spaces"
mkdir -p "$WRAPPER_WORKSPACE/workspace/target"
ARCHIVE="${WRAPPER_WORKSPACE}/workspace/target/OpenJDK17U-jdk_aarch64_mac_hotspot_17.0.3_7.tar.gz"
JRE_ARCHIVE="${WRAPPER_WORKSPACE}/workspace/target/OpenJDK17U-jre_x64_mac_hotspot_17.0.3_7.tar.gz"
tar -czf "$ARCHIVE" -C "$(dirname "$INPUT")" "$(basename "$INPUT")"
tar -czf "$JRE_ARCHIVE" -C "$(dirname "$INPUT")" "$(basename "$INPUT")"
WORKSPACE="$WRAPPER_WORKSPACE" MAJOR_VERSION=17 FULL_VERSION=17.0.3+7 CERTIFICATE=unused \
  bash "${REPOSITORY}/pkgbuild/create-installer-mac.sh"
[ -f "${ARCHIVE%.tar.gz}.pkg" ] || fail "Archive entry point did not create an installer"
[ -f "${JRE_ARCHIVE%.tar.gz}.pkg" ] || fail "Archive entry point did not create the JRE installer"
[ ! -e "$ARCHIVE" ] || fail "Successfully packaged source archive was not removed"
[ ! -e "$JRE_ARCHIVE" ] || fail "Successfully packaged JRE archive was not removed"
pkgutil --expand "${ARCHIVE%.tar.gz}.pkg" "${WORK_DIRECTORY}/wrapper"
assert_xml "${WORK_DIRECTORY}/wrapper/payload.pkg/PackageInfo" 'string(/pkg-info/@version)' 17.0.3+7
pkgutil --expand "${JRE_ARCHIVE%.tar.gz}.pkg" "${WORK_DIRECTORY}/wrapper-jre"
assert_xml "${WORK_DIRECTORY}/wrapper-jre/payload.pkg/PackageInfo" 'string(/pkg-info/@identifier)' net.temurin.17.jre
assert_xml "${WORK_DIRECTORY}/wrapper-jre/Distribution" 'string(//options/@hostArchitectures)' x86_64

tar -czf "$ARCHIVE" -C "$(dirname "$INPUT")" "$(basename "$INPUT")"
tar -czf "$JRE_ARCHIVE" -C "$(dirname "$INPUT")" "$(basename "$INPUT")"
WORKSPACE="$WRAPPER_WORKSPACE" MAJOR_VERSION=17 FULL_VERSION=17.0.3+7 \
  SEARCH_PATTERN='OpenJDK17U-jdk_*.tar.gz' \
  bash "${REPOSITORY}/pkgbuild/create-installer-mac.sh"
[ ! -e "$ARCHIVE" ] || fail "Matching archive was not removed"
[ -f "$JRE_ARCHIVE" ] || fail "SEARCH_PATTERN did not preserve the unmatched archive"
rm "$JRE_ARCHIVE"

INVALID_ARCHIVE="${WRAPPER_WORKSPACE}/workspace/target/OpenJDK17U-jdk_invalid_mac_hotspot_17.0.3_7.tar.gz"
tar -czf "$INVALID_ARCHIVE" -C "$(dirname "$INPUT")" "$(basename "$INPUT")"
expect_failure "Cannot identify architecture" env \
  WORKSPACE="$WRAPPER_WORKSPACE" MAJOR_VERSION=17 FULL_VERSION=17.0.3+7 \
  bash "${REPOSITORY}/pkgbuild/create-installer-mac.sh"
[ -f "$INVALID_ARCHIVE" ] || fail "Source archive was removed after a failed build"

expect_failure "Unknown architecture" bash "$BUILDER" --major_version 17 --full_version 17 \
  --input_directory "$INPUT" --output_directory "${WORK_DIRECTORY}/invalid.pkg" \
  --jvm hotspot --architecture invalid --type jdk
expect_failure "Missing value" bash "$BUILDER" --input_directory
expect_failure "Unknown option" bash "$BUILDER" --unexpected
expect_failure "Local signing is no longer supported" bash "$BUILDER" --sign unused
expect_failure "Contents/Info.plist" bash "$BUILDER" --major_version 17 --full_version 17 \
  --input_directory "${WORK_DIRECTORY}/missing"
expect_failure "No input archives match" env WORKSPACE="$WORK_DIRECTORY" MAJOR_VERSION=17 FULL_VERSION=17 \
  bash "${REPOSITORY}/pkgbuild/create-installer-mac.sh"

echo "PASS: native macOS package metadata, payload, UI, variants, archive entry point and diagnostics"
