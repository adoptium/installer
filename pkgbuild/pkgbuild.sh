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

while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "options:"
      echo "-h, --help               show brief help"
      echo "--major_version          <8,9,10,11>"
      echo "--full_version           1.8.0_192>"
      echo "-i, --input_directory    path to extracted jdk>"
      echo "-o, --output_directory   name of the pkg file>"
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
    -s|--sign)
      shift
      SIGN="$1"
      shift
      ;;
    *)
      break
      ;;
  esac
done

rm -rf *.pkg distribution.xml Resources/en.lproj/welcome.html Resources/en.lproj/conclusion.html
mkdir -p "${INPUT_DIRECTORY}/Contents/Home/bundle/Libraries"
ln -nsf "${INPUT_DIRECTORY}/Contents/Home/lib/server/libjvm.dylib" "${INPUT_DIRECTORY}/Contents/Home/bundle/Libraries/libserver.dylib"

# Detect if JRE or JDK
case $INPUT_DIRECTORY in
  *-jre)
    TYPE="jre"
    ;;
  *)
    TYPE="jdk"
    ;;
esac
    
# Plist commands:
case $JVM in
  openj9)
    IDENTIFIER="net.adoptopenjdk.${MAJOR_VERSION}-openj9.${TYPE}"
    DIRECTORY="adoptopenjdk-${MAJOR_VERSION}-openj9.${TYPE}"
    /usr/libexec/PlistBuddy -c "Set :CFBundleGetInfoString AdoptOpenJDK (OpenJ9) ${FULL_VERSION}" "${INPUT_DIRECTORY}/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName AdoptOpenJDK (OpenJ9) ${MAJOR_VERSION}" "${INPUT_DIRECTORY}/Contents/Info.plist"
    ;;
  *)
    IDENTIFIER="net.adoptopenjdk.${MAJOR_VERSION}.${TYPE}"
    DIRECTORY="adoptopenjdk-${MAJOR_VERSION}.${TYPE}"
    /usr/libexec/PlistBuddy -c "Set :CFBundleGetInfoString AdoptOpenJDK ${FULL_VERSION}" "${INPUT_DIRECTORY}/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName AdoptOpenJDK ${MAJOR_VERSION}" "${INPUT_DIRECTORY}/Contents/Info.plist"
    ;;
esac
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${IDENTIFIER}" "${INPUT_DIRECTORY}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :JavaVM:JVMPlatformVersion ${FULL_VERSION}" "${INPUT_DIRECTORY}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :JavaVM:JVMVendor AdoptOpenJDK" "${INPUT_DIRECTORY}/Contents/Info.plist"

cat distribution.xml.tmpl  \
  | sed -E "s/\\{major_version\\}/$MAJOR_VERSION/g" \
  | sed -E "s/\\{full_version\\}/$FULL_VERSION/g" \
  | sed -E "s/\\{file\\}/OpenJDK.pkg/g" \
  >distribution.xml ; \

  cat Resources/en.lproj/welcome.html.tmpl  \
  | sed -E "s/\\{major_version\\}/$MAJOR_VERSION/g" \
  | sed -E "s/\\{full_version\\}/$FULL_VERSION/g" \
  >Resources/en.lproj/welcome.html ; \

  cat Resources/en.lproj/conclusion.html.tmpl  \
  | sed -E "s/\\{major_version\\}/$MAJOR_VERSION/g" \
  | sed -E "s/\\{full_version\\}/$FULL_VERSION/g" \
  >Resources/en.lproj/conclusion.html ; \

/usr/bin/pkgbuild --root ${INPUT_DIRECTORY} --install-location /Library/Java/JavaVirtualMachines/${DIRECTORY} --identifier ${IDENTIFIER} --version ${FULL_VERSION} --sign "${SIGN}" OpenJDK.pkg
/usr/bin/productbuild --distribution distribution.xml --resources Resources --sign "${SIGN}" --package-path OpenJDK.pkg ${OUTPUT_DIRECTORY}

rm -rf OpenJDK.pkg
