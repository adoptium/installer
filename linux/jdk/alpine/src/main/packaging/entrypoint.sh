#!/usr/bin/env bash
set -euox pipefail

# Copy build scripts into a directory within the container. Avoids polluting the mounted
# directory and permission errors.
mkdir /home/builder/workspace
cp -R /home/builder/build/generated/packaging /home/builder/workspace

# Build package and set distributions it supports
cd /home/builder/workspace/packaging
abuild -r

# Copy resulting files into mounted directory where artifacts should be placed.
mv /home/builder/packages/workspace/x86_64/*.{apk,tar.gz} /home/builder/out
