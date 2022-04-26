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

set -eu

SIGN_OPTION=
SIGN_CMD=
NOTARIZE_OPTION=
IDENTIFIER=
VENDOR="temurin"
PACKAGE_NAME="Eclipse Temurin"
LOGO="Resources/adoptium.png"

while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "options:"
      echo "-h, --help               show brief help"
      echo "--major_version          <8,9,10,11>"
      echo "--full_version           1.8.0_192>"
      echo "-i, --input_directory    path to extracted jdk>"
      echo "-o, --output_directory   name of the pkg file>"
      echo "--jvm                    hotspot or openj9"
      echo "--architecture           x86_64 or arm64"
      echo "--type                   jdk or jre"
      echo "--vendor                 adoptium, dragonwell etc"
      echo "--package-name           full name of the package (shown in the title)"
      echo "--logo                   Relative path to a custom logo (bottom left)"
      echo "--identifier             override the identifier e.g net.adoptopenjdk.11.jdk"
      echo "-s, --sign               sign the installer>"
      exit 0
      ;;
    --major_version)
      shift
      MAJOR_VERSION=$1
      shift
      ;;
    --full_version)
      shift
      FULL_VERSION=$1
      shift
      ;;
    -i|--input_directory)
      shift
      INPUT_DIRECTORY=$1
      shift
      ;;
    -o|--output_directory)
      shift
      OUTPUT_DIRECTORY=$1
      shift
      ;;
    --jvm)
      shift
      JVM=$1
      shift
      ;;
    --architecture)
      shift
      ARCHITECTURE="$1"
      shift
      ;;
    --type)
      shift
      TYPE=$1
      shift
      ;;
    --vendor)
      shift
      VENDOR="$1"
      shift
      ;;
    --package-name)
      shift
      PACKAGE_NAME="$1"
      shift
      ;;
    --logo)
      shift
      LOGO="$1"
      shift
      ;;
    --identifier)
      shift
      IDENTIFIER="$1"
      shift
      ;;
    -s|--sign)
      shift
      SIGN_OPTION="true"
      SIGN_CERT="$1"
      NOTARIZE_OPTION="true"
      shift
      ;;
    *)
      break
      ;;
  esac
done

# Ensures that ARCHITECTURE is valid to avoid incorrectly compiled PKGs
case $ARCHITECTURE in
  x86_64) ;;
  arm64) ;;
  *)
    echo "Unknown architecture: $ARCHITECTURE"
    exit 1
    ;;
esac

case $JVM in
  openj9)
    if [ -z "$IDENTIFIER" ]; then
      IDENTIFIER="net.${VENDOR}.${MAJOR_VERSION}-openj9.${TYPE}"
    fi
    DIRECTORY="${VENDOR}-${MAJOR_VERSION}-openj9.${TYPE}"
    BUNDLE="${PACKAGE_NAME} (OpenJ9)"
    cp Licenses/license-OpenJ9.en-us.rtf Resources/license.rtf
    case $TYPE in
      jre) BUNDLE="${PACKAGE_NAME} (OpenJ9, JRE)" ;;
      jdk) BUNDLE="${PACKAGE_NAME} (OpenJ9)" ;;
    esac
    ;;
  *)
    if [ -z "$IDENTIFIER" ]; then
      IDENTIFIER="net.${VENDOR}.${MAJOR_VERSION}.${TYPE}"
    fi
    DIRECTORY="${VENDOR}-${MAJOR_VERSION}.${TYPE}"
    cp Licenses/license-GPLv2+CE.en-us.rtf Resources/license.rtf
    case $TYPE in
      jre) BUNDLE="${PACKAGE_NAME} (JRE)" ;;
      jdk) BUNDLE="${PACKAGE_NAME}" ;;
    esac
    ;;
esac

OUTPUT_FILE=$(basename "$OUTPUT_DIRECTORY" | cut -f 1 -d '.')

rm -rf *.pkg build/*.pkg distribution.xml Resources/en.lproj/welcome.html Resources/en.lproj/conclusion.html OpenJDKPKG.pkgproj "${DIRECTORY}"

cp -R "${INPUT_DIRECTORY}" "${DIRECTORY}"

if [ ! -z "$SIGN_OPTION" ]; then
    xattr -cr .
    security unlock-keychain -p `cat ~/.password` login.keychain-db
    /usr/bin/codesign --verbose=4 --deep --force -s - ${DIRECTORY}
fi

cat OpenJDKPKG.pkgproj.template  \
  | sed -E "s~\\{path\\}~$DIRECTORY~g" \
  | sed -E "s~\\{output\\}~$OUTPUT_FILE~g" \
  | sed -E "s~\\{identifier\\}~$IDENTIFIER~g" \
  | sed -E "s~\\{package-name\\}~$PACKAGE_NAME~g" \
  | sed -E "s~\\{directory\\}~$DIRECTORY~g" \
  | sed -E "s~\\{logo\\}~$LOGO~g" \
  | sed -E "s~\\{arch\\}~$ARCHITECTURE~g" \
  | sed -E "s~\\{full-version\\}~$FULL_VERSION~g" \
  >OpenJDKPKG.pkgproj ; \

  cat Resources/en.lproj/welcome.html.tmpl  \
  | sed -E "s/\\{full_version\\}/$FULL_VERSION/g" \
  | sed -E "s/\\{directory\\}/$DIRECTORY/g" \
  | sed -E "s~\\{package-name\\}~$PACKAGE_NAME~g" \
  >Resources/introduction.html ; \

  cat Resources/en.lproj/conclusion.html.tmpl  \
  | sed -E "s/\\{full_version\\}/$FULL_VERSION/g" \
  | sed -E "s/\\{directory\\}/$DIRECTORY/g" \
  | sed -E "s~\\{package-name\\}~$PACKAGE_NAME~g" \
  >Resources/summary.html ; \

/usr/local/bin/packagesbuild -v OpenJDKPKG.pkgproj

if [ ! -z "$SIGN_OPTION" ]; then
    /usr/bin/productsign --sign "${SIGN_CERT}" build/"$OUTPUT_FILE.pkg" "$OUTPUT_DIRECTORY"
else
    mv build/"$OUTPUT_FILE.pkg" "$OUTPUT_DIRECTORY"
fi

if [ ! -z "$NOTARIZE_OPTION" ]; then
  echo "Notarizing the installer (please be patient! this takes aprox 10 minutes)"
  sudo xcode-select --switch /Applications/Xcode.app || true
  cd notarize
  npm install
  node notarize.js --appBundleId $IDENTIFIER --appPath ${OUTPUT_DIRECTORY}
  if [ $? != 0 ]; then
    exit 1
  fi
  # Validates that the app has been notarized
  spctl -a -v --type install ${OUTPUT_DIRECTORY}
  cd -
fi
