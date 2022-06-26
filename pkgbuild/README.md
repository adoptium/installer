# pkgbuild mac installers

## Prerequisites

The generation of the OpenJDK installer depends on an open-source utility tool [Packages](http://s.sudre.free.fr/Software/Packages/about.html).
The application must be installed before running the installer generation task.

```bash
brew install --cask packages
```

## Example Usage

```bash
./packagesbuild.sh --major_version 17 --full_version 17.0.3_7 --input_directory /path/to/jdk --output_directory OpenJDK17U-jdk_x64_mac_hotspot_17.0.3_7.pkg --jvm hotspot --architecture x86_64 --type jdk
```

## Sign the installer

```bash
--sign <certificate name>
```
