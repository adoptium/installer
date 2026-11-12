#!/usr/bin/env bash

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
umask 022

SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)
MAJOR_VERSION=
FULL_VERSION=
INPUT_DIRECTORY=
OUTPUT_DIRECTORY=
JVM=
ARCHITECTURE=
TYPE=
IDENTIFIER=
VENDOR="temurin"
PACKAGE_NAME="Eclipse Temurin"
LOGO="${SCRIPT_DIRECTORY}/Resources/adoptium.png"

fail() {
  echo "Error: $*" >&2
  exit 1
}

while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "options:"
      echo "-h, --help               show brief help"
      echo "--major_version          Java feature version, e.g. 17"
      echo "--full_version           17.0.3+7"
      echo "-i, --input_directory    path to extracted jdk"
      echo "-o, --output_directory   name of the pkg file"
      echo "--jvm                    hotspot or openj9"
      echo "--architecture           x86_64 or arm64"
      echo "--type                   jdk or jre"
      echo "--vendor                 adoptium, dragonwell etc"
      echo "--package-name           full name of the package (shown in the title)"
      echo "--logo                   Path to a custom logo (bottom left)"
      echo "--identifier             override the identifier e.g net.adoptopenjdk.17.jdk"
      echo "Produces an unsigned package for the Eclipse signing service."
      exit 0
      ;;
    --major_version|--full_version|-i|--input_directory|-o|--output_directory|--jvm|--architecture|--type|--vendor|--package-name|--logo|--identifier)
      [ "$#" -ge 2 ] && [ -n "$2" ] || fail "Missing value for $1"
      case "$1" in
        --major_version) MAJOR_VERSION=$2 ;;
        --full_version) FULL_VERSION=$2 ;;
        -i|--input_directory) INPUT_DIRECTORY=$2 ;;
        -o|--output_directory) OUTPUT_DIRECTORY=$2 ;;
        --jvm) JVM=$2 ;;
        --architecture) ARCHITECTURE=$2 ;;
        --type) TYPE=$2 ;;
        --vendor) VENDOR=$2 ;;
        --package-name) PACKAGE_NAME=$2 ;;
        --logo) LOGO=$2 ;;
        --identifier) IDENTIFIER=$2 ;;
      esac
      shift 2
      ;;
    -s|--sign)
      fail "Local signing is no longer supported. Use codesign/eclipse-codesign.sh after building."
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
done

[[ "$MAJOR_VERSION" =~ ^[1-9][0-9]*$ ]] || fail "A numeric --major_version is required"
[[ "$FULL_VERSION" =~ ^[0-9][A-Za-z0-9.+_-]*$ ]] || fail "A valid --full_version is required"
[[ "$VENDOR" != *[!A-Za-z0-9._-]* ]] || fail "Invalid vendor: $VENDOR"
[ -n "$INPUT_DIRECTORY" ] && [ -d "${INPUT_DIRECTORY}/Contents" ] && [ -f "${INPUT_DIRECTORY}/Contents/Info.plist" ] \
  || fail "--input_directory must contain a macOS JDK or JRE bundle (Contents/Info.plist)"
[ -n "$OUTPUT_DIRECTORY" ] || fail "--output_directory is required"
[ -f "$LOGO" ] || fail "Logo not found: $LOGO"

case $ARCHITECTURE in
  x86_64|arm64) ;;
  *) fail "Unknown architecture: $ARCHITECTURE" ;;
esac

case $TYPE in
  jdk|jre) ;;
  *) fail "Unknown package type: $TYPE" ;;
esac

case $JVM in
  openj9)
    if [ -z "$IDENTIFIER" ]; then
      IDENTIFIER="net.${VENDOR}.${MAJOR_VERSION}-openj9.${TYPE}"
    fi
    DIRECTORY="${VENDOR}-${MAJOR_VERSION}-openj9.${TYPE}"
    LICENSE="license-OpenJ9.en-us.rtf"
    ;;
  hotspot)
    if [ -z "$IDENTIFIER" ]; then
      IDENTIFIER="net.${VENDOR}.${MAJOR_VERSION}.${TYPE}"
    fi
    DIRECTORY="${VENDOR}-${MAJOR_VERSION}.${TYPE}"
    LICENSE="license-GPLv2+CE.en-us.rtf"
    ;;
  *) fail "Unknown JVM: $JVM" ;;
esac

[[ "$IDENTIFIER" != *[!A-Za-z0-9._-]* ]] || fail "Invalid identifier: $IDENTIFIER"

WORK_DIRECTORY=$(mktemp -d "${TMPDIR:-/tmp}/temurin-pkg.XXXXXX")
readonly WORK_DIRECTORY
trap 'rm -rf "$WORK_DIRECTORY"' EXIT

