## Requirements for build environment:

1. Windows Installer XML (WiX) toolset, 3.11 or later, http://wixtoolset.org/releases/
2. Install "Windows SDK for Desktop C++ amd64 Apps" feature from Windows SDK 10 (https://developer.microsoft.com/en-us/windows/downloads/windows-10-sdk) for building multi-lingual setups.
3. Digital signature service if the MSI should be signed (optional). If you plan to sign the MSI, you need to install the Windows SDK 10 feature "Windows SDK Signing Tools for Desktops Apps".
4. For reviewing the MSI setup or creating custom MST transforms you can install feature "MSI Tools" from Windows SDK 10 (optional).


## How to upgrade to a new OpenJDK version:

1. Download latest OpenJDK zip.

2. Extract the content.

3. Edit `Build.*.cmd` and change below version lines:

  Example:
  ```batch
  SET PRODUCT_MAJOR_VERSION=11
  SET PRODUCT_MINOR_VERSION=0
  SET PRODUCT_MAINTENANCE_VERSION=0
  SET PRODUCT_PATCH_VERSION=28
  ```

  Depends on usage:
  ```batch
  SET WIN_SDK_MAJOR_VERSION=10
  SET WIN_SDK_FULL_VERSION=10.0.17763.0
  ```
 
4. Run "Build*.cmd" to create the MSI setup in "ReleaseDir".

  - `Build.OpenJDKxx.jdk_x64_windows_hotspot.cmd`
      If Java Development Kit need to be build with Hotspot only.
  - `Build.OpenJDKxx.jdk_x64_windows_openj9.cmd`
      If Java Development Kit need to be build with Eclipse OpenJ9 only.
  - `Build.OpenJDKxx.jre_x64_windows_hotspot.cmd`
      If Java Runtime Environment need to be build with Hotspot only.
  - `Build.OpenJDKxx.jre_x64_windows_openj9.cmd`
      If Java Runtime Environment need to be build with Eclipse OpenJ9 only.

5. Deploy via Active Directory GPO.
