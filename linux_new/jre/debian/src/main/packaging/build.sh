#!/usr/bin/env bash
set -euxo pipefail

# Copy build scripts into a directory within the container. Avoids polluting the mounted
# directory and permission errors.
mkdir /home/builder/workspace
cp -R /home/builder/build/generated/packaging /home/builder/workspace

if [ "$buildLocalFlag" == "true" ]; then
	# Copy sha256sum.txt file into SOURCE directory
	# It is worth noting that DEB will only ever build 1 package at a time
	for sha in $(ls /home/builder/build/jre/*.sha256*.txt); do
		cp $sha /home/builder/workspace/packaging/jre.tar.gz.sha256.txt
	done;
	# Copy source tar file into SOURCE directory
	for jre in $(ls /home/builder/build/jre/*.tar.gz); do
		cp $jre /home/builder/workspace/packaging/jre.tar.gz

		# Change name of *.tar.gz in .sha256sum.txt contents to match new name (jre.tar.gz)
		# Example:
		# f579751fdcd627552a550e37ee00f8ff7a04e53bb385154ac17a0fb1fbb6ed12  <vendor>-jre-17.0.7-linux-x64.tar.gz
		# To
		# f579751fdcd627552a550e37ee00f8ff7a04e53bb385154ac17a0fb1fbb6ed12  jre.tar.gz
		sed -i "s/$(basename $jre)/jre.tar.gz/" /home/builder/workspace/packaging/jre.tar.gz.sha256.txt

	done;
fi

# $ and $ARCH are env variables passing in from "docker run"
debVersionList="trixie bookworm bullseye buster oracular noble jammy focal bionic"

# the target package is only based on the host machine's ARCH
# ${buildArch} is only used for debug purpose what really matter is the label on the jenkins agent
echo "DEBUG: building Debian arch ${buildArch}"

# Build package and set distributions it supports
cd /home/builder/workspace/packaging
dpkg-buildpackage -us -uc -b
changestool /home/builder/workspace/*.changes setdistribution ${debVersionList}

# Copy resulting files into mounted directory where artifacts should be placed.
mv /home/builder/workspace/*.{deb,changes,buildinfo} /home/builder/out
