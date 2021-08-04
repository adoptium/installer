# Changelog for Temurin Windows installer

# Changelog
* All notable changes **impacting the users** will be documented in this file.
* Technical changes/build fix/rewrite will not be covered here for readability if the produced msi is not impacted.
* For more/technical changes or previous changes see [Commit History](https://github.com/AdoptOpenJDK/openjdk-installer/commits/master) 


The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

## 2021-02-23
### Changed
- Update IcedTea-Web to 1.8.6

## 2021-01-25
### Added
- This user oriented changelog is born [#143](https://github.com/AdoptOpenJDK/openjdk-installer/issues/143)

## 2021-01-25
### Added
- Windows Installer can package Alibaba Dragonwell [#280](https://github.com/AdoptOpenJDK/openjdk-installer/issues/280)

## 2020-12-16
### Added
- Windows Installer can package aarch64/arm64 JDK [#277](https://github.com/AdoptOpenJDK/openjdk-installer/issues/277)

## 2020-11-19
### Cleanup
- No more "-LTS" shown in the installer screen during setup [#261](https://github.com/AdoptOpenJDK/openjdk-installer/issues/261)

## 2020-11-10
### Fixed / Changed
- Enable 5 version string components instead of 4 (add patch number) [#258](https://github.com/AdoptOpenJDK/openjdk-installer/issues/258)
  Windows installer use only the 4st

## 2019-07-25
### Fixed
- jvm.dll location has changed for Windows X86-32 Hotspot from bin/server to bin/client [#137](https://github.com/AdoptOpenJDK/openjdk-installer/issues/137) [#139](https://github.com/AdoptOpenJDK/openjdk-installer/issues/139)
- Conditional feature JavaSoft not detected properly [#123](https://github.com/AdoptOpenJDK/openjdk-installer/issues/123) [#138](https://github.com/AdoptOpenJDK/openjdk-installer/issues/138) 

## 2019-07-15
### Fixed
- Windows installer content type register entry [#119](https://github.com/AdoptOpenJDK/openjdk-installer/issues/119) [#135](https://github.com/AdoptOpenJDK/openjdk-installer/issues/135)

## 2019-05-24
### Removed
- Only add icedtea-web to jdk8 msi installer [#121](https://github.com/AdoptOpenJDK/openjdk-installer/issues/121)

## 2019-05-21
### Removed
- Disable ITW for x86_32 [#115](https://github.com/AdoptOpenJDK/openjdk-installer/issues/115)

## 2019-05-13
### Added
- Add IcedTea-Web as an optional part of the install [#87](https://github.com/AdoptOpenJDK/openjdk-installer/issues/87)

## 2019-05-09
### Added
- enable capability to install per user + doc [#107](https://github.com/AdoptOpenJDK/openjdk-installer/issues/107) [#103](https://github.com/AdoptOpenJDK/openjdk-installer/issues/103)

## 2019-04-15
### Added
- Provide Oracle JDK compatible registry keys (Windows) [#64](https://github.com/AdoptOpenJDK/openjdk-installer/issues/64)

## 2019-03-19
### Added
- [MSI] Set option for keeping same UpgradeCode [#59](https://github.com/AdoptOpenJDK/openjdk-installer/issues/59)

## 2019-03-15
### Fixed
- add hostpot or openj9 to install folder and reg key [#58](https://github.com/AdoptOpenJDK/openjdk-installer/issues/58) [#73](https://github.com/AdoptOpenJDK/openjdk-installer/issues/73)

## 2019-02-26
### Changed
- Replace JRE_HOME with JAVA_HOME [#56](https://github.com/AdoptOpenJDK/openjdk-installer/issues/56)

## 2019-02-13
### Fixed
- Fix environment variables [#44](https://github.com/AdoptOpenJDK/openjdk-installer/issues/44)

## 2019-02-11
- Double-click on JAR doesn't launch the application [#32](https://github.com/AdoptOpenJDK/openjdk-installer/issues/32) [#34](https://github.com/AdoptOpenJDK/openjdk-installer/issues/34)

## 2018-11-14
### Fixed
- Fix incorrect JAVA_HOME path [#23](https://github.com/AdoptOpenJDK/openjdk-installer/issues/23)
