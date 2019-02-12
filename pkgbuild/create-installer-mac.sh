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

security unlock-keychain -p `cat ~/.password`
cd pkgbuild
for f in $WORKSPACE/workspace/target/*.tar.gz;
do tar -xf "$f";
  rm -rf Resources/license.rtf
  if [ $f=*hotspot* ]; then
    cp Licenses/license-GPLv2+CE.en-us.rtf Resources/license.rtf
  elif [ $f=*openj9* ]; then
    cp Licenses/license-OpenJ9.en-us.rtf Resources/license.rtf
  fi
  directory=$(ls -d jdk*)
  file=${f%%.*}
  ./pkgbuild.sh --sign "${CERTIFICATE}" --major_version ${MAJOR_VERSION} --full_version ${FULL_VERSION} --input_directory ${directory} --output_directory ${file}.pkg
  rm -rf ${directory}
done
