# Adoptium Installers

Repository for creating installable packages for Eclipse Adoptium based releases.

The packages are created using:
1. [Wix Toolset](http://wixtoolset.org) (Windows), detail see [implementation](./wix)
2. [Packages](http://s.sudre.free.fr/Software/Packages/about.html) (MacOS), detail see [implementation](./pkgbuild)
3. Linux installer include deb and rpm based package, detail see [implementation](./linux)

The available packages can be seen from the Eclipse Temurin OpenJDK download page: https://adoptium.net/temurin/releases

If a package is documented here but is not present on the Temurin OpenJDK download page, it may be because it is still being developed. Feel free to ask for the latest status in the installer Slack channel at <https://adoptopenjdk.slack.com>.

See the [CONFIGURATION.md](./CONFIGURATION.md) file for the details of each package.

## Releasing Mac and Windows Installer packages
Run from Jenkins job [Create Installer Mac](https://ci.adoptopenjdk.net/job/build-scripts/job/release/job/create_installer_mac/) and [Create Installer  Windows](https://ci.adoptopenjdk.net/job/build-scripts/job/release/job/create_installer_windows/)

## Releasing Linux Installer packages
During a Release the Linux installers (deb,rpm) are not created as part of the build job, but are instead created manually after the production binaries have been published to `https://github.com/adoptium/temurin{XX}-binaries/releases`.
The following documentation describes how to create and publish these Linux installers to [Artifactory](https://adoptium.jfrog.io/ui/repos/tree/General)

1. Check the given jdk version binaries have been published to GitHub, "latest" should be for Temurin:
  - jdk8 : https://github.com/adoptium/temurin8-binaries/releases/latest
  - jdk11 : https://github.com/adoptium/temurin11-binaries/releases/latest
  - jdk17 : https://github.com/adoptium/temurin17-binaries/releases/latest
  - jdk18 : https://github.com/adoptium/temurin18-binaries/releases/latest
2. For each jdk version and JVM variant, run the following [Jenkins job](https://ci.adoptopenjdk.net/job/build-scripts/job/release/jobs/) (Restricted auth permission) to create and publish Linux installers to Artifactory:
  - ensure values are specified in the correct format, using examples below
  - for new feature release use the full 3 dotted value e.g.jdk19 use "19.0.0" for VERSION
    - When MAJOR_VERSION == 8(replace minor and patch version accordingly)
      - Hotspot jdk8u292-b10:
        - VERSION: 8u292-b10
        - MAJOR_VERSION: 8
        - RELEASE_TYPE: Release
        - JVM: hotspot
        - TAG: jdk8u292-b10
        - SUB_TAG: 8u292b10
    - When MAJOR_VERSION >= 11 && is Feature release:
      - Hotspot jdk\<MAJOR_VERSION>:
        - VERSION: \<MAJOR_VERSION>.0.0+\<PRE-RLEASE_VERSION>
        - MAJOR_VERSION: <MAJOR_VERSION>
        - RELEASE_TYPE: Release
        - JVM: hotspot
        - TAG: jdk-\<MAJOR_VERSION>+\<PRE-RLEASE_VERSION>
        - SUB_TAG: \<MAJOR_VERSION>_\<PRE-RLEASE_VERSION>
    - When MAJOR_VERSION >= 11 && is CPU release:
      - Hotspot jdk\<MAJOR_VERSION>:
        - VERSION: \<MAJOR_VERSION>.\<MINOR_VERSION>.\<PATCH_VERSION>+\<PRE-RLEASE_VERSION>
        - MAJOR_VERSION: \<MAJOR_VERSION>
        - RELEASE_TYPE: Release
        - JVM: hotspot
        - TAG: jdk-\<VERSION>
        - SUB_TAG: \<VERSION>
3. After each Jenkins job run successfully, verify the artifacts have been uploaded to both [deb Artifactory](https://adoptium.jfrog.io/ui/repos/tree/General/deb/pool/main/t) and [rpm Artifactory](https://adoptium.jfrog.io/ui/repos/tree/General/rpm)
    - Verify:
      - For deb:
        - under sub-folder "temurin-<MAJOR_VERSION>"
        - file "temurin-<MAJOR_VERSION>-jdk_*_\<arch>.deb" exist, e.g temurin-18-jdk-18.0.1.0.0.10-1.armv7hl.rpm for jdk-18.0.1 hotspot JDK
      - For rpm:
        - under sub-folder "\<distro>/\<os_version>/\<arch>/Packages/"
        - file "temurin-\<MAJOR_VERSION>-jdk-*.\<arch>.rpm" exist, e.g: temurin-18-jdk-18.0.1.0.0.10-1.armv7hl.rpm for jdk-18.0.1 hotspot JDK
        
