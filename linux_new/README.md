# Linux Packages of Eclipse Adoptium

We package for Debian, Red Hat, SUSE (e.g. DEB and RPM based) Linux distributions.

The current implementation to build the packages involves using Gradle to call a small Java program.
That Java program spins up a Docker container, installing the base O/S and its packaging tools,
and then looping over configuration to create the various packages and signing them as appropriate
with the (Eclipse Foundation as a default) signing service.

TODO You can then optionally upload those packages to a package repository of your choice.
The default Adoptium package repository is https://packages.adoptium.net/ui/packages. The packages are built and uploaded by Jenkins pipeline job defined by [Jenkinsfile](https://github.com/adoptium/installer/blob/master/linux/Jenkinsfile)

## Prerequisites

To run this locally

* You will need to have Docker 20.10+ installed and running.
* You will need to have Java 8+ installed.
* You will need to have a minimum of 8GB of RAM on your system (the build required 4GB).

## Building the Packages

Builds take at least ~5-15 minutes to complete on a modern machine.  Please ensure that you have Docker installed and running.

You'll want to make sure you've set the exact versions of the binaries you want package in the:

* **Alpine Based** - _{jdk,jre}/alpine/src/main/packaging/\<vendor>\/\<version>\/AKKBUILD_ files.
* **Debian Based** - _{jdk,jre,ca-certificates}/debian/src/main/packaging/\<vendor>\/\<version>\/debian/rules_ files.
* **Red Hat Based** - _{jdk,jre}/redhat/src/main/packaging/\<vendor>/\<version>/\<vendor\>/\<vendor\>-\<version\>-jdk.spec_ files.
* **SUSE Based** - _{jdk,jre}/suse/src/main/packaging/\<vendor>/\<version>/\<vendor\>/\<vendor\>-\<version\>-jdk.spec_ files.

In all the examples below you'll need to replace the following variables:

* Replace `<version>` with `8|11|17|19`
* Replace `<vendor>` with `temurin|dragonwell`
* Replace `<platform>` with `Alpine|Debian|RedHat|Suse`
* Replace `<type>` with `Jdk|Jre` (or `CaCertificates` for the `Debian` platform)

**Notes:**
* Not all combinations are possible, i.e., for some vendors we might only provide certain versions, or types.
* For `Debian` we provide a separate package with _Certification Authority_ certificates.

### Build all packages for a version

```shell
export DOCKER_BUILDKIT=1
export _JAVA_OPTIONS="-Xmx4g"
./gradlew clean package checkPackage -PPRODUCT=<vendor> -PPRODUCT_VERSION=<version>
```

The scripts roughly work as follows:

* **Gradle Kickoff** - The various `package<type><platform>` tasks in subdirectories under the _jdk_ (or _jre_) directory all have a dependency on the `packageJDK` (`packageJRE`) task,
which in turn has a dependency on the `package` task (this is how Gradle knows to trigger each of those in turn).
* **package<type>&lt;platform&gt; Tasks** - These tasks are responsible for building the various packages for the given platform.  They fire up the Docker container
(A _Dockerfile_ is included in each subdirectory), mount some file locations (so you can get to the output) and then run packaging commands in that container.
* **check<type>&lt;platform&gt; Tasks** - Test containers are used to install the package and run the tests in
_src/packageTest/java/packaging_ on them.

- [task package](build.gradle) --> [task package\<type\>](<type>/build.gradle) --> [task package\<type>\<DISTRO\>](<type>/\<vendor\>/build.gradle )
- [task checkPackage](build.gradle)  --> [task check\<type\>Package](<type>/build.gradle) --> [task check\<type>\<DISTRO\>](<type>/\<vendor\>/build.gradle )

### Build a Debian specific package for a version

- replace `<version>` with `8|11|17|19`
- replace `<vendor>` with `temurin|dragonwell`
- Replace `<type>` with `Jdk|Jre`

