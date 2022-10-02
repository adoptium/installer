FROM alpine
ENV GOSU_VERSION 1.14

RUN set -eux; \
	\
	apk add \
		alpine-sdk \
		bash \
		ca-certificates \
		dpkg \
		gnupg \
		tini \
	; \
	\
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	\
# verify the signature
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	command -v gpgconf && gpgconf --kill all || :; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	chmod +x /usr/local/bin/gosu; \
# verify that the binary works
	gosu --version; \
	gosu nobody true

# Create unprivileged user for building, see
# https://github.com/hexops/dockerfile#use-a-static-uid-and-gid
RUN adduser -D -h /home/builder -u 10000 builder
RUN addgroup builder abuild

# Add GPG key
USER builder
RUN --mount=type=secret,id=gpg,gid=10001,uid=10000,dst=/tmp/private.rsa \
	if [[ -f /tmp/private.rsa ]]; then \
		mkdir /home/builder/.abuild; \
		cp /tmp/private.rsa /home/builder/.abuild; \
		printf 'PACKAGER_PRIVKEY=/home/builder/.abuild/private.rsa'\
>> /home/builder/.abuild/abuild.conf; \
	else \
		abuild-keygen -a -n; \
	fi

# Prepare entrypoint and build scripts
ADD entrypoint.sh /entrypoint.sh
ADD build.sh /home/builder/build.sh
USER root
RUN chmod +x /home/builder/build.sh

ENTRYPOINT ["/sbin/tini", "--", "/bin/bash", "/entrypoint.sh" ]
