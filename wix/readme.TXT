Requirements for build environment:
===================================

1. Windows Installer XML (WiX) toolset, 3.6 or later, http://wixtoolset.org/releases/
2. Windows SDK for building multi-lingual setups (optional).
3. Digital signature service if the MSI should be signed (optional).


How to upgrade to a new Skype Version:
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
  SET OPENJ9_VERSION=0.9.0
  SET WIN_SDK_VERSION=8.1
 
4. Run "Build.cmd" to create the MSI setup in "ReleaseDir".

  - Build.OpenJDKxx.cmd
      If both versions can be build at the same time.
  - Build.OpenJDKxx.withEclipseOpenJ9.cmd
      If OpenJDK need to be build with Eclipse OpenJ9 only.
  - Build.OpenJDKxx.withHotspot.cmd
      If OpenJDK need to be build with Hotspot only.

5. Deploy via Active Directory GPO.
