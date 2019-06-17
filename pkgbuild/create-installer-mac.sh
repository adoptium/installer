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

  # Download JavaFX
  case ${MAJOR_VERSION} in
    8)
      JFX="https://chriswhocodes.com/downloads/openjfx-8u60-sdk-overlay-osx-x64.zip"
    ;;
    11)
      JFX="http://gluonhq.com/download/javafx-11-0-2-sdk-mac"
    ;;
    12)
      JFX="http://gluonhq.com/download/javafx-12-0-1-sdk-mac"
    ;;
  esac

  wget -q $JFX -O javafx.zip
  unzip -q javafx.zip -d javafx

  ./pkgbuild.sh --sign "${CERTIFICATE}" --major_version ${MAJOR_VERSION} --full_version ${FULL_VERSION} --input_directory ${directory} --jfx_input_directory javafx --output_directory ${file}.pkg
  rm -rf ${directory} javafx
done
