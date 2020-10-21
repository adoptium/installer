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

set -eu

if [ -f ~/.password ]; then
  security unlock-keychain -p `cat ~/.password` login.keychain-db
fi

set +u
SIGN_CERT=
SIGN_CMD=
if [ ! -z "$CERTIFICATE" ]; then
  SIGN_CMD="--sign"
  SIGN_CERT="${CERTIFICATE}"
fi
set -u

set +u
if [ -z "$SEARCH_PATTERN" ]; then
  SEARCH_PATTERN=OpenJDK*-j*.tar.gz
fi
set -u

cd pkgbuild
for f in $WORKSPACE/workspace/target/${SEARCH_PATTERN};
do tar -xf "$f";
  echo "Processing: $f"

  rm -rf Resources/license.rtf

  case $f in
    *hotspot*)
      export JVM="hotspot"
    ;;
    *openj9*)
      export JVM="openj9"
    ;;
  esac

  # Detect if JRE or JDK
  case $f in
    *-jre)
      TYPE="jre"
      ;;
    *)
      TYPE="jdk"
      ;;
  esac

  directory=$(ls -d jdk*)
  file=${f%%.tar.gz*}

  echo running "./packagesbuild.sh ${SIGN_CMD} "${SIGN_CERT}" --major_version ${MAJOR_VERSION} --full_version ${FULL_VERSION} --input_directory ${directory} --output_directory ${file}.pkg --jvm ${JVM} --type ${TYPE}"
  ./packagesbuild.sh ${SIGN_CMD} "${SIGN_CERT}" --major_version ${MAJOR_VERSION} --full_version ${FULL_VERSION} --input_directory ${directory} --output_directory ${file}.pkg --jvm ${JVM} --type ${TYPE}

  rm -rf ${directory}
  rm -rf ${f}
done
