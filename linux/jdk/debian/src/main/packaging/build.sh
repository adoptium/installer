#!/usr/bin/env bash
set -euxo pipefail

# Copy build scripts into a directory within the container. Avoids polluting the mounted
# directory and permission errors.
mkdir /home/builder/workspace
cp -R /home/builder/build/generated/packaging /home/builder/workspace


# $ and $ARCH are env variables passing in from "docker run"
debVersionList="buster bullseye bionic focal jammy"
dpkgExtraARG="-us -uc" # ignore building with a gpg key

echo "DEBUG: building Debian arch ${buildArch}"
if [[ "${buildArch}" == "all" ]]; then
    dpkgExtraARG="${dpkgExtraARG} -b" # equal to --build=any,all|--build=binary
else
    dpkgExtraARG="${dpkgExtraARG} --build=any"
fi

# Build package and set distributions it supports
cd /home/builder/workspace/packaging
dpkg-buildpackage ${dpkgExtraARG}
changestool /home/builder/workspace/*.changes setdistribution ${debVersionList}

# Copy resulting files into mounted directory where artifacts should be placed.
mv /home/builder/workspace/*.{deb,changes,buildinfo} /home/builder/out
