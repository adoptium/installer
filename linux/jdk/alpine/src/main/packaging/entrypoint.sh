#!/usr/bin/env bash
set -euox pipefail

# Copy build scripts into a directory within the container. Avoids polluting the mounted
# directory and permission errors.
mkdir /home/builder/workspace
cp -R /home/builder/build/generated/packaging /home/builder/workspace

# Install Adoptium Public Key
sudo chmod 664 /etc/apk/repositories
sudo chgrp abuild /etc/apk/repositories
sudo chmod 775 /etc/apk/keys
sudo wget -O /etc/apk/keys/adoptium.rsa.pub https://packages.adoptium.net/artifactory/api/security/keypair/public/repositories/apk
sudo echo 'https://packages.adoptium.net/artifactory/apk/alpine/main' >> /etc/apk/repositories
sudo wget -O /home/builder/.abuild/adoptium.rsa.pub https://packages.adoptium.net/artifactory/api/security/keypair/public/repositories/apk
ls -ltr /etc/apk/keys

# Set permssions
sudo chown -R builder /home/builder/out

# Build package and set distributions it supports
cd /home/builder/workspace/packaging
sudo apk update
abuild -r

arch=$(abuild -A)

# Copy resulting files into mounted directory where artifacts should be placed.
mv /home/builder/packages/workspace/$arch/*.{apk,tar.gz} /home/builder/out
