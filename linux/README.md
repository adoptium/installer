# Packaging AdoptOpenJDK for Linux

## Prerequisites

Note: Linux packages can be created on any Linux distribution and macOS and on any CPU architecture. The package manager which the packages are going to be built for is not required to be present.

### Linux

* Ruby
* RubyGems
* JDK 11 or newer
* [fpm](https://fpm.readthedocs.io/en/latest/installing.html)

### macOS

* gnutar
* Ruby
* RubyGems
* JDK 11 or newer
* [fpm](https://fpm.readthedocs.io/en/latest/installing.html)

## Packaging


### Deb packages

Deb packages for Debian and Ubuntu (see section *Support Matrix* below for supported combinations) can be packaged with the help of Gradle and fpm: 

```
./gradlew build \
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
./gradlew build \
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

