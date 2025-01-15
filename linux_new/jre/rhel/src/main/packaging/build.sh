#!/usr/bin/env bash
set -euxo pipefail

# Ensure necessary directories for rpmbuild operation are present.
rpmdev-setuptree

if [ "$buildLocalFlag" == "true" ]; then
	# Copy all sha256 files into SOURCE directory
	count=1
	for sha in $(ls /home/builder/build/jre/*.sha256*.txt); do
		cp $sha /home/builder/rpmbuild/SOURCES/local_build_jre${count}.tar.gz.sha256.txt
		count=$((count + 1))
	done;
	# Copy all source tar files into SOURCE directory
	count=1
	for jre in $(ls /home/builder/build/jre/*.tar.gz); do
		cp $jre /home/builder/rpmbuild/SOURCES/local_build_jre${count}.tar.gz

		# Change name of *.tar.gz in .sha256.txt contents to match new name (local_build_jre#.tar.gz)
		# Example:
		# f579751fdcd627552a550e37ee00f8ff7a04e53bb385154ac17a0fb1fbb6ed12  <vendor>-jre-17.0.7-linux-x64.tar.gz
		# To
		# f579751fdcd627552a550e37ee00f8ff7a04e53bb385154ac17a0fb1fbb6ed12  local_build_jre1.tar.gz
		sed -i "s/$(basename $jre)/local_build_jre${count}.tar.gz/" /home/builder/rpmbuild/SOURCES/local_build_jre${count}.tar.gz.sha256.txt

		count=$((count + 1))
	done;
fi

echo "DEBUG: building RH arch ${buildArch} with jre version ${buildVersion}"
# Build specified target or build all
if [ "${buildArch}" != "all" ]; then
	targets=${buildArch}
elif [ ${buildVersion} -gt 20 ]; then
        targets="x86_64 ppc64le aarch64 s390x riscv64"
else
	targets="x86_64 ppc64le aarch64 armv7hl s390x"
fi

# loop spec file originally from src/main/packaging/$product/$productVersion/*.spec
for spec in "$(ls /home/builder/build/generated/packaging/*.spec)"; do
	spectool -g -R "$spec";
	rpmbuild --define "local_build ${buildLocalFlag}" \
				--nodeps -bs "$spec"; # build src.rpm
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
		rpmbuild --target "$target" \
					--define "local_build ${buildLocalFlag}" \
					--rebuild /home/builder/rpmbuild/SRPMS/*.src.rpm; # build binary package from src.rpm
	done;
done;

# Copy generated SRPMS, RPMs to destination folder
find /home/builder/rpmbuild/SRPMS /home/builder/rpmbuild/RPMS -type f -name "*.rpm" -print0 | xargs -0 -I {} cp {} /home/builder/out
# Rename Src RPM To Include Architecture
cd /home/builder/out/ && for file in `ls -1 *.src.rpm`; do filename=`basename -s .src.rpm $file` ; SRCTarget="$filename.${buildArch}.src.rpm" ; mv $file $SRCTarget ; done && cd -

# Sign generated RPMs with rpmsign.
if grep -q %_gpg_name /home/builder/.rpmmacros; then
	rm -f ~/.gnupg/public-keys.d/pubring.db.lock
	for file in `ls /home/builder/out/*.rpm`; do
		echo Signing: $file
		rpmsign --addsign $file
	done
fi;
