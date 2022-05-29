# openjdk-installer:
Repository for creating installable packages for AdoptOpenJDK releases.

The packages are created using:
1. The Wix Toolset http://wixtoolset.org (Windows only)
2. [Packages](http://s.sudre.free.fr/Software/Packages/about.html) (Mac OS)
3. For putting together `.deb` and `rpms` head to this link: [linuxNew subdir readme](https://github.com/adoptium/installer/tree/master/linuxNew#readme)

The available packages can be seen from the AdoptOpenJDK download pages: https://adoptopenjdk.net/releases.html.

If a package is documented here but is not present on the AdoptOpenJDK download pages it may be because it is still being developed. Feel free to ask for the latest status in the installer Slack channel at [https://adoptopenjdk.slack.com].

See the [CONFIGURATION.md](./CONFIGURATION.md) file for the details of each package.

## Releasing Linux Installer packages
During a Release the Linux installers (deb,rpm) are not created as part of the build job, but are instead created manually after
the production binaries have been published to github.com/jdkNN-binaries/releases. The following documentation describes
how to create and publish these Linux installers to Artifactory.

1. Check the given jdk version binaries have been published to github.com, "latest" maybe Hotspot or OpenJ9 depending on
the publish order, if so specify the expected tag name:
  - jdk8 : https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/latest
  - jdk11 : https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/latest
  - jdk16 : https://github.com/AdoptOpenJDK/openjdk16-binaries/releases/latest
2. For each jdk version and JVM variant run the following Jenkins job (Restricted auth permission) to create and
publish the Linux installers to Artifactory:
  - https://ci.adoptopenjdk.net/job/build-scripts/job/release/job/standalone_create_installer_linux
  - Parameters: (ensure values are specified in the correct format, following the following examples, note for new VERSIONS
 eg.16, use the full 3 dotted value 16.0.0 for the VERSION parameter)
    - Hotspot jdk8u292-b10:
      - VERSION: 8u292-b10
      - MAJOR_VERSION: 8
      - RELEASE_TYPE: Release
      - JVM: hotspot
      - TAG: jdk8u292-b10
      - SUB_TAG: 8u292b10
    - OpenJ9 jdk8u292-b10_openj9-0.26.0:
      - VERSION: 8u292-b10.openj9-0.26.0
      - MAJOR_VERSION: 8
      - RELEASE_TYPE: Release
      - JVM: openj9
      - TAG: jdk8u292-b10_openj9-0.26.0
      - SUB_TAG: 8u292b10_openj9-0.26.0
    - Hotspot jdk-11.0.11+9:
      - VERSION: 11.0.11+9
      - MAJOR_VERSION: 11
      - RELEASE_TYPE: Release
      - JVM: hotspot
      - TAG: jdk-11.0.11+9
      - SUB_TAG: jdk-11.0.11+9
    - Hotspot jdk-11.0.11+9_openj9-0.26.0:
      - VERSION: 11.0.11+9.openj9-0.26.0
      - MAJOR_VERSION: 11
      - RELEASE_TYPE: Release
      - JVM: openj9
      - TAG: jdk-11.0.11+9_openj9-0.26.0
      - SUB_TAG: 11.0.11_9_openj9-0.26.0
    - Hotspot jdk-16+36:
      - VERSION: 16.0.0+36
      - MAJOR_VERSION: 16
      - RELEASE_TYPE: Release
      - JVM: hotspot
      - TAG: jdk-16+36
      - SUB_TAG: 16_36
3. After each Jenkins job verify the success of the job, and also verify the artifacts have been uploaded to Artifactory by checking
this location:
  - https://adoptopenjdk.jfrog.io/ui/repos/tree/General/deb%2Fpool%2Fmain%2Fa
    - Verify the artifacts exist under the relevant sub-folder for the job run, eg.adoptopenjdk-11-hotspot, for jdk-11 hotspot JDK, and
adoptopenjdk-11-hotspot-jre for jdk-11 hotspot JRE


