FROM fedora:33

RUN dnf update -y && dnf install -y rpmdevtools rpmlint gnupg2 wget tar dpkg findutils

RUN wget --progress=dot:mega -O /usr/bin/gosu https://github.com/tianon/gosu/releases/download/1.12/gosu-"$(dpkg --print-architecture | awk -F- '{ print $NF }')"
RUN wget --progress=dot:mega -O /tmp/gosu.asc https://github.com/tianon/gosu/releases/download/1.12/gosu-"$(dpkg --print-architecture | awk -F- '{ print $NF }')".asc
RUN gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4
RUN gpg --batch --verify /tmp/gosu.asc /usr/bin/gosu
RUN chmod +x /usr/bin/gosu
RUN rm -f /tmp/gosu.asc

RUN wget --progress=dot:mega -O /usr/bin/tini https://github.com/krallin/tini/releases/download/v0.19.0/tini-"$(dpkg --print-architecture | awk -F- '{ print $NF }')"
RUN wget --progress=dot:mega -O /tmp/tini.asc https://github.com/krallin/tini/releases/download/v0.19.0/tini-"$(dpkg --print-architecture | awk -F- '{ print $NF }')".asc
RUN gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys 595E85A6B1B4779EA4DAAEC70B588DFF0527A9B7
RUN gpg --batch --verify /tmp/tini.asc /usr/bin/tini
RUN chmod +x /usr/bin/tini
RUN rm -f /tmp/tini.asc

# Create unprivileged user for building, see
# https://github.com/hexops/dockerfile#use-a-static-uid-and-gid
RUN groupadd -g 10001 builder
RUN useradd -m -d /home/builder -u 10000 -g 10001 builder

# Prepare entrypoint and build scripts
ADD entrypoint.sh /entrypoint.sh
RUN printf '#!/usr/bin/env bash\n\
set -euxo pipefail\n\
\n\
# Ensure necessary directories for rpmbuild operation are present.\n\
rpmdev-setuptree \n\
\n\
# Build all spec files we can find.\n\
for spec in "$(ls /home/builder/build/generated/packaging/*.spec)"; do\n\
	spectool -g -R "$spec";\n\
	rpmbuild -bb "$spec";\n\
done;\n\
\n\
# Copy generated RPMs to destination folder\n\
find /home/builder/rpmbuild/RPMS -type f -name "*.rpm" -print0 | xargs -0 -I {} cp {} /home/builder/out\n\
'\
>> /home/builder/build.sh
RUN chmod +x /home/builder/build.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/bin/bash", "/entrypoint.sh" ]
