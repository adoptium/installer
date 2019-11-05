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
  security unlock-keychain -p `cat ~/.password`
fi

set +u
SIGN_OPTION=
if [ ! -z "$CERTIFICATE" ]; then
  SIGN_OPTION="--sign ${CERTIFICATE}"
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
  rm -rf Resources/license.rtf

  case $f in
    *hotspot*)
      export JVM="hotspot"
      cp Licenses/license-GPLv2+CE.en-us.rtf Resources/license.rtf
    ;;
    *openj9*)
      export JVM="openj9"
      cp Licenses/license-OpenJ9.en-us.rtf Resources/license.rtf
    ;;
  esac

  directory=$(ls -d jdk*)
  file=${f%%.tar.gz*}

  ./pkgbuild.sh ${SIGN_OPTION} --major_version ${MAJOR_VERSION} --full_version ${FULL_VERSION} --input_directory ${directory} --output_directory ${file}.pkg

  rm -rf ${directory}
  rm -rf ${f}
done
