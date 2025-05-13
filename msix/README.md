# How to create MSIX files

## Make resources.pri file (Needed for MSIX creation)
```shell
MakePri.exe new /o /pr C:\path\to\your\project\root\dir /cf C:\path\to\pri\config.xml /of C:\output_filename.pri /mf appx
```
Note: This assumes you have a file in your `/pr` directory called AppXManifest.xml. If not, you will need to specify the `/mn` flag and set the path to your manifest xml file

## Make .msix file 
```shell
makeappx.exe pack /o /d C:\path\to\your\content\directory /p "output_filename.msix"
```

## Sign MSIX file
Notes
- See [this page](https://learn.microsoft.com/en-us/windows/win32/appxpkg/how-to-create-a-package-signing-certificate) for help on creating your .pfx file
- You will also need to add your cert to your list of trusted publishers
- Windows will not let you install from an unsigned MSIX file, even in developer mode
```shell
signtool.exe sign /fd SHA256 /a /f C:\path\to\your\certfile.pfx /p "your_pfx_file_password" your_package_file.msix
```

# Install, get info, and uninstall
Note: Must be run from a terminal with administrator privileges]

## Install from msix file
```shell
Add-AppPackage -Path C:\path\to\msix\file.msix -AllowUnsigned -verbose
```

## Check info of insallted MSIX
Get info on all packages installed via MSIX:
```shell
Get-AppPackage -AllUsers | Select Name, PackageFullName
```

Narrow down info to just packages containing the substring `jdk`:
```shell
Get-AppPackage -AllUsers | Select Name, PackageFullName | Select-String -Pattern "jdk"
```

Get more detailed information on a specific MSIX package:
```shell
Get-AppPackage -Name "package-name"
```

## Uninstall MSIX
```shell
Remove-AppPackage -AllUsers -package "package-full-name"
```
Note: The "package-full-name" must appear as it does in the `PackageFullName` attribute found via `Get-AppPackage`, including the package_ID at the end