ARG CONTAINER_REGISTRY=""

FROM ${CONTAINER_REGISTRY}alpine:3.19
ENV GOSU_VERSION 1.14

RUN set -eux; \
	\
	apk add \
		alpine-sdk \
		bash \
		ca-certificates \
		doas \
		dpkg \
		sudo \
		wget

# Create unprivileged user for building, see
# https://github.com/hexops/dockerfile#use-a-static-uid-and-gid
RUN adduser -D -h /home/builder builder \
    && addgroup builder abuild \
    && echo 'builder ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers \
    && echo 'permit builder as root' > /etc/doas.d/doas.conf

# Add GPG key
USER builder
WORKDIR /home/builder
RUN --mount=type=secret,id=gpg,gid=1000,uid=1000,dst=/tmp/private.rsa \
	if [[ -f /tmp/private.rsa ]]; then \
		mkdir /home/builder/.abuild; \
		cp /tmp/private.rsa /home/builder/.abuild; \
		printf 'PACKAGER_PRIVKEY=/home/builder/.abuild/private.rsa'\
>> /home/builder/.abuild/abuild.conf; \
		wget -o /home/builder/.abuild/private.rsa.pub https://packages.adoptium.net/artifactory/api/security/keypair/public/repositories/apk; \
	else \
		abuild-keygen -a -n; \
		sudo cp /home/builder/.abuild/*.rsa.pub /etc/apk/keys/; \
	fi

# Prepare entrypoint
COPY --chown=builder:abuild entrypoint.sh /home/builder/entrypoint.sh
RUN chmod +x /home/builder/entrypoint.sh

ENTRYPOINT ["/home/builder/entrypoint.sh"]