```shell
export DOCKER_BUILDKIT=1
export _JAVA_OPTIONS="-Xmx4g"
./gradlew clean package<type>Debian check<type>Debian --parallel -PPRODUCT=<vendor> -PPRODUCT_VERSION=<version>
```

### Build a Red Hat specific package for a version

- replace `<version>` with `8|11|17|19`
- replace `<vendor>` with `temurin|dragonwell`

```shell
export DOCKER_BUILDKIT=1
export _JAVA_OPTIONS="-Xmx4g"
./gradlew clean packageJdkRedHat checkJdkRedHat --parallel -PPRODUCT=<vendor> -PPRODUCT_VERSION=<version>
```

### Build a SUSE specific package for a version

- replace `<version>` with `8|11|17|19`
- replace `<vendor>` with `temurin|dragonwell`

```shell
export DOCKER_BUILDKIT=1
export _JAVA_OPTIONS="-Xmx4g"
./gradlew clean packageJdkSuse checkJdkSuse --parallel -PPRODUCT=<vendor> -PPRODUCT_VERSION=<version>
```

## GPG Signing RPMs/APKs

In order to GPG sign the generated RPMs/APKs you must add the following argument to the gradlew command:
- replace `<DISTRO>` with `Alpine|RedHat|Suse`
- replace `<version>` with `8|11|17|19`
- replace `<vendor>` with `temurin|dragonwell`

```shell
./gradlew packageJdk<DISTRO> --parallel -PPRODUCT=<vendor> -PPRODUCT_VERSION=<version> -PGPG_KEY=</path/to/private/gpg/key>
```

## Building from local files

In order to build a jdk/jre package for RPM or DEB from local `tar.gz` file(s), put both the `tar.gz` and the `sha256.txt` files in an empty input directory. If the vendor supports building locally, then one can specify this directory when running `./gradlew clean` using the `-PINPUT_DIR` flag

Example:
```shell
./gradlew clean packageJdkRedHat checkJdkRedHat --parallel -PPRODUCT=<vendor> -PPRODUCT_VERSION=<version> -PARCH=<architecture> -PINPUT_DIR=<path/to/input/directory>
```

**NOTE if building an RPM**:
Make sure to update global variables `upstream_version` and `spec_version` in the corresponding spec-file to match the version number of the jdk/jre RPM that you are building. (This is how RPM determines the version number of the resulting package)

**Note if building an DEB**:
Make sure to update the `changelog` file in the corresponding vendor's debian folder so the most recent entry is about the version number of the jdk/jre DEB that you are building. (This is how DEB determines the version number of the resulting package)

## Building SRPMs and RPMs Directly

If you do not require testing or advanced build support, it is perfectly fine to eschew the Gradle-based build and to
directly build SRPMs and RPMs using the spec files in the repository.

In this example, we are using the existing spec files for the Temurin 11 JDK to create an SRPM and then rebuild that
SRPM into a binary RPM. It supports building it for the current target architecture or for a different one than the host
system by specifying `vers_arch`.

Prerequisites: `rpm-build` and `rpmdevtools` packages are installed. For example:

```
$ rpm -q rpmdevtools rpm-build
rpmdevtools-9.3-3.fc33.noarch
rpm-build-4.16.1.3-1.fc33.x86_64
```

### Produce a Source/Binary RPM for x86_64

Consider this RPM build where x86_64 is the build hosts' architecture.
Download the release blobs and associated sources.
Suppose build rpm for jdk11 for target architecture `x86_64`

```shell
cd linux/jdk/redhat/src/main/packaging/temurin/11
mkdir temurin_x86_64
pushd temurin_x86_64
spec=$(pwd)/temurin-11-jdk.spec
spectool --gf ${spec}
sha256sum -c *.sha256.txt
```

Create a SRPM:

