#!/usr/bin/env bash
set -euxo pipefail

# Ensure necessary directories for rpmbuild operation are present.
rpmdev-setuptree

if [ "$buildLocalFlag" == "true" ]; then
  # Copy all sha256 files into SOURCE directory
  count=1
  for sha in $(ls /home/builder/build/jre/*.sha256*.txt); do
    cp "$sha" /home/builder/rpmbuild/SOURCES/local_build_jre${count}.tar.gz.sha256.txt
    count=$((count + 1))
  done

  # Copy all source tar files into SOURCE directory
  count=1
  for jre in $(ls /home/builder/build/jre/*.tar.gz); do
    cp "$jre" /home/builder/rpmbuild/SOURCES/local_build_jre${count}.tar.gz

    # Change name of *.tar.gz in .sha256.txt contents to match new name (local_build_jre#.tar.gz)
    sed -i "s/$(basename "$jre")/local_build_jre${count}.tar.gz/" /home/builder/rpmbuild/SOURCES/local_build_jre${count}.tar.gz.sha256.txt

    count=$((count + 1))
  done
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
for spec in /home/builder/build/generated/packaging/*.spec; do
  # Build BOTH variants; re-run spectool before each SRPM build because SOURCES may get cleaned
  for bcond in "--with headful" "--without headful"; do
    spectool -g -R "$spec"

    rpmbuild $bcond --define "local_build ${buildLocalFlag}" \
      --nodeps -bs "$spec" # build src.rpm

    # Capture the SRPM we just built for THIS variant
    srpm="$(ls -1t /home/builder/rpmbuild/SRPMS/*.src.rpm | head -n 1)"

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
      rpmbuild $bcond --target "$target" \
        --define "local_build ${buildLocalFlag}" \
        --rebuild "$srpm" # build binary package from THIS src.rpm
    done
  done
done

# Copy generated SRPMS, RPMs to destination folder
mkdir -p /home/builder/out
find /home/builder/rpmbuild/SRPMS /home/builder/rpmbuild/RPMS -type f -name "*.rpm" -print0 | xargs -0 -I {} cp {} /home/builder/out

# Rename Src RPM To Include Architecture (idempotent)
cd /home/builder/out/
for file in *.src.rpm; do
  [ -e "$file" ] || continue
  case "$file" in
    *".${buildArch}.src.rpm") continue ;;
  esac
  filename="$(basename -s .src.rpm "$file")"
  SRCTarget="$filename.${buildArch}.src.rpm"
  mv -f "$file" "$SRCTarget"
done
cd -

# Sign generated RPMs with rpmsign.
if grep -q %_gpg_name /home/builder/.rpmmacros; then
  rm -f ~/.gnupg/public-keys.d/pubring.db.lock
  for file in /home/builder/out/*.rpm; do
    [ -e "$file" ] || continue
    echo "Signing: $file"
    rpmsign --addsign "$file"
  done
fi
