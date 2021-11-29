FROM opensuse/leap:15.2

RUN zypper update -y && zypper install -y rpm-build rpm-devel rpmdevtools rpmlint gpg2 wget tar dpkg findutils tini

RUN wget --progress=dot:mega -O /usr/bin/gosu https://github.com/tianon/gosu/releases/download/1.12/gosu-"$(dpkg --print-architecture | awk -F- '{ print $NF }')"
RUN wget --progress=dot:mega -O /tmp/gosu.asc https://github.com/tianon/gosu/releases/download/1.12/gosu-"$(dpkg --print-architecture | awk -F- '{ print $NF }')".asc
RUN gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4
RUN gpg --batch --verify /tmp/gosu.asc /usr/bin/gosu
RUN chmod +x /usr/bin/gosu
RUN rm -f /tmp/gosu.asc

# Create unprivileged user for building, see
# https://github.com/hexops/dockerfile#use-a-static-uid-and-gid
RUN groupadd -g 10001 builder
RUN useradd -m -d /home/builder -u 10000 -g 10001 builder

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
USER root

# Prepare entrypoint and build scripts
ADD entrypoint.sh /entrypoint.sh
RUN printf '#!/usr/bin/env bash\n\
set -euxo pipefail\n\
\n\
# Ensure necessary directories for rpmbuild operation are present.\n\
rpmdev-setuptree \n\
\n\
# Build all spec files we can find.\n\

targets="x86_64 ppc64le s390x aarch64 armv7l" \n\
for spec in "$(ls /home/builder/build/generated/packaging/*.spec)"; do\n\
	rpmdev-spectool -g -R "$spec";\n\
	rpmbuild --nodeps -bs "$spec"; \n\
	if [[ "$spec" =~ "temurin-8-jdk" ]]; then \n\
		targets="x86_64 ppc64le aarch64" \n\
	fi \n\
	for target in $targets; do \n\
		rpmbuild --target "$target" --rebuild /home/builder/rpmbuild/SRPMS/*.src.rpm;\n\
	done;\n\
done;\n\
\n\
# Copy generated RPMs to destination folder\n\
find /home/builder/rpmbuild/SRPMS /home/builder/rpmbuild/RPMS -type f -name "*.rpm" -print0 | xargs -0 -I {} cp {} /home/builder/out\n\
# Sign generated RPMs with rpmsign.\n\
if grep -q %%_gpg_name /home/builder/.rpmmacros; then \n\
	rpmsign --addsign /home/builder/out/*.rpm \n\
fi;\n\
'\
>> /home/builder/build.sh
RUN chmod +x /home/builder/build.sh

ENTRYPOINT ["/tini", "--", "/bin/bash", "/entrypoint.sh" ]
