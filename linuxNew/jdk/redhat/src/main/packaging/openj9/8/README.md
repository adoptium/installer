# OpenJ9 RPM packaging prototype

This is a prototype for packaging OpenJ9 via an RPM
and also be able to rebuild it downstream via the provided
SRPM.

## Prerequisites

Packages `rpmdevtools` and `rpm-build` are installed on the
system. For example:

```
$ rpm -q rpmdevtools rpm-build
rpmdevtools-9.3-3.fc33.noarch
rpm-build-4.16.1.3-1.fc33.x86_64
```

## Basic Usage

On update, change the version numbers according to the new release
in `jdk/redhat/src/main/packaging/8/openj9/java-1.8.0-openj9.spec`.

Then, create a new SRPM from it. First by downloading the release
blobs.

```
$ spectool --gf java-1.8.0-openj9.spec
```

This downloads the binary blob tarballs (per architecture) and
associated sources.

Next, we build the SRPM via:

```
$ rpmbuild --define "_sourcedir $(pwd)" --define "_specdir $(pwd)" \
           --define "_builddir $(pwd)" --define "_srcrpmdir $(pwd)" \
           --define "_rpmdir $(pwd)" --nodeps -bs java-1.8.0-openj9.spec
```

Finally, we can build the binary RPM from the SRPM on the spec-file
supported architectures, x86_64, ppc64le, s390x. In this case, it would
build for the host architecture:

```
$ rpmbuild --define "_sourcedir $(pwd)" --define "_specdir $(pwd)" \
           --define "_builddir $(pwd)" --define "_srcrpmdir $(pwd)" \
           --define "_rpmdir $(pwd)" --rebuild *.src.rpm
```

## Building for a different architecture

Use the `--target` switch to `rpm-build` so as to build for a different
archicture. Suppose the host architecture is `x86_64` and we want to build
for target architecture `ppc64le`:

```
$ rpmbuild --define "_sourcedir $(pwd)" --define "_specdir $(pwd)" \
           --define "_builddir $(pwd)" --define "_srcrpmdir $(pwd)" \
           --define "_rpmdir $(pwd)" --target ppc64le --rebuild *.src.rpm
```
