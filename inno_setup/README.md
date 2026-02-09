# Introduction
This tool is designed to create EXE files which are modern and accessibility-friendly. This EXE format provides a reliable and user-friendly installation experience, including a graphical installer interface that achieves the highest standards for accessibility. When installed, the folder `jdk-${ExeProductVersion}-${JVM}` is placed at `C:\Program Files\${Vendor}\` (for machine-wide installs), or `C:\Users\${env:USERNAME}\AppData\Local\Programs\${Vendor}\` (for user installs).

# How to create EXE files

## Dependencies
The following files are required in order to successfully run `CreateExe.ps1`.
- Inno Setup:
  - Main download page: https://jrsoftware.org/isdl.php
  - Direct download link: https://jrsoftware.org/download.php/is.exe?site=1
  - Note: by default, the compiler is downloaded to the path `C:\Program Files (x86)\Inno Setup 6\ISCC.exe`. If Inno Setup is installed to another path, you will need to set `$env:INNO_SETUP_PATH` to this new path.

## Creating EXE files through CreateExe.ps1
Please take a look at the [Dependencies](#dependencies) section above to make sure that you have everything needed in order to run our `CreateExe.ps1` script successfully. In this section, you will find a few examples for how to run our script from a powershell terminal.

For more information on each variable, use the `powershell` command `Get-Help -Detailed .\CreateExe.ps1` or see the `powershell` style header within `inno_setup\CreateExe.ps1`

**First Example**: Running with all required + optional inputs. Below, you will see the inputs divided into sections: required, optional with a default value (shown below), and optional + changes behavior if omitted. This example builds an Eclipse Temurin EXE file for jdk `21.0.8+9`
```powershell
    .\CreateExe.ps1 `
        # Mandatory inputs
        -ZipFileUrl "https://example.com/file.zip" ` # You can use either ZipFileUrl or ZipFilePath, not both
        -ProductMajorVersion 21 `
        -ProductMinorVersion 0 `
        -ProductMaintenanceVersion 8 `
        -ProductPatchVersion 0 `
        -ProductBuildNumber 9 `
        -ExeProductVersion "21.0.8.9" `
        -Arch "aarch64" `
        -JVM "hotspot" `
        -ProductCategory "jdk" `
        # Optional inputs: These are the defaults that will be used if not specified
        -AppName "Eclipse Temurin JDK with Hotspot 21.0.8+9 (aarch64)" `
        -Vendor "Eclipse Adoptium" `
        -VendorBranding "Eclipse Temurin" `
        -VendorBrandingLogo "logos\logo.ico" `
        -VendorBrandingDialog "logos\welcome-dialog.png" `
        -VendorBrandingSmallIcon "logos\logo-small.png" `
        -ProductPublisherLink "https://adoptium.net" `
        -ProductSupportLink "https://adoptium.net/support" `
        -ProductUpdateInfoLink "https://adoptium.net/temurin/releases" `
        -OutputFileName "OpenJDK21-jdk_aarch64_windows_hotspot-21.0.8.0.9" `
        -License "licenses/license-GPLv2+CE.en-us.rtf" `
        -UpgradeCodeSeed "MySecretSeedCode(SameAsWix)" `
        -TranslationFile "translations/default.iss" `
        # Additional Optional Inputs: Omitting these inputs will cause their associated process to be skipped
        -IncludeUnofficialTranslations "true" `
        -SigningCommand "signtool.exe sign /f C:\path\to\cert" # For more explanation, see: https://jrsoftware.org/ishelp/index.php?topic=setup_signtool
```

**Second Example**: Running with only required inputs. This will produce an EXE file, but many values (ex: OutputFileName) will take the default Eclipse/Adoptium value. Note: either `-ZipFilePath` or `-ZipFileUrl` are required inputs, but you cannot specify both. This example builds an Eclipse Temurin EXE file for jdk `17.0.16+8`
```powershell
.\CreateExe.ps1 `
    -ZipFilePath "C:\path\to\file.zip" ` # You can use either ZipFileUrl or ZipFilePath, not both
    -ProductMajorVersion 17 `
    -ProductMinorVersion 0 `
    -ProductMaintenanceVersion 16 `
    -ProductPatchVersion 0 `
    -ProductBuildNumber 8 `
    -ExeProductVersion "17.0.16.8" `
    -Arch "x64" `
    -JVM "hotspot" `
    -ProductCategory "jdk"
```

### Sign EXE file
Here you can either sign during compilation (recommended) or after compilation. To sign during compilation, you will need to pass in a formatted CLI command as the value to the `SigningCommand` variable when running `CreateExe.ps1`. <u>Signing during compilation is recommended</u> as it is the only way to ensure that the uninstall script (packaged within the EXE) is also signed by you. For more information on how to format the input to `SigningCommand`, see: https://jrsoftware.org/ishelp/index.php?topic=setup_signtool

While not recommended, you can choose not to use the `SigningCommand` input and instead manually sign the resulting EXE file after compilation is completed.

> [!WARNING]
> If you do not use the `SigningCommand` to sign during compilation, then the uninstall script (packaged within your EXE) will not be signed. In this case, if the user attempts to uninstall your OpenJDK, they will be warned that they are about to run a program from an unknown vendor.


Example input to `SigningCommand`:
```powershell
-SigningCommand signtool.exe sign /a /n $qMy Common Name$q /t http://timestamp.comodoca.com/authenticode /d $qMy Program$q $f
```

# Using EXE files

## Install using EXE file
To install via UI, simply double-click on the EXE installer file and follow the instructions in the setup wizard.

To install via CLI, follow these steps:
1. Choose the features you want to install from the following table:

   | Feature                 | Description                                              |
   |-------------------------|----------------------------------------------------------|
   | `FeatureEnvironment`    | Update the `PATH` environment variable. (DEFAULT)        |
   | `FeatureJarFileRunWith` | Associate *.jar* files with Java applications. (DEFAULT) |
   | `FeatureJavaHome`       | Update the `JAVA_HOME` environment variable.             |
   | `FeatureOracleJavaSoft` | Updates registry keys `HKLM\SOFTWARE\JavaSoft\`.         |

   > [!NOTE]
   > You can use `FeatureOracleJavaSoft` to prevent Oracle Java from launching from PATH when the Microsoft Build of OpenJDK is uninstalled. Reinstall Oracle Java if you need to restore the Oracle registry keys.

2. Run the EXE file from the command line. Use the selected features, as shown in the following example.

   ```cmd
   .\<package>.exe /SILENT /SUPPRESSMSGBOXES /ALLUSERS /TASKS="FeatureEnvironment,FeatureJarFileRunWith" /DIR="C:\Program Files\Microsoft\"
   ```

   > [!NOTE]
   > If installing for only the current user, use the flag `/CURRENTUSER` instead of `/ALLUSERS`.
   >
   > To suppress the progress bar screen of the installation, use the flag `/VERYSILENT` instead of `/SILENT`.
   >
   > The `/DIR` flag is optional. If omitted, the default installation directory is used based on the installation mode: `/ALLUSERS` or `/CURRENTUSER`.

## Uninstall EXE file
To uninstall the OpenJDK, open your Windows settings and navigate to `Apps > Installed Apps`. Search for the name of the OpenJDK that was installed. Once located, click on the `...` on the right-hand side of the entry and select `Uninstall` from the dropdown menu. A UI uninstaller will appear; follow the remaining instructions.
