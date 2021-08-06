# Linux Packages of Eclipse Adoptium

We package for Debian, Red Hat, Suse (e.g. Yum and RPM based) Linux distributions.

The current implementation to build the packages involves using Gradle to call a small Java program.
That Java program spinning up a Docker container, installing the base O/S and its packaging tools,
and then looping over configuration to create the various packages and sign them as appropriate.

TODO You can then optionally upload those packages to a package repository of your choice.  As a default
the scripts upload to the Eclipse Foundation Nexus Package Repository as part of the Eclipse Adoptium
CI/CD pipeline runs.

## Prerequisites

To run this locally

* You will need to have Docker installed and running.
* You will need to have Java 8+ installed.
* You will need to have a minimum of 16GB of RAM on your system.

## Building the Packages

Builds take at least ~15 minutes to complete on a modern machine.  Please ensure that you have Docker installed and running.

You'll want to make sure you've set the exact versions of the binaries you want package in the:

* **Debian Based** - _jdk\debian\src\main\packaging\\&lt;vendor&gt;\\&lt;version&gt;\\&lt;platform&gt;\\rules_ files.
* **Red Hat Based** - _jdk\redhat\src\main\packaging\\&lt;vendor&gt;\\&lt;version&gt;\\&lt;vendor&gt;-&lt;version&gt;-jdk.spec_ files.
* **Suse Based** - _jdk\suse\src\main\packaging\\&lt;vendor&gt;\\&lt;version&gt;\\&lt;vendor&gt;-&lt;version&gt;-jdk.spec_ files.

In all of the examples below you'll need to replace the following variables:

* Replace `<version>` with `8|11|16`
* Replace `<vendor>` with `temurin|dragonwell`

### Build all packages for a version

```shell
export _JAVA_OPTIONS="-Xmx4g"
./gradlew clean package checkPackage -PPRODUCT=<vendor> -PPRODUCT_VERSION=<version>
```

The scripts roughly work as follows:

* **Gradle Kickoff** - The various `packageJdk<platform>` tasks in subdirectories under the _jdk_ directory all have a dependency on the `packageJDK` task,
which in turn has a dependency on the `package` task (this is how Gradle knows to trigger each of those in turn).
* **packageJdk&lt;platform&gt; Tasks** - These tasks are responsible for building the various packages for the given platform.  They fire up the Docker container
(A _Dockerfile_ is included in each subdirectory), mount some file locations (so you can get to the output) and then run packaging commands in that container.
* **TODO** - More details about how it works.

### Build a Debian specific package for a version


```shell
export _JAVA_OPTIONS="-Xmx4g"
./gradlew clean packageJdkDebian checkJdkDebian --parallel -PPRODUCT=<vendor> -PPRODUCT_VERSION=<version>
```

### Build a Red Hat specific package for a version

Replace `<version>` with `8|11|16`
Replace `<vendor>` with `temurin|dragonwell`


```shell
export _JAVA_OPTIONS="-Xmx4g"
./gradlew clean packageJdkRedHat checkJdkRedHat --parallel -PPRODUCT=<vendor> -PPRODUCT_VERSION=<version>
```

### Build a Suse specific package for a version

Replace `<version>` with `8|11|16`

```shell
export _JAVA_OPTIONS="-Xmx4g"
./gradlew clean packageSuseRedHat checkSuseRedHat --parallel -PPRODUCT=<vendor> -PPRODUCT_VERSION=<version>
```

## Building SRPMs and RPMs Directly

If you do not require testing or advanced build support, it is perfectly fine to eschew the Gradle-based build and to
directly build SRPMs and RPMs using the spec files in the  repository.

In this example, we are using the existing spec files for the Temurin 11 JDK to create an SRPM and then rebuild that
SRPM into a binary RPM. It supports building it for the current target architecture or for a different one than the host
system by specifying `vers_arch`.

Prerequisites: `rpm-build` and `rpmdevtools` packages are installed.

### Produce a Source/Binary RPM for x86_64

Consider this RPM build where x86_64 is the build hosts' architecture.

```shell
$ spec=$(pwd)/temurin-11-jdk.spec
$ mkdir temurin_x86_64
$ pushd temurin_x86_64
$ spectool --gf ${spec}
$ sha256sum -c *.sha256.txt
```

Create an SRPM:

```shell
$ rpmbuild --define "_sourcedir $(pwd)" --define "_specdir $(pwd)" \
           --define "_builddir $(pwd)" --define "_srcrpmdir $(pwd)" \
           --define "_rpmdir $(pwd)" --nodeps -bs ${spec}
```

Build the binary from the SRPM:

```shell
$ rpmbuild --define "_sourcedir $(pwd)" --define "_specdir $(pwd)" \
           --define "_builddir $(pwd)" --define "_srcrpmdir $(pwd)" \
           --define "_rpmdir $(pwd)" --rebuild *.src.rpm
```

### Produce a Source/Binary RPM for s390x on a x86_64 Host

In order to produce RPMs on an x86_64 build host for the s390x target architecture, consider this example.

```shell
$ spec=$(pwd)/temurin-11-jdk.spec
$ mkdir temurin_s390x
$ pushd temurin_s390x
$ spectool --define 'vers_arch s390x' \
           --gf ${spec}.spec
$ sha256sum -c *.sha256.txt
```

Create an SRPM:

```shell
$ rpmbuild --define 'vers_arch s390x' \
           --define "_sourcedir $(pwd)" --define "_specdir $(pwd)" \
           --define "_builddir $(pwd)" --define "_srcrpmdir $(pwd)" \
           --define "_rpmdir $(pwd)" --nodeps -bs ${spec}.spec
```

Build the binary from the SRPM:

```shell
$ rpmbuild --define 'vers_arch s390x' \
           --define "_sourcedir $(pwd)" --define "_specdir $(pwd)" \
           --define "_builddir $(pwd)" --define "_srcrpmdir $(pwd)" \
           --define "_rpmdir $(pwd)" --target "s390x" --rebuild *.src.rpm
```
