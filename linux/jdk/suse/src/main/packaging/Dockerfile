ARG CONTAINER_REGISTRY=""

FROM ${CONTAINER_REGISTRY}tianon/gosu as gosu
FROM ${CONTAINER_REGISTRY}opensuse/leap:15.6

RUN zypper update -y && zypper install -y rpm-build \
	rpm-devel \
	rpmdevtools \
	rpmlint \
	dirmngr \
	tar \
	dpkg \
	findutils \
	tini \
	wget

COPY --from=gosu /gosu /usr/local/bin/

# Create unprivileged user for building, see
# https://github.com/hexops/dockerfile#use-a-static-uid-and-gid
RUN groupadd -g 10001 builder \
	&& useradd -m -d /home/builder -u 10000 -g 10001 builder

# Add GPG key
USER builder
RUN --mount=type=secret,id=gpg,gid=10001,uid=10000,dst=/tmp/private.gpg \
	if [[ -f /tmp/private.gpg ]]; then \
		gpg --import /tmp/private.gpg; \
		printf '%%_signature gpg\n\
%%_gpg_name 3B04D753C9050D9A5D343F39843C48A565F8F04B\n\
%%__gpg /usr/bin/gpg\n\
'\
>> /home/builder/.rpmmacros; \
	fi

# Prepare entrypoint and build scripts
ADD entrypoint.sh /entrypoint.sh
ADD build.sh /home/builder/build.sh
USER root
RUN chmod +x /home/builder/build.sh

ENTRYPOINT ["/tini", "--", "/bin/bash", "/entrypoint.sh" ]
