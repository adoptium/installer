#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

REPOSITORY=$(cd "$(dirname "$0")/../../.." && pwd)
WORK_DIRECTORY=$(mktemp -d "$HOME/.adoptium-installer-test.XXXXXXXX")
readonly WORK_DIRECTORY
case "$WORK_DIRECTORY" in
  "$HOME"/.adoptium-installer-test.*) ;;
  *) echo "Unsafe test directory: $WORK_DIRECTORY" >&2; exit 1 ;;
esac
RUN_ID=$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-')
RECEIPTS="$WORK_DIRECTORY/receipts"
: > "$RECEIPTS"
RECEIPTS_DIRECTORY_EXISTED=false
if [ -d "$HOME/Library/Receipts" ]; then
  RECEIPTS_DIRECTORY_EXISTED=true
fi

cleanup() {
  local status=$? receipt
  trap - EXIT
  while IFS= read -r receipt; do
    if pkgutil --volume "$HOME" --pkg-info "$receipt" >/dev/null 2>&1; then
      if ! pkgutil --volume "$HOME" --forget "$receipt" >/dev/null; then
        echo "Failed to remove test receipt: $receipt" >&2
        status=1
      fi
    fi
  done < "$RECEIPTS"
  rm -rf "$WORK_DIRECTORY"
  if [ "$RECEIPTS_DIRECTORY_EXISTED" = false ] && [ -d "$HOME/Library/Receipts" ]; then
    rmdir "$HOME/Library/Receipts" 2>/dev/null || true
  fi
  exit "$status"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

HOST_ARCH=$(uname -m)
case "$HOST_ARCH" in
  arm64|x86_64) ;;
  *) fail "Unsupported macOS test architecture: $HOST_ARCH" ;;
esac

build_fixture() {
  local profile="$1" release="$2" version="$3" short_version="$4" build_version="$5"
  local identifier="$6" major="$7" type="$8" bundle_identifier="$9"
  local build="$WORK_DIRECTORY/builds/${profile}-${release}"
  local relative="${WORK_DIRECTORY#"$HOME"/}/installed/${profile}.${type}"
  mkdir -p "$build/input/Contents/Home"
  cat > "$build/input/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$bundle_identifier</string>
  <key>CFBundleVersion</key><string>$build_version</string>
  <key>CFBundleShortVersionString</key><string>$short_version</string>
  <key>CFBundlePackageType</key><string>BNDL</string>
</dict></plist>
PLIST
  printf '%s\n' "$release" > "$build/input/Contents/Home/marker"
  if [ "$release" = old ]; then
    printf 'only in old package\n' > "$build/input/Contents/Home/obsolete"
  fi

  if ! bash "$REPOSITORY/pkgbuild/packagesbuild.sh" \
    --major_version "$major" --full_version "$version" \
    --input_directory "$build/input" --output_directory "$build/production.pkg" \
    --jvm hotspot --architecture "$HOST_ARCH" --type "$type" \
    --vendor compat --identifier "$identifier" > "$build/build.log" 2>&1; then
    cat "$build/build.log" >&2
    fail "Could not build $profile $release fixture"
  fi

  local style
  for style in legacy native; do
    pkgutil --expand-full "$build/production.pkg" "$build/$style"
    if [ "$style" = legacy ]; then
      python3 "$REPOSITORY/test/functional/pkgbuild/rebase_fixture.py" \
        "$build/$style" "$relative" --legacy
    else
      python3 "$REPOSITORY/test/functional/pkgbuild/rebase_fixture.py" \
        "$build/$style" "$relative"
    fi
    pkgutil --flatten-full "$build/$style" "$build/$style.pkg"
    [ "$(installer -dominfo -pkg "$build/$style.pkg")" = CurrentUserHomeDirectory ] \
      || fail "$profile $style fixture is not restricted to the current user"
  done
}

forget_receipt() {
  local identifier="$1"
  if pkgutil --volume "$HOME" --pkg-info "$identifier" >/dev/null 2>&1; then
    pkgutil --volume "$HOME" --forget "$identifier" >/dev/null
  fi
}

