# How to create MSIX files

## Dependencies
The following files are required in order to successfully run `CreateMsix.ps1`. These files can be found within the `Windows Kits` section of `Visual Studio` installation directories.
- `makepri.exe`
- `makeappx.exe`
- `signtool.exe`

If you are running the `CreateMsix.ps1` and have all files available, you will need to check which version(s) of `Visual Studio` or `Windows SDK` you have installed. If you want to use a version other than `10.0.22621.0`, you will need to set the following environment variables:
- `$Env:WIN_SDK_FULL_VERSION=<YOUR_VS_VERSION>` # (Default: 10.0.22621.0)
- `$Env:WIN_SDK_MAJOR_VERSION=<YOUR_MAJOR_VS_VERSION>` # (Default: 10)

In order to run the commands below, you may need to add the `bin` of the `Windows Kits` section of your `Visual Studio` or `Windows SDK` installation directory. We currently default to using `10.0.22621.0`, so the path that we use in the script is: `C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64` (here, the `10` is the `WIN_SDK_MAJOR_VERSION`).

## Creating MSIX files through CreateMsix.ps1
Please take a look at the [Dependencies](#dependencies) section above to make sure that you have everything needed in order to run our `CreateMsix.ps1` script successfully. In this section, you will find a few examples for how to run our script from a powershell terminal. For more information on each variable, see the `powershell` style header within `msix/CreateMsix.ps1`

IMPORTANT: make sure to set the `-PackageName` since this needs to be consistent between releases for upgrades to work as expected. This also dictates the output file's name (which becomes `$PackageName.msix`)

*First Example*: Running with only required inputs. This will produce an MSIX file, but many values (ex: DisplayName) will take the default Eclipse/Temurin value. Note: either `-ZipFilePath` or `-ZipFileUrl` are required inputs, but you cannot specify both. This example builds an Eclipse Temurin msix for jdk `17.0.15+6`
```powershell
.\CreateMsix.ps1 `
    -ZipFilePath "C:\path\to\file.zip" `
    -PackageName "OpenJDK17U-jdk-x64-windows-hotspot" `
    -PublisherCN "ExamplePublisher" `
    -ProductMajorVersion 17 `
    -ProductMinorVersion 0 `
    -ProductMaintenanceVersion 15 `
    -ProductBuildNumber 6 `
    -Arch "x64" `
```

*Second Option*: Running with all required + optional inputs. Below, you will see the inputs divided into sections: required, optional with a default value (shown below), optional + changes behavior if omitted. This example builds an Eclipse Temurin msix for jdk `21.0.7+6`
```powershell
.\CreateMsix.ps1 `
    # Mandatory inputs
    -ZipFileUrl "https://example.com/file.zip" `
    -PackageName "OpenJDK21U-jdk-x64-windows-hotspot" `
    -PublisherCN "ExamplePublisher" `
    -ProductMajorVersion 21 `
    -ProductMinorVersion 0 `
    -ProductMaintenanceVersion 7 `
    -ProductBuildNumber 6 `
    -Arch "aarch64" `
    # Optional inputs: These are the defaults that will be used if not specified
    -Vendor "Eclipse Adoptium" `
    -VendorBranding "Eclipse Temurin" `
    -MsixDisplayName "Eclipse Temurin 17.0.15+6 (x64)" `
    -Description "Eclipse Temurin" `                        # Example: "Eclipse Temurin Development Kit with Hotspot"
    # Optional Inputs: omitting these inputs will cause their associated process to be skipped
    -SigningCertPath "C:\path\to\cert.pfx"                  # Used to sign with signtool.exe, typically .pfx file
    -SigningPassword "your cert's password"
    -OutputFileName "OpenJDK21U-jdk_x64_windows_hotspot_21.0.7_6.msix" `
    -VerboseOutput                                          # Keeps $global:ProgressPreference at original value (if not verbose, this value is set to 'SilentlyContinue' which increases the speed of unzipping binaries)
```
## Creating MSIX Files Manually
If you would like to create MSIX files manually, there are not that many powershell commands to run. A good amount of the work comes from ensuring that the `AppXManifest.xml` file contains the correct configuration parameters. If you would like to manually build your `msix` files, then you can follow the commands in the sections below after:
1. Copying `msix/templates/pri_config.xml` to your project root
2. Creating `AppXManifest.xml` in your project root (you may find that our template file at `msix/templates/AppXManifestTemplate.xml` will be a good place to start)
3. Following the instructions in the [Dependencies](#dependencies) section

### Make resources.pri file (Needed for MSIX creation)
Note: This assumes you have a file in your `/pr` (project root) directory called `AppXManifest.xml`. If not, you will need to specify the `/mn` flag and set the path to your manifest xml file. This will create the `.pri` file that we need to create `.msix` files
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
- Windows will not let you install from an unsigned MSIX file, even in developer mode
  - ie: the step above is mandatory for testing new `msix` files made locally, even if it is not intended to be published
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
- If your `.msix` file was signed with a cert that is trusted by Microsoft, then you should be able to double click it and install via the GUI.
- If it was signed by a cert that is only trusted by the local computer, you will need to run the powershell command below from a terminal with admin privileges
- If your `.msix` file was not signed at all, you will not be able to install from it (even if your machine is in developer mode)
```powershell
Add-AppPackage -Path C:\path\to\msix\file.msix -AllowUnsigned -verbose
```

## Check info of installed MSIX
Get info on all packages installed via MSIX:
```powershell
Get-AppPackage -AllUsers | Select Name, PackageFullName
```

Narrow down info to just packages containing the substring `jdk`:
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