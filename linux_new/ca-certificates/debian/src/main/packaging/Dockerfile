ARG CONTAINER_REGISTRY=""

FROM ${CONTAINER_REGISTRY}debian:bullseye

# Combine apt-get update with apt-get install to prevent stale package indexes.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential \
 		debhelper lsb-release reprepro gosu tini

# Create unprivileged user for building, see
# https://github.com/hexops/dockerfile#use-a-static-uid-and-gid
RUN groupadd -g 10001 builder \
	&& useradd -m -d /home/builder -u 10000 -g 10001 builder

# Prepare entrypoint and build scripts
ADD entrypoint.sh /entrypoint.sh
ADD build.sh /home/builder/build.sh
RUN chmod +x /home/builder/build.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/bin/bash", "/entrypoint.sh" ]
