# Packaging AdoptOpenJDK for Linux

## Prerequisites

Note: Linux packages can be created on any Linux distribution and macOS and on any CPU architecture. The package manager which the packages are going to be built for is not required to be present.

### Linux

* [fpm](https://fpm.readthedocs.io/en/latest/installing.html)
* JDK 11 or newer
* Ruby
* RubyGems
* rpmbuild

### macOS

* [fpm](https://fpm.readthedocs.io/en/latest/installing.html)
* JDK 11 or newer
* Ruby
* RubyGems
* gnutar
* rpmbuild

## Packaging

It is possible to simultaneously build Debian and RPM packages by using `./gradlew build` and specifying all properties (`-P`) that required by all package formats.

### Deb packages

Deb packages for Debian and Ubuntu (see section *Support Matrix* below for supported combinations) can be packaged with the help of Gradle and fpm: 

```
./gradlew buildDebPackage \
    -PJDK_DISTRIBUTION_DIR=/path/to/jdk \
    -PJDK_MAJOR_VERSION=<majorversion> \
    -PJDK_VERSION=<versionstring> \
    -PJDK_VM=<vm> \
    -PJDK_ARCHITECTURE=<architecture> \
    -PDEB_JINFO_PRIORITY=<jinfo>
```

`JDK_DISTRIBUTION_DIR` must point to a directory with a binary distribution of AdoptOpenJDK (for example an expanded tarball downloaded from https://adoptopenjdk.net/). 

Example:

```
./gradlew buildDebPackage \
    -PJDK_DISTRIBUTION_DIR=/path/to/jdk-11.0.2+9 \
    -PJDK_MAJOR_VERSION=11 \
    -PJDK_VERSION="11.0.2+9" \
    -PJDK_VM=hotspot \
    -PJDK_ARCHITECTURE=amd64 \
    -PDEB_JINFO_PRIORITY=1101
```

Table with arguments:

|        | JDK\_MAJOR\_VERSION | JDK\_VERSION    | JDK\_VM             | JDK\_ARCHITECTURE                    | DEB\_JINFO\_PRIORITY |
|--------|---------------------|-----------------|---------------------|--------------------------------------|----------------------|
| JDK 8  | 8                   | e.g. `8u202`    | `hotspot`, `openj9` | `amd64`, `s390x`, `ppc64el`, `arm64` | `1081`               |
| JDK 9  | 9                   | e.g. `9.0.4+11` | `hotspot`, `openj9` | `amd64`, `s390x`, `ppc64el`, `arm64` | `1091`               |
| JDK 10 | 10                  | e.g. `10.0.2+13`| `hotspot`, `openj9` | `amd64`, `s390x`, `ppc64el`, `arm64` | `1101`               |
| JDK 11 | 11                  | e.g. `11.0.2+9` | `hotspot`, `openj9` | `amd64`, `s390x`, `ppc64el`, `arm64` | `1111`               |
| JDK 12 | 12                  |                 | `hotspot`, `openj9` | `amd64`, `s390x`, `ppc64el`, `arm64` | `1121`               |

### RPM packages

RPM packages for CentOS, Fedora, Red Hat Enterprise Linux (RHEL) as well as OpenSUSE and SUSE Enterprise Linux (SLES) (see section *Support Matrix* below for supported combinations) can be packaged with the help of Gradle and fpm: 

```
./gradlew buildRpmPackage \
    -PJDK_DISTRIBUTION_DIR=/path/to/jdk \
    -PJDK_MAJOR_VERSION=<majorversion> \
    -PJDK_VERSION=<versionstring> \
    -PJDK_VM=<vm> \
    -PJDK_ARCHITECTURE=<architecture> \
    -PSIGN_PACKAGE=<true|false>
```

`JDK_DISTRIBUTION_DIR` must point to a directory with a binary distribution of AdoptOpenJDK (for example an expanded tarball downloaded from https://adoptopenjdk.net/). 

Example:

```
./gradlew buildRpmPackage \
    -PJDK_DISTRIBUTION_DIR=/path/to/jdk-11.0.2+9 \
    -PJDK_MAJOR_VERSION=11 \
    -PJDK_VERSION="11.0.2+9" \
    -PJDK_VM=hotspot \
    -PJDK_ARCHITECTURE=amd64
    -PSIGN_PACKAGE=true
```

|        | JDK\_MAJOR\_VERSION | JDK\_VERSION    | JDK\_VM             | JDK\_ARCHITECTURE                    |
|--------|---------------------|-----------------|---------------------|--------------------------------------|
| JDK 8  | 8                   | e.g. `8u202`    | `hotspot`, `openj9` | `amd64`, `s390x`, `ppc64el`, `arm64` |
| JDK 9  | 9                   | e.g. `9.0.4+11` | `hotspot`, `openj9` | `amd64`, `s390x`, `ppc64el`, `arm64` |
| JDK 10 | 10                  | e.g. `10.0.2+13`| `hotspot`, `openj9` | `amd64`, `s390x`, `ppc64el`, `arm64` |
| JDK 11 | 11                  | e.g. `11.0.2+9` | `hotspot`, `openj9` | `amd64`, `s390x`, `ppc64el`, `arm64` |
| JDK 12 | 12                  |                 | `hotspot`, `openj9` | `amd64`, `s390x`, `ppc64el`, `arm64` |

RPMs are automatically signed if `SIGN_PACKAGE` is set to `true`. Signing require a file `~/.rpmmacros` to be present that contains the signing config (change values as necessary):

```
%_signature gpg
%_gpg_path /path/to/.gnupg
%_gpg_name KEY_ID
%__gpg /usr/bin/gpg
```

## Support Matrix

### Deb packages

All packages can be installed on Debian and Ubuntu without further changes. They are available for amd64, s390x, ppc64el, arm64 unless otherwise noted. All major versions can be installed side by side. 

| OpenJDK                  | Debian                               | Ubuntu                                                          |
|--------------------------|--------------------------------------|-----------------------------------------------------------------|
| JDK 8 (Hotspot, OpenJ9)  | 8 (jessie), 9 (stretch), 10 (buster) | 14.04* (trusty), 16.04 (xenial), 18.04 (bionic), 18.10 (cosmic) |
| JDK 9 (Hotspot, OpenJ9)  | 8 (jessie), 9 (stretch), 10 (buster) | 14.04* (trusty), 16.04 (xenial), 18.04 (bionic), 18.10 (cosmic) |
| JDK 10 (Hotspot, OpenJ9) | 8 (jessie), 9 (stretch), 10 (buster) | 14.04* (trusty), 16.04 (xenial), 18.04 (bionic), 18.10 (cosmic) |
| JDK 11 (Hotspot, OpenJ9) | 8 (jessie), 9 (stretch), 10 (buster) | 14.04* (trusty), 16.04 (xenial), 18.04 (bionic), 18.10 (cosmic) |
| JDK 12 (Hotspot, OpenJ9) | 8 (jessie), 9 (stretch), 10 (buster) | 14.04* (trusty), 16.04 (xenial), 18.04 (bionic), 18.10 (cosmic) |

\* amd64, ppc64el, arm64 only

### RPM packages

All packages can be installed on CentOS, Fedora, Red Hat Enterprise Linux (RHEL) as well as OpenSUSE and SUSE Enterprise Linux (SLES) without further changes. All major versions can be installed side by side. Packages for Fedora and OpenSUSE are only available for amd64, packages for all other distributions are available for amd64, s390x, ppc64el and arm64.

| OpenJDK                  | CentOS | Fedora | RHEL | OpenSUSE | SLES   |
|--------------------------|--------|--------|------|----------|--------|
| JDK 8 (Hotspot, OpenJ9)  | 6, 7   | 28, 29 | 6, 7 | 15.0     | 12, 15 |
| JDK 9 (Hotspot, OpenJ9)  | 6, 7   | 28, 29 | 6, 7 | 15.0     | 12, 15 |
| JDK 10 (Hotspot, OpenJ9) | 6, 7   | 28, 29 | 6, 7 | 15.0     | 12, 15 |
| JDK 11 (Hotspot, OpenJ9) | 6, 7   | 28, 29 | 6, 7 | 15.0     | 12, 15 |
| JDK 12 (Hotspot, OpenJ9) | 6, 7   | 28, 29 | 6, 7 | 15.0     | 12, 15 |

