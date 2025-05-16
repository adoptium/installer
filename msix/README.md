# Introduction
This tool is designed to create MSIX files, the modern installer format supported by Microsoft for Windows applications. MSIX packages provide a reliable, secure, and user-friendly installation experience, including a graphical installer interface that achieves the highest standards for accessibility. When installed, java.exe is placed at `C:\Users\${env:USERNAME}\AppData\Local\${Vendor}\WindowsApps` and the rest of the binary files are downloaded to: `C:\Program Files\WindowsApps\<FULL_PACKAGE_NAME_WITH_ID>` (See [this section](#check-info-of-installed-msix) to see how to get the package ful name). MSIX is also the required package type for distributing applications through the Microsoft Store.

Note: Users must be on `Windows 7 SP1 (Build 7601)` or higher to install from `.msix` files. Windows users on versions prior to `Windows 10 version 1809` may need to enable sideloading in order for this installer format to work on their machine. If you are using a computer with an earlier version, you will need to enable sideloading to use `.msix` files:
1. Navigate to `Settings` > `Update & Security` > `For Developers`
1. Select `Sideload apps`
1. Restart if prompted

If you are on Windows `7` or `8.1`, you will also need to install `MSIX Core` to enable MSIX package installation. Documentation on `MSIX Core` and links to the latest release can be found here: https://learn.microsoft.com/en-us/windows/msix/msix-core/msixcore

# How to create MSIX files

## Dependencies
The following files are required in order to successfully run `CreateMsix.ps1`. These files can be found within the `Windows Kits` section of the `Windows SDK` directory.
- `makepri.exe`
- `makeappx.exe`
- `signtool.exe`

When running the `CreateMsix.ps1`, you will need to check which version(s) of the `Windows SDK` are installed. If you want to use a version other than `10.0.22621.0`, please set the following environment variables:
- `$Env:WIN_SDK_FULL_VERSION=<YOUR_VS_VERSION>` # (Default: 10.0.22621.0)
- `$Env:WIN_SDK_MAJOR_VERSION=<YOUR_MAJOR_VS_VERSION>` # (Default: 10)

In order to run the commands below, you may need to add the `bin` directory of the `Windows Kits` section of the Windows SDK. We currently default to using `10.0.22621.0`, so the default path that we use in the script is: `C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64` (here, the `10` is the `WIN_SDK_MAJOR_VERSION`).

## Creating MSIX files through CreateMsix.ps1
Please take a look at the [Dependencies](#dependencies) section above to make sure that you have everything needed in order to run our `CreateMsix.ps1` script successfully. In this section, you will find a few examples for how to run our script from a powershell terminal.

For more information on each variable, use the `powershell` command `Get-Help -Detailed .\CreateMsix.ps1` or see the `powershell` style header within `msix/CreateMsix.ps1`

IMPORTANT: Make sure to set the `-PackageName`, as this needs to be consistent between releases for upgrades to work as expected. This also dictates the output file's name (which becomes `$PackageName.msix`)

**First Example**: Running with all required + optional inputs. Below, you will see the inputs divided into sections: required, optional with a default value (shown below), and optional + changes behavior if omitted. This example builds an Eclipse Temurin msix file for jdk `21.0.7+6`
```powershell
.\CreateMsix.ps1 `
    # Mandatory inputs
    -ZipFileUrl "https://example.com/file.zip" `
    -PackageName "OpenJDK21U-jdk-x64-windows-hotspot" ` # Cannot contain spaces or underscores
    -PublisherCN "ExamplePublisher" `   # everything on the right side of your `CN=` field in your .pfx file.
    -ProductMajorVersion 21 `
    -ProductMinorVersion 0 `
    -ProductMaintenanceVersion 7 `
    -ProductBuildNumber 6 `
    -Arch "aarch64" `
    # Optional inputs: These are the defaults that will be used if not specified
    -Vendor "Eclipse Adoptium" `
    -VendorBranding "Eclipse Temurin" `     # Only determines default values for $MsixDisplayName and $Description, unused if those both provided
    -MsixDisplayName "Eclipse Temurin 21.0.7+6 (x64)" `
    -OutputFileName "OpenJDK21U-jdk_x64_windows_hotspot_21.0.7_6.msix" `
    -Description "Eclipse Temurini using license: https://www.gnu.org/licenses/old-licenses/lgpl-2.0.html" `        # Example: "Eclipse Temurin Development Kit with Hotspot"
    # Optional Inputs: omitting these inputs will cause their associated process to be skipped
    -SigningCertPath "C:\path\to\cert.pfx"  # Used to sign with signtool.exe, typically .pfx file
    -SigningPassword "your cert's password"
    -License "https://www.gnu.org/licenses/old-licenses/lgpl-2.0.html"  # The URL to the license file.
    -VerboseTools   # Sets Windows SDK tools to verbose output
```

**Second Example**: Running with only required inputs. This will produce an MSIX file, but many values (ex: MsixDisplayName) will take the default Eclipse/Adoptium value. Note: either `-ZipFilePath` or `-ZipFileUrl` are required inputs, but you cannot specify both. This example builds an Eclipse Temurin msix file for jdk `17.0.15+6`
```powershell
.\CreateMsix.ps1 `
    -ZipFilePath "C:\path\to\file.zip" `
    -PackageName "OpenJDK17U-jdk-x64-windows-hotspot" ` # Cannot contain spaces or underscores
    -PublisherCN "ExamplePublisher" `   # everything on the right side of your `CN=` field in your .pfx file.
    -ProductMajorVersion 17 `
    -ProductMinorVersion 0 `
    -ProductMaintenanceVersion 15 `
    -ProductBuildNumber 6 `
    -Arch "x64" `
```
## Creating MSIX Files Manually
Here, much of the work comes from ensuring that the `AppXManifest.xml` file contains the correct configuration parameters. If you would like to manually build your `msix` files, you can follow the commands in the sections below after:
1. Copying `msix/templates/pri_config.xml` to your project root
2. Creating `AppXManifest.xml` in your project root (you may find that our template file at `msix/templates/AppXManifestTemplate.xml` will be a good place to start)
3. Following the instructions in the [Dependencies](#dependencies) section

### Make resources.pri file (Needed for MSIX creation)
Assumptions:
- There is a file in the `/pr` (project root) directory called `AppXManifest.xml`
    - If not, please specify the `/mn` flag and set the path to your manifest xml file. This will create the `.pri` file that we need to create `.msix` files
- The bin `bin` of the `Windows Kits` section of the `Windows SDK` directory is added to your path.
    - We currently default to using `10.0.22621.0`, so the default path that we use in the script is: `C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64`
    - Alternative: each command can be run by specifying the full path to the file.  Example: `C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\makepri.exe`
```powershell
makepri.exe new `
    /o `
    /pr "C:\path\to\your\project\root\dir" `
    /cf "C:\path\to\pri\config.xml" `
    /of "C:\output_filename.pri" `
    /mf appx
```

### Make .msix file
Now, we will use the generated `.pri` file to create our `.msix` file
```powershell
makeappx.exe pack `
    /o `
    /d "C:\path\to\your\content\directory" `
    /p "output_filename.msix"
```

### Sign MSIX file
Notes
- See [this page](https://learn.microsoft.com/en-us/windows/win32/appxpkg/how-to-create-a-package-signing-certificate) for help on creating your .pfx file
- You will also need to add your cert to your list of trusted publishers
- Windows will not allow you to install an unsigned MSIX file, even in developer mode
  - ie: the step above is mandatory for testing new `msix` files made locally, even if they are not intended to be published
```powershell
signtool.exe sign `
    /fd SHA256 `
    /a `
    /f "C:\path\to\your\certfile.pfx" `
    /p "your_pfx_file_password" `
    your_package_file.msix
```

# Using MSIX files
Note: These commands must be run from a terminal with administrator privileges

## Install using MSIX file
- If your `.msix` file was signed with a certificate trusted by Microsoft, you should be able to double-click it and install it via the GUI.
- If it was signed by a certificate trusted only by the local computer, you need to run the PowerShell command below from a terminal with administrator privileges
- If your `.msix` file is not signed, you will not be able to install it (even if your machine is in developer mode)
```powershell
Add-AppPackage -Path C:\path\to\msix\file.msix -AllowUnsigned -verbose
```

## Check info of installed MSIX
Get info on all packages installed via MSIX:
```powershell
Get-AppPackage -AllUsers | Select Name, PackageFullName
```

Narrow down the information to only packages containing the substring `jdk`:
```powershell
Get-AppPackage -AllUsers | Select Name, PackageFullName | Select-String -Pattern "jdk"
```

Get more detailed information on a specific MSIX package:
```powershell
Get-AppPackage -Name "package-name"
```

## Uninstall MSIX
```powershell
Remove-AppPackage -AllUsers -package "package-full-name"
```
Note: The `package-full-name` must appear as it does in the `PackageFullName` attribute found via `Get-AppPackage`, including the package_ID at the end