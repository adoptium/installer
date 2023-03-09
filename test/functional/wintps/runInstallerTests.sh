#!/usr/bin/env bash
#
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

set -x
set -eo pipefail

mkdir input

export RESULTS_FOLDER=$1/result
export INPUT_FOLDER="$(pwd)/input"
export JDK_VERSION=$2
export MSI_VENDOR="Adoptium"
export CURRENT_USER_NAME='jenkins'

echo "Fetch the MSI file"
curl -OLJSks "https://api.adoptium.net/v3/installer/latest/$JDK_VERSION/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk"
mv *.msi $INPUT_FOLDER/
ls $INPUT_FOLDER
./WindowsTPS/wrapper/run-tps-win-vagrant.sh
