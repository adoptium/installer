#!/usr/bin/env bash
set -euxo pipefail

# Ensure necessary directories for rpmbuild operation are present.
rpmdev-setuptree

echo "DEBUG: building Suse arch ${buildArch} with version ${buildVersion}"
# Build specified target or build all
if [ "${buildArch}" != "all" ]; then
	targets=${buildArch}
elif [ ${buildVersion} -gt 20 ]; then
        targets="x86_64 ppc64le aarch64 s390x riscv64"
else
	targets="x86_64 ppc64le aarch64 armv7hl s390x"
fi

for spec in "$(ls /home/builder/build/generated/packaging/*.spec)"; do
	rpmdev-spectool -g -R "$spec";
	rpmbuild --nodeps -bs "$spec";
	# if buildArch == all, extract ExclusiveArch from the spec file
	if [ "${buildArch}" = "all" ]; then
		# extract the ExclusiveArch from the spec file
		# the sed command is to remove the trailing whitespace
		# the second sed command is to replace %{arm} with armv7hl
		ExclusiveArch=$(grep -E "^ExclusiveArch:" "$spec" | sed -e 's/ExclusiveArch: *//' | sed -e 's/%{arm}/armv7hl/g')
		if [ "$ExclusiveArch" = "x64" ] ; then ExclusiveArch="x86_64" ; fi
		[ -n "$ExclusiveArch" ] && targets="${ExclusiveArch}"

	fi
	for target in $targets; do
		rpmbuild --target "$target" --rebuild /home/builder/rpmbuild/SRPMS/*.src.rpm;
	done;
done;

# Copy generated RPMs to destination folder
find /home/builder/rpmbuild/SRPMS /home/builder/rpmbuild/RPMS -type f -name "*.rpm" -print0 | xargs -0 -I {} cp {} /home/builder/out
# Rename Src RPM To Include Architecture
cd /home/builder/out/ && for file in `ls -1 *.src.rpm`; do filename=`basename -s .src.rpm $file` ; SRCTarget="$filename.${buildArch}.src.rpm" ; mv $file $SRCTarget ; done && cd -

# Sign generated RPMs with rpmsign
if grep -q %_gpg_name /home/builder/.rpmmacros; then
	rm -f ~/.gnupg/public-keys.d/pubring.db.lock
	for file in `ls /home/builder/out/*.rpm`; do
		echo Signing: $file
		rpmsign --addsign $file
	done
fi;
