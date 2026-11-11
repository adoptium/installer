#!/bin/bash

################################################################################
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
################################################################################

set -euo pipefail

SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)
: "${WORKSPACE:?WORKSPACE must point to the installer workspace}"
: "${MAJOR_VERSION:?MAJOR_VERSION is required}"
: "${FULL_VERSION:?FULL_VERSION is required}"
SEARCH_PATTERN=${SEARCH_PATTERN:-OpenJDK*-j*.tar.gz}

if [ -n "${CERTIFICATE:-}" ]; then
  echo "Warning: CERTIFICATE is ignored; the installer must be signed separately." >&2
fi

WORK_DIRECTORY=$(mktemp -d "${TMPDIR:-/tmp}/temurin-mac.XXXXXX")
readonly WORK_DIRECTORY
trap 'rm -rf "$WORK_DIRECTORY"' EXIT

for f in "$WORKSPACE"/workspace/target/"${SEARCH_PATTERN}"; do
  if [ ! -f "$f" ]; then
    echo "No input archives match: $WORKSPACE/workspace/target/$SEARCH_PATTERN" >&2
    exit 1
  fi
  echo "Processing: $f"
  INPUT_DIRECTORY=$(mktemp -d "${WORK_DIRECTORY}/input.XXXXXX")
  tar -xf "$f" -C "$INPUT_DIRECTORY"

  case $f in
    *hotspot*)
      export JVM="hotspot"
    ;;
    *openj9*)
      export JVM="openj9"
    ;;
    *)
      echo Cannot identify variant from filename "${f}" - only hotspot or openj9 are allowable
      exit 1
    ;;
  esac

  # Detect if JRE or JDK
  case $f in
    *-jre_*)
      TYPE="jre"
      ;;
    *)
      TYPE="jdk"
      ;;
  esac

  # Detect architecture
  case $f in
    *x64*)
      ARCHITECTURE="x86_64"
      ;;
    *aarch64*)
      ARCHITECTURE="arm64"
      ;;
    *)
      echo "Cannot identify architecture from filename: $f" >&2
      exit 1
      ;;
  esac

  set -- "$INPUT_DIRECTORY"/*
  if [ "$#" -ne 1 ] || [ ! -d "$1/Contents" ]; then
    echo "Expected exactly one JDK or JRE bundle in $f" >&2
    exit 1
  fi

  "${SCRIPT_DIRECTORY}/packagesbuild.sh" \
    --major_version "$MAJOR_VERSION" \
    --full_version "$FULL_VERSION" \
    --input_directory "$1" \
    --output_directory "${f%.tar.gz}.pkg" \
    --jvm "$JVM" \
    --architecture "$ARCHITECTURE" \
    --type "$TYPE"

  rm "$f"
done
