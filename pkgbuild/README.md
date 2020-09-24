# pkgbuild mac installers

## Prerequisites

The generation of the OpenJDK installer depends on an open-source utility tool [Packages](http://s.sudre.free.fr/Software/Packages/about.html).
The application must be installed before running the installer generation task.

```bash
brew cask install packages
```

## Example Usage

```bash
./packagesbuild.sh --major_version 8 --full_version 1.8.0_192 --input_directory /path/to/jdk --output_directory OpenJDK8U-jdk_x64_mac_hotspot_8u181b13.pkg --jvm hotspot --type jdk
```

## Sign the installer

```bash
--sign <certificate name>
```
