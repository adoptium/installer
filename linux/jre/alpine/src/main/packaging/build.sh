#!/usr/bin/env bash
set -euxo pipefail

# Copy build scripts into a directory within the container. Avoids polluting the mounted
# directory and permission errors.
mkdir /home/builder/workspace
cp -R /home/builder/build/generated/packaging /home/builder/workspace

# Build package and set distributions it supports
cd /home/builder/workspace/packaging
abuild -r

arch=$(abuild -A)

# Copy resulting files into mounted directory where artifacts should be placed.
mv /home/builder/packages/workspace/$arch/*.{apk,tar.gz} /home/builder/out
