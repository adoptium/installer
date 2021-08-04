#! /bin/bash

# Jenkins build script for the job create_installer_linux. It repackages all
# tarballs named OpenJDK*.tar.gz into OS packages that have been copied into
# the root folder of the Jenkins' workspace using Gradle. If desired, the
# resulting packages are automatically published if they haven't been published
# yet (see environment variable RELEASE_TYPE below).
#
# If you want to package Temurin builds yourself, use Gradle directly.
#
# The script expects some environment variables to be present:
#
#   RELEASE_TYPE          "Release", "Nightly" or "Nightly Without Publish".
#                         See Temurin build pipelines for details.
#
#   WORKSPACE             Path to the root directory of Jenkins' workspace.
#
#   MAJOR_VERSION         Major version of Temurin, e.g. 8, 9, 11
#
#   VERSION               Complete version string, e.g. 1.8.0_222-b10
#
#   ARCHITECTURE          Name of the CPU architecture, e.g. x64. See
#                         Temurin build pipelines for valid values.
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

if [ -z "${ARTIFACTORY_USER+x}" ]; then
    # TODO Need to change bot user name long term
    ARTIFACTORY_USER="adoptopenjdk-jenkins-bot"
fi

# Need the XXXXXX else the template complains it doesn't have them
DISTRIBUTION_DIR=$(mktemp -d -t adoptjdkbuild.XXXXXX)

finish() {
    if [ -d "$DISTRIBUTION_DIR" ] ; then
        rm -rf "$DISTRIBUTION_DIR"
    fi
}
trap finish EXIT

echoerr() { printf "%s\n" "$*" >&2; }

# Define Artifactory repositories to deploy to depending on the type of the
# release if custom repositories haven't been specified with
# ARTIFACTORY_REPOSITORY_DEB or ARTIFACTORY_REPOSITORY_RPM. If it's a nightly
# build without publication, instruct Gradle only to build the packages
# without uploading them.
case "$RELEASE_TYPE" in
    "Release")
        if [ -z "${ARTIFACTORY_REPOSITORY_DEB+x}" ]; then
            ARTIFACTORY_REPOSITORY_DEB="deb"
        fi
        if [ -z "${ARTIFACTORY_REPOSITORY_RPM+x}" ]; then
            ARTIFACTORY_REPOSITORY_RPM="rpm"
        fi
        GRADLE_TASK="upload"
        ;;
    "Nightly")
        if [ -z "${ARTIFACTORY_REPOSITORY_DEB+x}" ]; then
            ARTIFACTORY_REPOSITORY_DEB="deb-nightly"
        fi
        if [ -z "${ARTIFACTORY_REPOSITORY_RPM+x}" ]; then
            ARTIFACTORY_REPOSITORY_RPM="rpm-nightly"
        fi
        GRADLE_TASK="upload"
        ;;
    "Nightly Without Publish")
        ARTIFACTORY_REPOSITORY_DEB=""
        ARTIFACTORY_REPOSITORY_RPM=""
        GRADLE_TASK="build"
        ;;
    *)
        echoerr "Unsupported build type"
        exit 0
        ;;
esac

if [ -z "${ARTIFACTORY_PASSWORD+x}" ]; then
   echo No artifactory credentials available - will not upload
   GRADLE_TASK=build
elif [ "${GRADLE_TASK}" == "upload" ]; then
   GRADLE_ARTIFACTORY_OPTS="-PARTIFACTORY_USER="$ARTIFACTORY_USER" -PARTIFACTORY_PASSWORD="$ARTIFACTORY_PASSWORD" -PARTIFACTORY_REPOSITORY_DEB=$ARTIFACTORY_REPOSITORY_DEB -PARTIFACTORY_REPOSITORY_RPM=$ARTIFACTORY_REPOSITORY_RPM"
fi

JDK_TARBALLS=( "$WORKSPACE"/OpenJDK*.tar.gz )
for JDK_TARBALL in ${JDK_TARBALLS[*]} ; do

    # Determine whether the tarball to repackage is a JRE or JDK by looking at
    # the filenames.
    case "$JDK_TARBALL" in
        *OpenJDK${MAJOR_VERSION}*jdk*hotspot*.tar.gz|*OpenJDK${MAJOR_VERSION}*jdk*openj9*.tar.gz)
            DISTRIBUTION_TYPE="JDK"
            ;;
        *OpenJDK${MAJOR_VERSION}*jre*hotspot*.tar.gz|*OpenJDK${MAJOR_VERSION}*jre*openj9*.tar.gz)
            DISTRIBUTION_TYPE="JRE"
            ;;
        *)
            echoerr "Distribution type not recognized in $JDK_TARBALL"
            continue
            ;;
    esac

    # Determine the type of Java VM by looking at the filename.
    case "$JDK_TARBALL" in
        *openj9*XL*)
            JVM="openj9_xl"
            ;;
        *openj9*)
            JVM="openj9"
            ;;
        *hotspot*)
            JVM="hotspot"
            ;;
        *)
            echoerr "Could not recognize JVM type in file name: $JDK_TARBALL"
            continue
            ;;
    esac

    if [ -d "$DISTRIBUTION_DIR" ] ; then
        rm -rf "$DISTRIBUTION_DIR"
    fi

    mkdir "$DISTRIBUTION_DIR" && tar xf "$JDK_TARBALL" -C "$_" --strip-components=1

    ./gradlew clean $GRADLE_TASK \
        -PJDK_DISTRIBUTION_DIR="$DISTRIBUTION_DIR" \
        -PJDK_MAJOR_VERSION="$MAJOR_VERSION" \
        -PJDK_VERSION="$VERSION" \
        -PJDK_VM="$JVM" \
        -PJDK_ARCHITECTURE="$ARCHITECTURE" \
        -PJDK_DISTRIBUTION_TYPE="$DISTRIBUTION_TYPE" \
        ${GRADLE_ARTIFACTORY_OPTS:-}
done