PAYLOAD_DIRECTORY="${WORK_DIRECTORY}/root/Library/Java/JavaVirtualMachines"
RESOURCE_DIRECTORY="${WORK_DIRECTORY}/Resources"
mkdir -p "$PAYLOAD_DIRECTORY" "$RESOURCE_DIRECTORY/en.lproj" "${WORK_DIRECTORY}/scripts"
ditto --norsrc --noextattr --noqtn "$INPUT_DIRECTORY" "${PAYLOAD_DIRECTORY}/${DIRECTORY}"
chmod 755 "${PAYLOAD_DIRECTORY}/${DIRECTORY}"
cp "${SCRIPT_DIRECTORY}/Resources/preinstall" "${WORK_DIRECTORY}/scripts/preinstall"
chmod 755 "${WORK_DIRECTORY}/scripts/preinstall"
cp "${SCRIPT_DIRECTORY}/Licenses/${LICENSE}" "${RESOURCE_DIRECTORY}/en.lproj/license.rtf"
LOGO_FILE=$(basename "$LOGO")
cp "$LOGO" "${RESOURCE_DIRECTORY}/${LOGO_FILE}"

escape_template_value() {
  printf '%s' "$1" | sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g' \
    -e "s/'/\\&apos;/g" \
    -e 's/[\\&|]/\\&/g'
}

XML_PACKAGE_NAME=$(escape_template_value "$PACKAGE_NAME")
XML_DIRECTORY=$(escape_template_value "$DIRECTORY")
XML_IDENTIFIER=$(escape_template_value "$IDENTIFIER")
XML_FULL_VERSION=$(escape_template_value "$FULL_VERSION")
XML_LOGO_FILE=$(escape_template_value "$LOGO_FILE")

render_template() {
  sed \
    -e "s|{package-name}|$XML_PACKAGE_NAME|g" \
    -e "s|{directory}|$XML_DIRECTORY|g" \
    -e "s|{identifier}|$XML_IDENTIFIER|g" \
    -e "s|{full_version}|$XML_FULL_VERSION|g" \
    -e "s|{logo}|$XML_LOGO_FILE|g" \
    -e "s|{arch}|$ARCHITECTURE|g" \
    "$1" > "$2"
}

render_template "${SCRIPT_DIRECTORY}/distribution.xml.template" "${WORK_DIRECTORY}/Distribution"
render_template "${SCRIPT_DIRECTORY}/components.plist.template" "${WORK_DIRECTORY}/components.plist"
render_template "${SCRIPT_DIRECTORY}/Resources/en.lproj/welcome.html.tmpl" "${RESOURCE_DIRECTORY}/en.lproj/welcome.html"
render_template "${SCRIPT_DIRECTORY}/Resources/en.lproj/conclusion.html.tmpl" "${RESOURCE_DIRECTORY}/en.lproj/conclusion.html"

pkgbuild \
  --root "${WORK_DIRECTORY}/root" \
  --component-plist "${WORK_DIRECTORY}/components.plist" \
  --identifier "$IDENTIFIER" \
  --version "$FULL_VERSION" \
  --install-location / \
  --ownership recommended \
  --scripts "${WORK_DIRECTORY}/scripts" \
  --filter '(^|/)(\._[^/]*|\.DS_Store|\.pbdevelopment|CVS|\.cvsignore|\.cvspass|\.svn|\.git|\.gitignore|Resources Disabled)(/|$)|\.nib/(classes\.nib|designable\.db|info\.nib)$' \
  "${WORK_DIRECTORY}/component.pkg"

# pkgbuild otherwise resets permissions on pre-existing shared directories.
pkgutil --expand "${WORK_DIRECTORY}/component.pkg" "${WORK_DIRECTORY}/component"
sed 's/overwrite-permissions="true"/overwrite-permissions="false"/' \
  "${WORK_DIRECTORY}/component/PackageInfo" > "${WORK_DIRECTORY}/PackageInfo"
[ "$(xmllint --xpath 'string(/pkg-info/@overwrite-permissions)' "${WORK_DIRECTORY}/PackageInfo")" = false ] \
  || fail "Could not preserve existing directory permissions in PackageInfo"
mv "${WORK_DIRECTORY}/PackageInfo" "${WORK_DIRECTORY}/component/PackageInfo"
pkgutil --flatten "${WORK_DIRECTORY}/component" "${WORK_DIRECTORY}/payload.pkg"

productbuild \
  --distribution "${WORK_DIRECTORY}/Distribution" \
  --resources "$RESOURCE_DIRECTORY" \
  --package-path "$WORK_DIRECTORY" \
  "${WORK_DIRECTORY}/product.pkg"

mkdir -p "$(dirname "$OUTPUT_DIRECTORY")"
mv "${WORK_DIRECTORY}/product.pkg" "$OUTPUT_DIRECTORY"
echo "Created unsigned installer: $OUTPUT_DIRECTORY"
