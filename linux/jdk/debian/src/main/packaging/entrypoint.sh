#!/usr/bin/env bash
set -euox pipefail

# The directory mounted into the container has the UID/GID of the host user. In order to allow the user builder to write
# into it without changing its ownership (which could render the folder or its contents inaccessible to the host user),
# add the user builder to the group with the same GID as the host user.
HOST_USER_GID=$(stat -c "%g" /home/builder/out)
getent group "$HOST_USER_GID" || groupadd -g "$HOST_USER_GID" hostusrg
usermod -a -G "$HOST_USER_GID" builder
chmod g+w /home/builder/out

# Drop root privileges and build the package.
gosu builder /home/builder/build.sh
