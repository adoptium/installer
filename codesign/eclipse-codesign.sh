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

VENDOR="adoptium"

case $OPERATING_SYSTEM in
    windows) SEARCH_PATTERN=OpenJDK*-j*.msi ;;
    mac) SEARCH_PATTERN=OpenJDK*-j*.pkg ;;
esac

for f in $WORKSPACE/workspace/target/${SEARCH_PATTERN};
do 
    # Detect if JRE or JDK
    case $f in
        *-jre_*)
        TYPE="jre"
        ;;
        *)
        TYPE="jdk"
        ;;
    esac

    echo "Signing $f using Eclipse Foundation codesign service"
    dir=$(dirname "$f")
    file=$(basename "$f")
    mv "$f" "${dir}/unsigned_${file}"

    case $OPERATING_SYSTEM in
        windows) 
            curl -o "$f" -F file="@${dir}/unsigned_${file}" https://cbi.eclipse.org/authenticode/sign
            ;;
        mac)
            curl -o "$f" -F file="@${dir}/unsigned_${file}" https://cbi.eclipse.org/macos/codesign/sign
            IDENTIFIER="net.${VENDOR}.${MAJOR_VERSION}.${TYPE}"
            bash "${WORKSPACE}/codesign/eclipse-notarize.sh" "${f}" "${IDENTIFIER}"
            ;;
    esac

    rm -rf "${dir}/unsigned_${file}"
done