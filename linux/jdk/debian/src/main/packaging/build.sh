#!/usr/bin/env bash
set -euxo pipefail

# Copy build scripts into a directory within the container. Avoids polluting the mounted
# directory and permission errors.
mkdir /home/builder/workspace
cp -R /home/builder/build/generated/packaging /home/builder/workspace


# $ and $ARCH are env variables passing in from "docker run"
debVersionList="buster bullseye bionic focal jammy kinetic"

# the target package is only based on the host machine's ARCH
# ${buildArch} is only used for debug purpose what really matter is the label on the jenkins agent
echo "DEBUG: building Debian arch ${buildArch}"

# Build package and set distributions it supports
cd /home/builder/workspace/packaging
dpkg-buildpackage -us -uc -b
changestool /home/builder/workspace/*.changes setdistribution ${debVersionList}

# Copy resulting files into mounted directory where artifacts should be placed.
mv /home/builder/workspace/*.{deb,changes,buildinfo} /home/builder/out