run_transition() {
  local profile="$1" identifier="$2" type="$3"
  local first_style="$4" first_release="$5" second_style="$6" second_release="$7"
  local target="$WORK_DIRECTORY/installed/${profile}.${type}"
  local first="$WORK_DIRECTORY/builds/${profile}-${first_release}/${first_style}.pkg"
  local second="$WORK_DIRECTORY/builds/${profile}-${second_release}/${second_style}.pkg"
  local log="$WORK_DIRECTORY/${profile}-installer.log"
  rm -rf "$target"
  forget_receipt "$identifier"

  if ! installer -pkg "$first" -target CurrentUserHomeDirectory -allowUntrusted > "$log" 2>&1; then
    cat "$log" >&2
    fail "$profile initial $first_style $first_release installation"
  fi
  [ "$(cat "$target/Contents/Home/marker")" = "$first_release" ] \
    || fail "$profile initial installation did not install its payload"
  if ! installer -pkg "$second" -target CurrentUserHomeDirectory -allowUntrusted > "$log" 2>&1; then
    cat "$log" >&2
    fail "$profile subsequent $second_style $second_release installation"
  fi
  local marker obsolete receipt_version
  marker=$(cat "$target/Contents/Home/marker")
  if [ -e "$target/Contents/Home/obsolete" ]; then obsolete=present; else obsolete=absent; fi
  receipt_version=$(pkgutil --volume "$HOME" --pkg-info "$identifier" | awk '/^version:/ {print $2}')
  [ -n "$receipt_version" ] || fail "$profile installation did not record a version"
  printf '%s %s %s\n' "$marker" "$obsolete" "$receipt_version"
}

test_profile() {
  local profile="$1" major="$2" type="$3" old_version="$4" old_short="$5" old_build="$6"
  local new_version="$7" new_short="$8" new_build="$9" bundle_mode="${10}"
  local identifier="org.adoptium.installer.test${RUN_ID}.${profile}"
  local bundle_identifier
  case "$bundle_mode" in
    same) bundle_identifier="$identifier" ;;
    distinct) bundle_identifier="${identifier}.bundle" ;;
    *) fail "Unknown fixture bundle identifier mode: $bundle_mode" ;;
  esac
  if pkgutil --volume "$HOME" --pkg-info "$identifier" >/dev/null 2>&1; then
    fail "Test receipt already exists: $identifier"
  fi
  printf '%s\n' "$identifier" >> "$RECEIPTS"
  build_fixture "$profile" old "$old_version" "$old_short" "$old_build" "$identifier" "$major" "$type" "$bundle_identifier"
  build_fixture "$profile" new "$new_version" "$new_short" "$new_build" "$identifier" "$major" "$type" "$bundle_identifier"

  local direction baseline result first_style second_style first_release second_release
  for direction in upgrade downgrade; do
    if [ "$direction" = upgrade ]; then
      first_release=old; second_release=new
    else
      first_release=new; second_release=old
    fi
    baseline=$(run_transition "$profile" "$identifier" "$type" legacy "$first_release" legacy "$second_release")
    if [ "$direction" = upgrade ] && [ "$baseline" != "new absent $new_version" ]; then
      fail "$profile upstream-style upgrade produced $baseline"
    fi
    for first_style in legacy native; do
      for second_style in legacy native; do
        result=$(run_transition "$profile" "$identifier" "$type" \
          "$first_style" "$first_release" "$second_style" "$second_release")
        [ "$result" = "$baseline" ] \
          || fail "$profile $direction $first_style -> $second_style: expected '$baseline', got '$result'"
      done
    done
    echo "PASS: $profile $direction matches upstream-style behavior ($baseline)"
  done
}

test_profile jdk25 25 jdk "25.0.4.1+1-LTS" "25.0.4.1" "1" "25.0.5+8-LTS" "25.0.5" "8" distinct
test_profile jdk25build 25 jdk "25.0.5+7-LTS" "25.0.5" "7" "25.0.5+8-LTS" "25.0.5" "8" distinct
test_profile jdk8 8 jdk "1.8.0_503-b08" "1.0" "1.8.0_503" "1.8.0_504-b01" "1.0" "1.8.0_504" same
test_profile jre11 11 jre "11.0.32+8" "11.0.32" "" "11.0.33+10" "11.0.33" "" distinct
