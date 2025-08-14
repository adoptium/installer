# Maintaining The Linux Installer Packaging Process

This document is intended to provide a guide to the most common works needed to maintain and produce the current set of linux installer packages.

## 1. Overview Of The Linux Installer Packaging Process

The linux installer packaging process, currently consists of the following elements:


  ### 1.1. Jenkins Linux Packaging Job
  
  This job which has restricted access. It requires several inputs that drive the packaging process:

  
  + JDK / JRE - Whether you would like the packaging process to produce the installer packages for the JDK or JRE
  + Java version option (Which version of Java to produce packages for)
    + Current Options : 8, 11, 17, 21, 22 
  + Architecture - (Which hardware platform to build for)
    + Current Options :
      + x86_64
      + armv7hl ( RHEL / Suse Arm 32 Platform Option )
      + armv7l ( Debian Arm 32 Platform Option )
      + aarch64
      + ppc64le
      + s390x
      + riscv64
      + all (This will attempt to run for all of the available architectures)
  + Distribution - (Which Linux distributions to build for)
    + Current Options :
      + Alpine
      + Debian
      + RHEL
      + Suse
      + all (This will attempt to run for all of the available distributions)

There are a number of restrictions around combinations of architecture and platforms detailed in Appendix A below. For our CI/CD pipelines, the [jenkinsfile](https://github.com/adoptium/installer/blob/master/linux/Jenkinsfile) has been coded to exclude these from the build processes, details are included here for reference.


  ### 1.2. Gradle / Docker Package Build & Test Process

Once the jenkins job is triggered, it performs a build using Gradle, and a Dockerfile to produce installer packages for the supported versions of each of the 4 distributions that we currently support, i.e., `.apk` (Alpine), `.deb` (Debian) & `.rpm` (RHEL & Suse). The versions of each specific distribution supported can be viewed in the [jenkinsfile](https://github.com/adoptium/installer/blob/master/linux/Jenkinsfile) by searching for the `deb_versions` variable, or the `distro_Package` variable. The table below shows the currently supported versions, but this does change on a regular basis.


Supported Linux Distros:
Distribution Type| Supported Versions
----------|---------
Apk (Alpine)| All supported version.
Deb (Debian)| Trixie (Debian 13)<br>Bookworm (Debian 12)</br>Bullseye (Debian 11)<br>Oracular (Ubuntu 24.10)</br>Noble (Ubuntu 24.04)</br>Jammy (Ubuntu 22.04)</br>Focal (Ubuntu 20.04)</br>Bionic (Ubuntu 18.04)
RPM (RHEL)| centos 7</br> rocky 8</br>RHEL7 , RHEL8 & RHEL9</br> Fedora 35, 36, 37, 38 ,39 , 40</br>Oracle Linux 7 & 8</br>Amazon Linux 2
RPM(SUSE) | Opensuse 15.3</br>Opensuse 15.4</br>Opensuse 15.5</br>SLES 12</br>SLES15

As part of this process, the packages are first built, using the appropriate mechanisms, and then a set of unit tests are executed to ensure the builds have completed correctly.

  ### 1.3. Package Signing & Upload

  The final part of the jenkins job is triggered when either/both of the enable enableGpgSigning and uploadPackage options are selected. 

  The Gpg signing uses the Adoptium Gpg key to sign the installer packages prior to their upload to the [Jfrog artifactory, hosted at packages.adoptium.net](https://packages.adoptium.net/)



## 2. Preparing The Source Code For Package Builds & Releases

Prior to building and releasing any packages, the source code that controls the process requires a number of updates. These updates typically happen once all of the linux platforms for a particular Java version have been released and the binaries uploaded to Github.

Prior to updating the source code, its important to have an understanding of how the source code is structured so that the correct files can be updated. The callout below, highlights the structure of the source code so for example underneath the linux top level directory, a selection of either jdk/jre, followed by the distribution, and then the vendor (temurin in the example), followed by the Java version. 

```
-- linux
  -- jdk / jre
    -- alpine / debian / rhel / suse (Distribution)
      -- src
        -- main
          -- packaging
            -- temurin / dragonwell / openj9 (Package vendor)
              -- 8 / 11 / 17 / 21/ 22 (Java version)
```

The following sections will detail the source changes required when a release is done, similar changes are made to both jdk/jre and are also similar between versions. Changes should be made in the specific vendor version being edited. The examples shown in this document assume a Temurin release is being undertaken.

  ### Per Distribution Guide To Code Changes

  <details><summary>2.1 Alpine Linux</summary>

  To update the source files for each new Alpine release, the ``ÀPKBUILD`` file ( located under _jdk_ / alpine / src / main / packaging /_temurin_ / _21_for example) must be updated in several ways, there are 2 sections of the APKBUILD file that need to be considered..

  <h5>2.1.1 The header section (example below)</h5>

  In this section, the key fields that must be amended are as follows

  <b>pkg_ver</b> : This field should be amended to the version tag of the release being processed, e.g , 21.0.3_p9.</br>
  <b>pkgrel</b> : This field should be reset to 0 for the first release of a package, and then incremented should there be patches or additional rebuilds of this package version.</br>

  And additionally were an additional architecture being added (Alpine is currently only supported on x86_64 and Alpine from JDK version 21 onwards), then the <b>arch</b> field would also need appending.

  Once all changes are made in the header section, its time to move on to the footer section.  

    ```
    pkgname=temurin-21
    pkgver=21.0.3_p9
    # replace _p1 with _1
    _pkgver=${pkgver/_p/_}
    _pkgverplus=${pkgver/_p/+}
    _pkgvername=${_pkgverplus/+/%2B}
    pkgrel=1
    pkgdesc="Eclipse Temurin 21"
    provider_priority=21
    url="https://adoptium.net"
    arch="aarch64 x86_64"
    ```

<h5>2.1.2 The footer section (example below)</h5>

  In this section, the key fields that must be amended are the architecture specific checksum, as shown below. These checksums are released alongside the binary files uploaded to Github, so these checksums can be obtained from there. 

  Again, were another architecture being added an additional element in the case statement below would be required, along with its checksum.
  
  <b>NB:</b> Note how the case statement uses the values from the <b>arch</b> field in the header section to determine the correct checksum to use.


```
case "$CARCH" in
	x86_64)
	  _arch_sum="8e861638bf6b08c6d5837de6dc929930550928ec5fcc81b9fa7e8296afd0f9c0"	;;
	aarch64)
		_arch_sum="0f68a9122054149861f6ce9d1b1c176bbe30dd76b36b74c916ba897c12e9d970"
		;;
esac

sha256sums="
$_arch_sum  OpenJDK21u-jdk_${CARCH/x86_64/x64}_alpine-linux_hotspot_$_pkgver.tar.gz
e9185736dde99a4dc570a645a20407bdb41c1f48dfc34d9c3eb246cf0435a378  HelloWorld.java
22d2ff9757549ebc64e09afd3423f84b5690dcf972cd6535211c07c66d38fab0  TestCryptoLevel.java
9fb00c7b0220de8f3ee2aa398459a37d119f43fd63321530a00b3bb9217dd933  TestECDSA.java
```

</details>
<details><summary>2.2 Debian Distributions</summary>
</br>
To update the source files for each new Debian release, there are potentially 3 files that must be updated. These 3 files are ```changelog , control & rules``` ( located under _jdk_ / debian / src / main / packaging /_temurin_ / _21_) below are the files, and how to update them.


<h5>2.2.1 The changelog file (example below:)</h5>

When actioning a new release, or patching to an existing release, the changelog file should have an additional section added to the top of the file (the most recent change is at the head). The version number should be updated appropriately (e.g. 21.0.3.0.0+9) and then additionally the final element (-1) should be changed to be -0 for the first release, and then incremented by 1 for each subsequent release. In addition to the version number the release date and timestamps should also be updated.


```
temurin-21-jdk (21.0.3.0.0+9-1) STABLE; urgency=medium

  * Eclipse Temurin 21.0.3.0.0+9-1 release.

 -- Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org>  Wed, 17 Apr 2024 00:00:00 +0000
```

<h5>2.2.2 The rules file (example below:)</h5>

The second file that should be updated as part of a release is the Debian rules file. This contains the URLs of the binaries published to GitHub along with their checksum. It contains a pair of values (a tarball url, and a checksum) per architecture, and it is these values used to create the .deb packages.


Should a new architecture require support, the a new value pair should be added here in addition to the other changes.

```
pkg_name = temurin-21-jdk
priority = 2111
jvm_tools = jar jarsigner java javac javadoc javap jcmd jconsole jdb jdeprscan jdeps jfr jhsdb jimage jinfo jlink jmap jmod jpackage jps jrunscript jshell jstack jstat jstatd jwebserver keytool rmiregistry serialver jexec jspawnhelper
amd64_tarball_url = https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.3%2B9/OpenJDK21U-jdk_x64_linux_hotspot_21.0.3_9.tar.gz
amd64_checksum = fffa52c22d797b715a962e6c8d11ec7d79b90dd819b5bc51d62137ea4b22a340
arm64_tarball_url = https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.3%2B9/OpenJDK21U-jdk_aarch64_linux_hotspot_21.0.3_9.tar.gz
arm64_checksum = 7d3ab0e8eba95bd682cfda8041c6cb6fa21e09d0d9131316fd7c96c78969de31
ppc64el_tarball_url = https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.3%2B9/OpenJDK21U-jdk_ppc64le_linux_hotspot_21.0.3_9.tar.gz
ppc64el_checksum = 9a1079d7f0fc72951fdc9a0029e49a15f6ba114683aee626f882ee2c761f1d57
s390x_tarball_url = https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.3%2B9/OpenJDK21U-jdk_s390x_linux_hotspot_21.0.3_9.tar.gz
s390x_checksum = f57a078d417614e5d78c07c77a6d8a04701058cf692c8e2868d593582be92768
riscv64_tarball_url = https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.3%2B9/OpenJDK21U-jdk_riscv64_linux_hotspot_21.0.3_9.tar.gz
riscv64_checksum = 246acb1db3ef69a7e3328fa378513b2e606e64710626ae8dd29decc0e525359b
```

<h5>2.2.3 The control file (example below:)</h5>

The final file typically only requires updates if this is the first release of a new jdk, or alternatively if a new architecture is being added. 


In the event of a new architecture being added, the <b>Architecture</b> line should have the new value appended.

In the event that this is the first release of a new JDK version, then the <b>Provides</b> field should also be updated with the new values as appropriate.

```
Source: temurin-21-jdk
Section: java
Priority: optional
Maintainer: Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org>
Build-Depends: debhelper (>= 11), lsb-release

Package: temurin-21-jdk
Architecture: amd64 arm64 ppc64el s390x riscv64
Provides: 
java15-sdk-headless,
java16-sdk-headless,
java17-sdk-headless,
java18-sdk-headless,
java19-sdk-headless,
java2-sdk-headless,
java20-sdk-headless,
java21-sdk-headless,
```
</details>

<details><summary>2.3 RHEL/Suse Distributions</summary>
</br>
The process for updating the source files for both RHEL & Suse based distributions is identical. The source file that drives the build process for the produced rpm files is typically named like this <i>vendor-version-jdk</i>  ```temurin-21-jdk.spec``` ( located under _jdk_ / redhat / src / main / packaging / _temurin_ / _21_for example).  Details on how to update/amend the relevant sections of the spec file are below:

<h5>2.3.1 The header section(example below:)</h5>

This section requires updates to the following 2 fields:

<b>global spec version:</b></br> This field should be amended to the FULL version number of the release being processed, e.g , 21.0.3.0.0.9.
<b>global spec release:</b></br> This field should be reset to 0 for the first release of a package, and then incremented should there be patches or additional rebuilds of this package version. The first version should be 1. This will ultimately be appended to the final package name, e.g temurin-21-jdk-21.0.3.0.0.9-1. 

In the event that this is a new java major version release, the <b>global priority</b> should also be updated appropriately.


```
%global upstream_version 21.0.3+9
# Only [A-Za-z0-9.] allowed in version:
# https://docs.fedoraproject.org/en-US/packaging-guidelines/Versioning/#_upstream_uses_invalid_characters_in_the_version
# also not very intuitive:
#  $ rpmdev-vercmp 21.0.0.0.0___21.0.0.0.0+1
#  21.0.0.0.0___1 == 21.0.0.0.0+35
%global spec_version 21.0.3.0.0.9
%global spec_release 1
%global priority 1161
```
<h5>2.3.2 The footer/changelog section(example below:)</h5>

The second step in updating a RHEL/Suse spec for in preperation for release, involves adding a new section to the changelog, being sure to put it at the top of the list directly below <b>%changelog</b> and ensuring that the date, time and version numbers are updated appropriately, as shwon in the example below.

```
%changelog
* Wed Apr 17 2024 Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org> 21.0.3.0.0.9-1
- Eclipse Temurin 21.0.3+9 release.
```

<h5>2.3.3 JDK8 / Arm32 Specific Change</h5>

If you are updating the spec files for JDK8, for the arm32 platform there is an additional field which should be updated to match the upstream tag used to build the arm32 JDK.

```
# jdk8 arm32 has different top directory name https://github.com/adoptium/temurin-build/issues/2795
%global upstream_version 8u412-b08-aarch32-20240419
```

<h5>2.3.4 Adding a new supported architecture</h5>

In the event that a new architecture requires adding to the spec file, there are a number of changes that require adding,  firstly a new section should be added to the architecture mapping summary, as detailed blow, the additional architecture should be added as <b>%global vers_arch6 somenew</b> to ALL ifarch section, and both the <b>%global src_num</b> & <b>%global sha_src_num</b> should be incremented to be the next two values in the list, taking the list below as an example, the new values would be :<</br><b>%global src_num 10</b></br><b>%global sha_src_num 11</b>
</br>

The new section should be added prior to this section:

```
# Allow for noarch SRPM build
%ifarch noarch
%global src_num 0
%global sha_src_num 1
%endif
```

and should look something like this:

```
%ifarch somenew
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 aarch64
%global vers_arch4 s390x
%global vers_arch5 riscv64
%global vers_arch6 somenew
%global src_num 10
%global sha_src_num 11
%endif
```

<details>
<summary>Full Architectures Section</summary>
# Map architecture to the expected value in the download URL; Allow for a
# pre-defined value of vers_arch and use that if it's defined

%ifarch x86_64
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 aarch64
%global vers_arch4 s390x
%global vers_arch5 riscv64
%global src_num 0
%global sha_src_num 1
%endif
%ifarch ppc64le
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 aarch64
%global vers_arch4 s390x
%global vers_arch5 riscv64
%global src_num 2
%global sha_src_num 3
%endif
%ifarch aarch64
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 aarch64
%global vers_arch4 s390x
%global vers_arch5 riscv64
%global src_num 4
%global sha_src_num 5
%endif
%ifarch s390x
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 aarch64
%global vers_arch4 s390x
%global vers_arch5 riscv64
%global src_num 6
%global sha_src_num 7
%endif
%ifarch riscv64
%global vers_arch x64
%global vers_arch2 ppc64le
%global vers_arch3 aarch64
%global vers_arch4 s390x
%global vers_arch5 riscv64
%global src_num 8
%global sha_src_num 9
%endif
# Allow for noarch SRPM build
%ifarch noarch
%global src_num 0
%global sha_src_num 1
%endif
</details>
</br>

Once the additional section has been added above, the 2 new source files need adding to the list ( sources 10 & 11 in this example), and once again, a new section similar to the previous ones needs adding the section of the file detailed below. Note that the <b>vers_arch6</b> value represents the somenew architecture value added above and the <b>Source10</b> & <b>Source11</b> values have been added.

The section being added should be similar to this example:
```
# Sixth architecture (somenew)
Source10: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK21U-jdk_%{vers_arch6}_linux_hotspot_%{upstream_version_no_plus}.tar.gz
Source11: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK21U-jdk_%{vers_arch6}_linux_hotspot_%{upstream_version_no_plus}.tar.gz.sha256.txt
```

Finally the <b>ExclusiveArch</b> line in the file should also be extended, and should look similar to this:

```
ExclusiveArch: x86_64 ppc64le aarch64 s390x riscv64 somenew
```

<details>
<summary>Architectures To Process & Source Version Lines Example</summary>

```ExclusiveArch: x86_64 ppc64le aarch64 s390x riscv64 

# First architecture (x86_64)
Source0: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK21U-jdk_%{vers_arch}_linux_hotspot_%{upstream_version_no_plus}.tar.gz
Source1: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK21U-jdk_%{vers_arch}_linux_hotspot_%{upstream_version_no_plus}.tar.gz.sha256.txt
# Second architecture (ppc64le)
Source2: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK21U-jdk_%{vers_arch2}_linux_hotspot_%{upstream_version_no_plus}.tar.gz
Source3: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK21U-jdk_%{vers_arch2}_linux_hotspot_%{upstream_version_no_plus}.tar.gz.sha256.txt
# Third architecture (aarch64)
Source4: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK21U-jdk_%{vers_arch3}_linux_hotspot_%{upstream_version_no_plus}.tar.gz
Source5: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK21U-jdk_%{vers_arch3}_linux_hotspot_%{upstream_version_no_plus}.tar.gz.sha256.txt
# Fourth architecture (s390x)
Source6: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK21U-jdk_%{vers_arch4}_linux_hotspot_%{upstream_version_no_plus}.tar.gz
Source7: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK21U-jdk_%{vers_arch4}_linux_hotspot_%{upstream_version_no_plus}.tar.gz.sha256.txt
# Fifth architecture (riscv64)
Source8: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK21U-jdk_%{vers_arch5}_linux_hotspot_%{upstream_version_no_plus}.tar.gz
Source9: %{source_url_base}/jdk-%{upstream_version_url}/OpenJDK21U-jdk_%{vers_arch5}_linux_hotspot_%{upstream_version_no_plus}.tar.gz.sha256.txt
```
</details>
</details>


## 3. Adding/Removing An Additional Supported Distribution

Should a new version of a Debian, RHEL or Suse distribution require adding to the list of distributions we publish packages for or alternatively a distribution requires removing as it is no longer supported, there are a few changes required to the [jenkinsfile](https://github.com/adoptium/installer/blob/master/linux/Jenkinsfile) that drives the build and packaging process.

The versions of each specific distribution supported can be viewed can be found , by searching for the deb_versions variable (Debian), or the distro_Package variable for (RHEL & Suse). The table below shows the current supported versions, but this does change on a regular basis

<details>
<summary>Table Of Currently Supported Versions As Of 05/2024 </summary>
Supported Linux Distros:

Distribution Type| Supported Versions
----------|---------
Deb (Debian)| Trixie (Debian 13)<br>Bookworm (Debian 12)</br>Bullseye (Debian 11)<br>Noble (Ubuntu 24.04)</br>Jammy (Ubuntu 24.04)</br>Focal (Ubuntu 20.04)</br>Bionic (Ubuntu 18.04)
RPM (RHEL)| centos 7</br> rocky 8</br>RHEL7 , RHEL8 & RHEL9</br> Fedora 35, 36, 37, 38 ,39 , 40</br>Oracle Linux 7 & 8</br>Amazon Linux 2
RPM(SUSE) | Opensuse 15.3</br>Opensuse 15.4</br>Opensuse 15.5</br>SLES 12</br>SLES15
</details></br>

To add an additional RHEL/Suse simply add new entries to relevant array as shown below and the packaging process will automatically upload the packages to the relevant sections of artifactory as part of the release process.
```
def distro_Package = [
        'redhat' : [
            'rpm/centos/7',
            'rpm/rocky/8',
            'rpm/rhel/7',
            'rpm/rhel/8',
            'rpm/rhel/9',
            'rpm/fedora/35',
            'rpm/fedora/36',
            'rpm/fedora/37',
            'rpm/fedora/38',
            'rpm/fedora/39',
            'rpm/fedora/40',
            'rpm/oraclelinux/7',
            'rpm/oraclelinux/8',
            'rpm/amazonlinux/2'
        ],
        'suse'   : [
            'rpm/opensuse/15.3',
            'rpm/opensuse/15.4',
            'rpm/opensuse/15.5',
            'rpm/sles/12',
            'rpm/sles/15'
        ]
```
For Debian based distributions a similar process is required, firstly add the distribution into the relevant section of the jenkinsfile shown below. In addition to this addition though, the build script used for creating and testing the packages will also require updates, and additionally the cacerts package, that the JDK & JRE are dependent on will also need updating, this is a seperate process, but must be carried out ahead of publishing the packages. To find out how to do this, please see section 4 of this document. Below is an example of the Debian distributions from the jenkinsfile.

```
    def deb_versions = [
            "trixie", // Debian/13
            "bookworm", // Debian/12
            "bullseye", // Debian/11
            "buster",   // Debian/10
            "oracular", // Ubuntu/24.10 (STS)
            "noble",    // Ubuntu/24.04 (LTS)
            "jammy",    // Ubuntu/22.04 (LTS)
            "focal",    // Ubuntu/20.04 (LTS)
            "bionic"   // Ubuntu/18.04 (LTS)
    ]
```

In addition to the updates detailed above, it is also important to change the following 4 files to add the new distributions (or remove redundant distributions), in the 2 build scripts located below:

```
  linux/jdk/debian/src/main/packaging/build.sh
  linux/jre/debian/src/main/packaging/build.sh
```

the following line should be changed :

```
debVersionList="trixie bookworm bullseye oracular noble jammy focal bionic"
```

And similarly in the following two files

```
  linux/jdk/debian/src/packageTest/java/packaging/DebianFlavours.java
  linux/jre/debian/src/packageTest/java/packaging/DebianFlavours.java
```

The array needs to be updated to add or remove distributions as necessary as shown below:
```
	return Stream.of(
       	  Arguments.of("debian", "trixie"),   // Debian/13 (testing)
          Arguments.of("debian", "bookworm"), // Debian/12 (testing)
          Arguments.of("debian", "bullseye"), // Debian/11 (stable)
          Arguments.of("ubuntu", "oracular"), // Ubuntu/24.10 (STS)
          Arguments.of("ubuntu", "noble"),    // Ubuntu/24.04 (LTS)
          Arguments.of("ubuntu", "jammy"),    // Ubuntu/22.04 (LTS)
          Arguments.of("ubuntu", "focal"),    // Ubuntu/20.04 (LTS)
          Arguments.of("ubuntu", "bionic")    // Ubuntu/18.04 (LTS)
    );
```

## 4. Updating the Adoptium cacerts package

When adding new Debian based distribution support to the installer packages, it is vital to update the dependent cacerts packages. This is a prerequisite package that the JDK/JRE Debian packages require. Unlike the other installer packages the cacerts package is built and tested by a Github action, when the relevant source code files are changed and added to a PR. Once the PR with the necessary code changes, has built and been tested cleanly, the cacerts package will get automatically uploaded to the package repository when the PR is merged.

The changes to the source code involve updating the Github action and both the files involved in building the new package, and the files that perform the automated testing. The following sections will detail the changes required.

### 4.1 Updating the Github action.

To update the Github action the following file must be updated <b>.github/workflows/cacert-publish.yml.</b>

Simply add or remove the supported distributions to the <b>debVersionList</b> line as shown in the example below. Note that this uses the "codename" for each Debian & Ubuntu version.

```
- name: Upload deb file to Artifactory
        if: steps.check-deb.outputs.file_exists == 'false'
        run: |
          debVersionList=("bookworm" "bullseye" "buster" "oracular" "jammy" "focal" "bionic")
          for debVersion in "${debVersionList[@]}"; do
            distroList+="deb.distribution=${debVersion};"
          done
```

### 4.2 Updating the cacerts package build source.

There are 2 changes required in the build source files, when creating an update for the cacerts package, the first is to change the following file:
```
linux/ca-certificates/debian/build.gradle
```

Again, new distributions should be added or removed in the array.

```
def deb_versions = [
		"trixie",   // Debian/13
		"bookworm", // Debian/12
		"bullseye", // Debian/11
    "buster",   // Debian/10
		"oracular"  // Ubuntu/24.10 (STS)
		"noble",    // Ubuntu/24.04 (LTS)
		"jammy",    // Ubuntu/22.04 (LTS)
		"focal",    // Ubuntu/20.04 (LTS)
		"bionic"    // Ubuntu/18.04 (LTS)
]
```

The second change that is required is to the following file:

```
linux/ca-certificates/debian/src/main/packaging/debian/changelog
```
A new section should be added, at the top of the changelog file, and the version number (e.g <b>1.0.3-1</b>) should be updated appropriately, again for this example, the new version would expect to be <b>1.0.4-1</b> , with the <b>x.x.x</b>  element being the version number, with the <b>-x</b> element being the release number number.

```
adoptium-ca-certificates (1.0.3-1) STABLE; urgency=medium

  * Add Debian Trixie & Ubuntu Noble to the list of supported releases.

 -- Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org>  Thu, 25 April 2024 10:30:30 +0000
```

### 4.3 Updating the cacerts package test source.

In addition to the previous changes, the automated test source code also needs updating to reflect the new distributions, in the first file:

```
linux/ca-certificates/debian/src/packageTest/java/org/adoptium/cacertificates/AptOperationsTest.java
```

This file requires that the <b>.contains("Version: 1.0.4-1")</b> line be updated to reflect the new version number added to the <i>changelog</i> above.
```
result = runShell(container, "apt-cache show adoptium-ca-certificates");
			assertThat(result.getExitCode()).isEqualTo(0);
			assertThat(result.getStdout())
				.contains("Package: adoptium-ca-certificates")
				.contains("Version: 1.0.4-1")
				.contains("Priority: optional")
				.contains("Architecture: all")
				.contains("Status: install ok installed");
```

The other two files that require changing are detailed below:

```
linux/ca-certificates/debian/src/packageTest/java/org/adoptium/cacertificates/ChangesVerificationTest.java
```

```
	private static String[] versionsList = {
		  "trixie", // Debian/13
			"bookworm", // Debian/12
			"bullseye", // Debian/11
			"noble",    // Ubuntu/24.04 (LTS)
			"jammy",    // Ubuntu/22.04 (LTS)
			"focal",    // Ubuntu/20.04 (LTS)
			"bionic",   // Ubuntu/18.04 (LTS)
	};
```

```
linux/ca-certificates/debian/src/packageTest/java/org/adoptium/cacertificates/DebianFlavours.java
```

```
	return Stream.of(
	  Arguments.of("debian", "trixie"),   // Debian/13 (testing)
		Arguments.of("debian", "bookworm"), // Debian/12 (testing)
		Arguments.of("debian", "bullseye"), // Debian/11 (stable)
		Arguments.of("ubuntu", "noble"),    // Ubuntu/24.04 (LTS)
		Arguments.of("ubuntu", "jammy"),    // Ubuntu/22.04 (LTS)
		Arguments.of("ubuntu", "focal"),    // Ubuntu/20.04 (LTS)
		Arguments.of("ubuntu", "bionic")    // Ubuntu/18.04 (LTS)
	);
```

The change that is required to both these files is to update the array of arguments by adding/removing the new versions as appropriate.

For a specific example of these changes being made, see this PR : https://github.com/adoptium/installer/pull/868/files

When the PR is created it will perform the necessary builds and tests, and then once merged, the package should be uploaded to the package repository.

## Appendices
<details>
<summary><B>Appendix A Invalid Installer Job Combinations</B></summary>
The following architecture, version and platform combinations are considered invalid, and may error, or produce no output, these are considered invalid and unsupported version, architecture and platform combinations, the installer build process is designed to not produce artifacts for these combinations, but the list is included here as a reference:

JDK Version |Architecture |Distribution |Reason
----------|---------|----------|--------
8 | s390x | ALL | s390x is not a supported architecture for JDK8
8 & 11 | riscv64 | ALL | riscv64 is not a supported architecture for JDKs prior to version 17
8 , 11 & 17 | aarch64 | Alpine | Alpine linux is only supported on x64 for JDK versions prior to 21
21 & 22 | s390x, ppc64le, armv7l, armv7hl , riscv64 | Alpine | Alpine linux is only supported on x86_64 & aarch64 for JDK versions later than 21.
21 & 22 | armv7l & armv7hl | All | Arm32 bit is no longer supported for JDKs later than version 21
</details>