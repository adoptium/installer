## Requirements for build environment:

1. Windows Installer XML (WiX) toolset, 3.11 or later, http://wixtoolset.org/releases/
2. Install "Windows SDK for Desktop C++ amd64 Apps" feature from Windows SDK 10 (https://developer.microsoft.com/en-us/windows/downloads/windows-10-sdk) for building multi-lingual setups.
3. Digital signature service if the MSI should be signed (optional). If you plan to sign the MSI, you need to install the Windows SDK 10 feature "Windows SDK Signing Tools for Desktops Apps".
4. For reviewing the MSI setup or creating custom MST transforms you can install feature "MSI Tools" from Windows SDK 10 (optional).


## How to upgrade to a new OpenJDK version:

1. Download latest OpenJDK zip into `openjdk-installer\wix\SourceDir\`

2. Run CreateSourceFolder.AdoptOpenJDK.ps1 to unzip and rename.

3. SET all the variables below in `build.cmd.sample` and rename to `build.cmd` and run:

  Example:
  ```batch
  SET PRODUCT_MAJOR_VERSION=11
  SET PRODUCT_MINOR_VERSION=0
  SET PRODUCT_MAINTENANCE_VERSION=2
  SET PRODUCT_PATCH_VERSION=8
  SET ARCH=x64
  SET JVM=openj9
  SET PRODUCT_CATEGORY=jdk
  cmd /c Build.OpenJDK_generic.cmd
  ```

 `Build.OpenJDK_generic.cmd` statically depend on this SDK version (edit if needed ):
  ```batch
  SET WIN_SDK_MAJOR_VERSION=10
  SET WIN_SDK_FULL_VERSION=10.0.17763.0
  ```

4. Run `Build.OpenJDK_generic.cmd` to create the MSI setup in "ReleaseDir".

5. Deploy via Active Directory GPO.

   5a. Installation optional parameters:
   	INSTALLLEVEL
   		1 = (Add to PATH + Associate jar)
   		2 = (Add to PATH + Associate jar) + define JAVA_HOME
   		usage sample: 
   		msiexec /i OpenJDK8-jdk_xxx.msi INSTALLLEVEL=1
   		msiexec /i OpenJDK8-jdk_xxx.msi INSTALLLEVEL=2
   		

	Features available:
		FeatureEnvironment ( PATH )
		FeatureJavaHome (JAVA_HOME)
		FeatureJarFileRunWith (associate .jar)
		
		usage sample:
		msiexec /i OpenJDK8-jdk_xxx.msi ADDLOCAL=FeatureJavaHome,FeatureJarFileRunWith

