Requirements for build environment:
===================================

1. Windows Installer XML (WiX) toolset, 3.11 or later, http://wixtoolset.org/releases/
2. "MSI Tools" feature from Windows SDK (https://developer.microsoft.com/en-us/windows/downloads/windows-10-sdk) for building multi-lingual setups.
3. Digital signature service if the MSI should be signed (optional).


How to upgrade to a new OpenJDK version:
========================================

1. Download latest OpenJDK zip.

2. Extract the content.

3. Edit Build.*.cmd and change below version lines:

  Example:
  SET PRODUCT_MAJOR_VERSION=10
  SET PRODUCT_MINOR_VERSION=0
  SET PRODUCT_MAINTENANCE_VERSION=2
  SET PRODUCT_PATCH_VERSION=13

  Depends on usage:
  SET WIN_SDK_VERSION=8.1
 
4. Run "Build*.cmd" to create the MSI setup in "ReleaseDir".

  - Build.OpenJDKxx.jdk_x64_windows_openj9.cmd
      If OpenJDK need to be build with Eclipse OpenJ9 only.
  - Build.OpenJDKxx.jdk_x64_windows_hotspot.cmd
      If OpenJDK need to be build with Hotspot only.

5. Deploy via Active Directory GPO.
