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

* You will need to have Docker installed and running.
* You will need to have Java 8+ installed.
* You will need to have a minimum of 8GB of RAM on your system (the build required 4GB).

## Building the Packages

Builds take at least ~5-15 minutes to complete on a modern machine.  Please ensure that you have Docker installed and running.

You'll want to make sure you've set the exact versions of the binaries you want package in the:

* **Debian Based** - _jdk/debian/src/main/packaging/\<vendor>\/\<version>\/debian/rules_ files.
* **Red Hat Based** - _jdk/redhat/src/main/packaging/\<vendor>/\<version>/\<vendor\>/\<vendor\>-\<version\>-jdk.spec_ files.
* **SUSE Based** - _jdk/suse/src/main/packaging/\<vendor>/\<version>/\<vendor\>/\<vendor\>-\<version\>-jdk.spec_ files.

In all of the examples below you'll need to replace the following variables:

* Replace `<version>` with `8|11|17|18`
* Replace `<vendor>` with `temurin|dragonwell`
* Replace `<platform>` with `Debian|RedHat|Suse`

### Build all packages for a version

```shell
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
export _JAVA_OPTIONS="-Xmx4g"
./gradlew clean package checkPackage -PPRODUCT=<vendor> -PPRODUCT_VERSION=<version>
```

The scripts roughly work as follows:

* **Gradle Kickoff** - The various `packageJdk<platform>` tasks in subdirectories under the _jdk_ directory all have a dependency on the `packageJDK` task,
which in turn has a dependency on the `package` task (this is how Gradle knows to trigger each of those in turn).
* **packageJdk&lt;platform&gt; Tasks** - These tasks are responsible for building the various packages for the given platform.  They fire up the Docker container
(A _Dockerfile_ is included in each subdirectory), mount some file locations (so you can get to the output) and then run packaging commands in that container.
* **checkJdk&lt;platform&gt; Tasks** - Test containers are used to install the package and run the tests in
_src/packageTest/java/packaging_ on them.

[task package](https://github.com/adoptium/installer/blob/master/linux/build.gradle) --> [task packageJdk](https://github.com/adoptium/installer/blob/master/linux/jdk/build.gradle) --> [task packageJdk\<DISTRO\>](jdk/\<vendor\>/build.gradle )
[task checkPackage](https://github.com/adoptium/installer/blob/master/linux/build.gradle)  --> [task checkJdkPackage](https://github.com/adoptium/installer/blob/master/linux/jdk/build.gradle) --> [task checkJdk\<DISTRO\>](jdk/\<vendor\>/build.gradle )

### Build a Debian specific package for a version

- replace `<version>` with `8|11|17|18`
- replace `<vendor>` with `temurin|dragonwell`

```shell
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
export _JAVA_OPTIONS="-Xmx4g"
./gradlew clean packageJdkDebian checkJdkDebian --parallel -PPRODUCT=<vendor> -PPRODUCT_VERSION=<version>
```

### Build a Red Hat specific package for a version

- replace `<version>` with `8|11|17|18`
- replace `<vendor>` with `temurin|dragonwell`

```shell
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
export _JAVA_OPTIONS="-Xmx4g"
./gradlew clean packageJdkRedHat checkJdkRedHat --parallel -PPRODUCT=<vendor> -PPRODUCT_VERSION=<version>
```

### Build a SUSE specific package for a version

- replace `<version>` with `8|11|17|18`
- replace `<vendor>` with `temurin|dragonwell`

```shell
export _JAVA_OPTIONS="-Xmx4g"
export COMPOSE_DOCKER_CLI_BUILD=1
export _JAVA_OPTIONS="-Xmx4g"
./gradlew clean packageJdkSuse checkJdkSuse --parallel -PPRODUCT=<vendor> -PPRODUCT_VERSION=<version>
```

## GPG Signing RPMs

In order to GPG sign the generated RPMs you must add the following argument to the gradlew command:
- replace `<DISTRO>` with `RedHat|Suse|Debian`
- replace `<version>` with `8|11|17|18`
- replace `<vendor>` with `temurin|dragonwell`

```shell
./gradlew packageJdk<DISTRO> --parallel -PPRODUCT=<vendor> -PPRODUCT_VERSION=<version> -PGPG_KEY=</path/to/private/gpg/key>
```

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

In order to produce RPMs on an x86_64 build host for the s390x target architecture, use the `--target` switch to `rpm-build` so as to build for a different
archicture. Suppose the host architecture is `x86_64` and we want to build for target architecture `s390x`:

```shell
rpmbuild --define "_sourcedir $(pwd)" --define "_specdir $(pwd)" \
         --define "_builddir $(pwd)" --define "_srcrpmdir $(pwd)" \
         --define "_rpmdir $(pwd)" --target s390x --rebuild *.src.rpm
```

## Supported packages

### DEB
Supported JDK version 8,11,17,18 
Supported platform amd64, arm64, armhf, ppc64le, s390x (s390x is only available for jdk11+)  

| Distr        | Test enabled platforms | Note |
|--------------|:----------------------:|:----:|
| debian/12    |         x86_64         |      |
| debian/11    |         x86_64         |      |
| debian/10    |         x86_64         |      |   
| ubuntu/22.10 |         x86_64         |      |
| ubuntu/22.04 |         x86_64         |      |
| ubuntu/21.10 |         x86_64         |      |
| ubuntu/20.04 |         x86_64         |      |
| ubuntu/18.04 |         x86_64         |      |

### RPM (RedHat and Suse)
Supported JDK version 8,11,17,18
Supported platform x86_64, aarch64, armv7hl, ppc64le, s390x (s390x is only available for jdk11+)
SRPM also available.

| Distr            | Test enabled platforms | Note |
| ---------------- |:----------------------:|:----:|
| amazonlinux/2    | x86_64     |                |
| centos/7         | x86_64     |                |
| centos/8 (switch to rocky/8)  | x86_64     ||   |
| rpm/fedora/34    | x86_64     |                |
| rpm/fedora/35    | x86_64     |                |
| rpm/fedora/36    | x86_64     |                |
| oraclelinux/7    | x86_64     |                |
| oraclelinux/8    | x86_64     |                |
| opensuse/15.3    | x86_64     |                |
| opensuse/15.4    | x86_64     |                |
| rocky/8          | x86_64     |                |
| rpm/rhel/7       | x86_64     |                |
| rpm/rhel/8       | x86_64     |                |
| sles/12          | Null       | Need subscription to even run zypper update|
| sles/15          | x86_64     |                |

## Install the packages

See [Eclipse Temurin Linux (RPM/DEB) installer packages](https://blog.adoptium.net/2021/12/eclipse-temurin-linux-installers-available)