```shell
rpmbuild --define "_sourcedir $(pwd)" --define "_specdir $(pwd)" \
         --define "_builddir $(pwd)" --define "_srcrpmdir $(pwd)" \
         --define "_rpmdir $(pwd)" --nodeps -bs ${spec}
```

Build the binary from the SRPM:

```shell
rpmbuild --define "_sourcedir $(pwd)" --define "_specdir $(pwd)" \
         --define "_builddir $(pwd)" --define "_srcrpmdir $(pwd)" \
         --define "_rpmdir $(pwd)" --rebuild *.src.rpm
```

### Building for a different architecture

In order to produce RPMs on an x86_64 build host for the s390x target architecture, use the `--target` switch to `rpm-build` to build for a different
architecture. Suppose the host architecture is `x86_64` and we want to build for target architecture `s390x`:

```shell
rpmbuild --define "_sourcedir $(pwd)" --define "_specdir $(pwd)" \
         --define "_builddir $(pwd)" --define "_srcrpmdir $(pwd)" \
         --define "_rpmdir $(pwd)" --target s390x --rebuild *.src.rpm
```

## Supported packages

### APK (Alpine)
- Supported JDK version 8,11,17,19
- Supported JRE version 8,11,17,19

Supported platform amd64

| Distro       | Test enabled platforms | Note |
|--------------|:----------------------:|:----:|
| alpine/3.x.x |         x86_64         |      |

### DEB
- Supported JDK version 8,11,17,19
- Supported JRE version 8,11,17,19

Supported platform amd64, arm64, armhf, ppc64le, s390x (s390x is only available for jdk > 8)

| Distro                       | Test enabled platforms | Note |
|------------------------------|:----------------------:|:----:|
| debian/13 (trixie/testing)   |         x86_64         |      |
| debian/12 (bookworm/testing) |         x86_64         |      |
| debian/11 (bullseye/stable)  |         x86_64         |      |
| debian/10 (buster/oldstable) |         x86_64         |      |
| ubuntu/24.10 (oracular)      |         x86_64         |      |
| ubuntu/24.04 (noble)         |         x86_64         |      |
| ubuntu/22.04 (jammy)         |         x86_64         |      |
| ubuntu/20.04 (focal)         |         x86_64         |      |
| ubuntu/18.04 (bionic)        |         x86_64         |      |

- Debian Releases: https://www.debian.org/releases/index.en.html
- Ubuntu Releases: https://ubuntu.com/about/release-cycle

### RPM (RedHat and Suse)
- Supported JDK version 8,11,17,19
- Supported JRE version 8,11,17,19

Supported platform x86_64, aarch64, armv7hl, ppc64le, s390x (s390x is only available for jdk > 8)
SRPM also available.

| Distro        | Test enabled platforms |                    Note                     |
|---------------|:----------------------:|:-------------------------------------------:|
| amazonlinux/2 |         x86_64         |                                             |
| centos/7      |         x86_64         |                                             |
| rpm/fedora/35 |         x86_64         |                                             |
| rpm/fedora/36 |         x86_64         |                                             |
| rpm/fedora/37 |         x86_64         |                                             |
| rpm/fedora/38 |         x86_64         |                                             |
| rpm/fedora/39 |         x86_64         |                                             |
| oraclelinux/7 |         x86_64         |                                             |
| oraclelinux/8 |         x86_64         |                                             |
| opensuse/15.3 |         x86_64         |                                             |
| opensuse/15.4 |         x86_64         |                                             |
| opensuse/15.5 |         x86_64         |                                             |
| rocky/8       |         x86_64         |                                             |
| rpm/rhel/7    |         x86_64         |                                             |
| rpm/rhel/8    |         x86_64         |                                             |
| rpm/rhel/9    |         x86_64         |                                             |
| sles/12       |          Null          | Need subscription to even run zypper update |
| sles/15       |         x86_64         |                                             |

## Install the packages

See [Eclipse Temurin Linux (RPM/DEB) installer packages](https://adoptium.net/installation/linux/)
