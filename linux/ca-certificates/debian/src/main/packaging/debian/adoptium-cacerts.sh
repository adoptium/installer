#!/usr/bin/env sh
set -eu

cacerts_updates=yes

if [ -f /etc/default/adoptium-ca-certificates ]; then
	# shellcheck disable=SC1091
	. /etc/default/adoptium-ca-certificates
fi

# We need to leave the update-ca-certificates hook in place until the package
# is purged. Therefore we have to check whether trust is a known command.
if [ "$cacerts_updates" != yes ] || ! command -v trust >/dev/null 2>&1 ; then
	echo "Updates of adoptium-ca-certificates' keystore disabled."
	exit 0
fi

# Trust does not overwrite existing files, therefore we need to remove it
# beforehand.
if [ -e "/etc/ssl/certs/adoptium/cacerts" ]; then
	rm -f /etc/ssl/certs/adoptium/cacerts
fi

trust extract --format=java-cacerts /etc/ssl/certs/adoptium/cacerts

echo "/etc/ssl/certs/adoptium/cacerts successfully populated."
