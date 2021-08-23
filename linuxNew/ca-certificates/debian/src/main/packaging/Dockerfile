FROM debian:buster

# Combine apt-get update with apt-get install to prevent stale package indexes.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential \
 		debhelper sudo lsb-release reprepro gosu tini

# Create unprivileged user for building, see
# https://github.com/hexops/dockerfile#use-a-static-uid-and-gid
RUN groupadd -g 10001 builder
RUN useradd -m -d /home/builder -u 10000 -g 10001 builder

# Prepare entrypoint and build scripts
ADD entrypoint.sh /entrypoint.sh
RUN printf '#!/usr/bin/env bash\n\
set -euxo pipefail\n\
\n\
# Copy build scripts into a directory within the container. Avoids polluting the mounted\n\
# directory and permission errors.\n\
mkdir /home/builder/workspace\n\
cp -R /home/builder/build/generated/packaging /home/builder/workspace\n\
\n\
# Build package and set distributions it supports.\n\
cd /home/builder/workspace/packaging\n\
dpkg-buildpackage -us -uc -b\n\
changestool /home/builder/workspace/*.changes setdistribution $VERSIONS\n\
\n\
# Copy resulting files into mounted directory where artifacts should be placed.\n\
mv /home/builder/workspace/*.{deb,changes,buildinfo} /home/builder/out\n\
'\
>> /home/builder/build.sh
RUN chmod +x /home/builder/build.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/bin/bash", "/entrypoint.sh" ]
