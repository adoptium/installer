#!/usr/bin/env bash
set -euxo pipefail

# Ensure necessary directories for rpmbuild operation are present.
rpmdev-setuptree

echo "DEBUG: building RH arch ${buildArch} with jdk version ${buildVersion}"
# Build specified target or build all (not s390x on jdk8)
if [ "${buildArch}" != "all" ]; then
	targets=${buildArch}
elif [ "${buildVersion}" != "8" ]; then
	targets="x86_64 ppc64le aarch64 armv7hl s390x"
else
	targets="x86_64 ppc64le aarch64 armv7hl"
fi

# loop spec file originally from src/main/packaging/$product/$productVersion/*.spec
for spec in "$(ls /home/builder/build/generated/packaging/*.spec)"; do
	spectool -g -R "$spec";
	rpmbuild --nodeps -bs "$spec"; # build src.rpm
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