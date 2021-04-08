#!/bin/bash
# Simple script to run a local RPM build including
# download of binary blobs.
#
# Examples:
#
#   bash $(pwd)/run_build.sh $(pwd)/8/java-1.8.0-openj9.spec
#
#   bash $(pwd)/run_build.sh $(pwd)/11/java-11-openj9.spec
set -exv

if [ $# -ne 1 ]; then
  echo "Usage: $0 <path/to/specfile.spec>"
  exit 1
fi
mytmpdir=$(mktemp -d)

spec=$1
pushd $mytmpdir
spectool --gf ${spec}
# work-around issue of wrong filename in sha256 file
sed -i 's/OpenJDK11U/OpenJDK11u/g' *.sha256.txt
rpmbuild --define "_sourcedir $(pwd)" --define "_specdir $(pwd)" \
         --define "_builddir $(pwd)" --define "_srcrpmdir $(pwd)" \
         --define "_rpmdir $(pwd)" --nodeps -bs ${spec}
rpmbuild --define "_sourcedir $(pwd)" --define "_specdir $(pwd)" \
         --define "_builddir $(pwd)" --define "_srcrpmdir $(pwd)" \
         --define "_rpmdir $(pwd)" --rebuild *.src.rpm
popd

echo "Results in $mytmpdir"
