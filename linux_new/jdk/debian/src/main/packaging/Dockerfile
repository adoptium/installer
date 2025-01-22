ARG CONTAINER_REGISTRY=""
ARG IMAGE=debian:bullseye
FROM ${CONTAINER_REGISTRY}${IMAGE}

# Combine apt-get update with apt-get install to prevent stale package indexes.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential \
		debhelper \
		lsb-release \
		reprepro \
		gosu \
		java-common \
		libasound2 \
		libc6 \
		libx11-6 \
		libfontconfig1 \
		libfreetype6 \
		libxext6 \
		libxi6 \
		libxrender1 \
		libxtst6 \
		zlib1g \
		tini \
		wget

# Create unprivileged user for building, see
# https://github.com/hexops/dockerfile#use-a-static-uid-and-gid
RUN groupadd -g 10001 builder \
	&& useradd -m -d /home/builder -u 10000 -g 10001 builder

# Prepare entrypoint and build scripts
ADD entrypoint.sh /entrypoint.sh
ADD build.sh /home/builder/build.sh
RUN chmod +x /home/builder/build.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/bin/bash", "/entrypoint.sh" ]
