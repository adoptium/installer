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

rm -rf *.pkg distribution.xml
mkdir -p "${INPUT_DIRECTORY}/Contents/Home/bundle/Libraries"
ln -nsf "${INPUT_DIRECTORY}/Contents/Home/lib/server/libjvm.dylib" "${INPUT_DIRECTORY}/Contents/Home/bundle/Libraries/libserver.dylib"

# Plist commands:
/usr/libexec/PlistBuddy -c "Set :CFBundleGetInfoString AdoptOpenJDK ${FULL_VERSION}" "${INPUT_DIRECTORY}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier net.adoptopenjdk.${MAJOR_VERSION}.jdk" "${INPUT_DIRECTORY}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName AdoptOpenJDK ${MAJOR_VERSION}" "${INPUT_DIRECTORY}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :JavaVM:JVMPlatformVersion ${FULL_VERSION}" "${INPUT_DIRECTORY}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :JavaVM:JVMVendor AdoptOpenJDK" "${INPUT_DIRECTORY}/Contents/Info.plist"

cat distribution.xml.tmpl  \
  | sed -E "s/\\{major_version\\}/$MAJOR_VERSION/g" \
  | sed -E "s/\\{full_version\\}/$FULL_VERSION/g" \
  | sed -E "s/\\{file\\}/OpenJDK.pkg/g" \
  >distribution.xml ; \

/usr/bin/pkgbuild --root ${INPUT_DIRECTORY} --install-location /Library/Java/JavaVirtualMachines/adoptopenjdk-${MAJOR_VERSION}.jdk --identifier net.adoptopenjdk.${MAJOR_VERSION}.jdk --version ${FULL_VERSION} --sign "${SIGN}" OpenJDK.pkg
/usr/bin/productbuild --distribution distribution.xml --resources Resources  --sign "${SIGN}" --package-path OpenJDK.pkg ${OUTPUT_DIRECTORY}


rm -rf OpenJDK.pkg
