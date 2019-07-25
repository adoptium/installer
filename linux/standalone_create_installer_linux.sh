#! /bin/bash

# Jenkins build script for the job standalone_create_installer_linux. It
# downloads official releases of a certain major version with a specific VM for
# all architectures into the Jenkins workspace. Then, it repackages all
# tarballs named OpenJDK*.tar.gz into OS packages using Gradle by calling
# create_installer_linux.sh. If desired, the resulting packages are
# automatically published if they haven't been published yet (see environment
# variable RELEASE_TYPE below).
#
# If you want to package AdoptOpenJDK builds yourself, use Gradle directly.
#
# The script expects some environment variables to be present:
#
#   RELEASE_TYPE          "Release", "Nightly" or "Nightly Without Publish".
#                         See AdoptOpenJDK build pipelines for details.
#
#   WORKSPACE             Path to the root directory of Jenkins' workspace.
#
#   MAJOR_VERSION         Major version of AdoptOpenJDK, e.g. 8, 9, 11
#
#   VERSION               Complete version string, e.g. 1.8.0_222-b10
#
#   JVM                   Type of the JVM, e.g. hotspot, openj9_linuxXL
#
#   TAG                   Git tag of the major version, e.g.
#                         jdk-11.0.4+11_openj9-0.15.1
#
#   SUB_TAG               Sub tag of the major version, e.g.
#                         11.0.4_11_openj9-0.15.1
#
#   ARTIFACTORY_PASSWORD  Password of the user that is used to push releases
#                         to Artifactory.
#
# Optional variables:
#
#   ARTIFACTORY_USER            Name of the Artifactory user
#
#   ARTIFACTORY_REPOSITORY_DEB  Name of the Artifactory repository for DEB
#                               packages.
#
#   ARTIFACTORY_REPOSITORY_RPM  Name of the Artifactory repository for RPM
#                               packages.

set -eu
shopt -s globstar nullglob nocaseglob nocasematch

for DISTRIBUTION_TYPE in "jdk" "jre" ; do
    for ARCHITECTURE in "x64" "s390x" "ppc64le" "arm" "aarch64" ; do
        JDK_FILENAME="OpenJDK${MAJOR_VERSION}U-${DISTRIBUTION_TYPE}_${ARCHITECTURE}_linux_${JVM}_${SUB_TAG}.tar.gz"
        DOWNLOAD_URL="https://github.com/AdoptOpenJDK/openjdk${MAJOR_VERSION}-binaries/releases/download/${TAG}/${JDK_FILENAME}"

        # Script should continue even if the file cannot be downloaded because
        # not all variants are available for all platforms.
        # shellcheck disable=SC2015
        (cd "$WORKSPACE" && curl -fO -L "$DOWNLOAD_URL" -o "$JDK_FILENAME" || true)

        if [ -f "$WORKSPACE/$JDK_FILENAME" ] ; then
          (source create_installer_linux.sh)
          rm -v "$WORKSPACE/$JDK_FILENAME"
        fi
    done
done
