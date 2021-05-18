# Linux Packages of Eclipse Adoptium 

## RPMs for Fedora/Red Hat

### Other Topics

### Building SRPMs and RPMs Directly

If you do not require testing or advanced build support, it is perfectly fine to eschew the Gradle-based build and to
directly build SRPMs and RPMs using the spec files in the  repository.

In this example, we are using the existing spec files for the Temurin 11 JDK to create an SRPM and then rebuild that
SRPM into a binary RPM. It supports building it for the current target architecture or for a different one than the host
system by specifying `vers_arch`.

Prequisites: `rpm-build` and `rpmdevtools` packages are installed.

#### Produce a Source/Binary RPM for x86_64

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

#### Produce a Source/Binary RPM for s390x on a x86_64 Host

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

````shell
$ rpmbuild --define 'vers_arch s390x' \
           --define "_sourcedir $(pwd)" --define "_specdir $(pwd)" \
           --define "_builddir $(pwd)" --define "_srcrpmdir $(pwd)" \
           --define "_rpmdir $(pwd)" --target "s390x" --rebuild *.src.rpm
````
