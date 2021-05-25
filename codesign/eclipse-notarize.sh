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

PKG="$1"
PRIMARY_BUNDLE_ID="$2"

echo "Notarizing $1, this can take a while! Updating status every minute..."

RESPONSE=$(curl -s -X POST -F file=@${PKG} -F 'options={"primaryBundleId": "'${PRIMARY_BUNDLE_ID}'", "staple": true};type=application/json' https://cbi.eclipse.org/macos/xcrun/notarize)
    
UUID=$(echo $RESPONSE | grep -Po '"uuid"\s*:\s*"\K[^"]+')
STATUS=$(echo $RESPONSE | grep -Po '"status"\s*:\s*"\K[^"]+')

while [[ ${STATUS} == 'IN_PROGRESS' ]]; do
    sleep 1m
    RESPONSE=$(curl -s https://cbi.eclipse.org/macos/xcrun/${UUID}/status)
    STATUS=$(echo $RESPONSE | grep -Po '"status"\s*:\s*"\K[^"]+')
done

rm "${PKG}" 

if [[ ${STATUS} != 'COMPLETE' ]]; then
    echo "Notarization failed: ${RESPONSE}"
    exit 1
fi

curl -o "$1" https://cbi.eclipse.org/macos/xcrun/${UUID}/download

mv "${1}" "${WORKSPACE}/workspace/target/"
