#!/usr/bin/env bash
set -euxo pipefail

# Ensure necessary directories for rpmbuild operation are present.
rpmdev-setuptree

echo "DEBUG: building RH arch ${buildArch} with jre version ${buildVersion}"
# Build specified target or build all
if [ "${buildArch}" != "all" ]; then
	targets=${buildArch}
else
	targets="x86_64 ppc64le aarch64 armv7hl s390x"
fi

# loop spec file originally from src/main/packaging/$product/$productVersion/*.spec
for spec in "$(ls /home/builder/build/generated/packaging/*.spec)"; do
	spectool -g -R "$spec";
	rpmbuild --nodeps -bs "$spec"; # build src.rpm
	# if buildArch == all, extract ExclusiveArch from the spec file
	if [ "${buildArch}" = "all" ]; then
		# extract the ExclusiveArch from the spec file
		# the sed command is to remove the trailing whitespace
		# the second sed command is to replace %{arm} with armv7hl
		ExclusiveArch=$(grep -E "^ExclusiveArch:" "$spec" | sed -e 's/ExclusiveArch: *//' | sed -e 's/%{arm}/armv7hl/g')
		[ -n "$ExclusiveArch" ] && targets="${ExclusiveArch}"
	fi
	for target in $targets; do
		rpmbuild --target "$target" --rebuild /home/builder/rpmbuild/SRPMS/*.src.rpm; # build binary package from src.rpm
	done;
done;

# Copy generated SRPMS, RPMs to destination folder
find /home/builder/rpmbuild/SRPMS /home/builder/rpmbuild/RPMS -type f -name "*.rpm" -print0 | xargs -0 -I {} cp {} /home/builder/out
# Sign generated RPMs with rpmsign.
if grep -q %_gpg_name /home/builder/.rpmmacros; then
	rpmsign --addsign /home/builder/out/*.rpm
fi;