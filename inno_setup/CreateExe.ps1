<#
.SYNOPSIS
    Script to handle a zip file by either copying it from a local location or downloading it from a URL.

.DESCRIPTION
    This script automates the process of creating an EXE installer for OpenJDK distributions. It accepts either a local zip file path or a URL to a zip file (containing a zip file of the JDK binaries), extracts the contents, and prepares the necessary folder structure. This script is designed to be used with Inno Setup, a tool for creating Windows installers. First, a template Inno Setup script is modified with the provided parameters. The script then generates an EXE installer package that can be used to install OpenJDK on Windows systems. If a signing cli command is provided, the script will also sign the resulting EXE package (Note: this is the only way to also sign the uninstall script that goes into the EXE). The script supports various parameters to customize the installer, such as application name, vendor information, architecture, and versioning details.

.PARAMETER ZipFilePath
    Optional. The local path to a zip file to be copied and unzipped.

.PARAMETER ZipFileUrl
    Optional. The URL of a zip file to be downloaded and unzipped.

.PARAMETER ProductMajorVersion
    Example: if the version is 17.0.16+8, this is 17

.PARAMETER ProductMinorVersion
    Example: if the version is 17.0.16+8, this is 0

.PARAMETER ProductMaintenanceVersion
    Example: if the version is 17.0.16+8, this is 16

.PARAMETER ProductPatchVersion
    This is a number that comes between the maintenance and build numbers if it exists.
    For most builds, this is 0. If this is a respin, it will be the respin number.
    Examples:
        - if the version is 17.0.16+8,  this is 0
        - if the version is 17.0.8.1+1, this is 1

.PARAMETER ProductBuildNumber
    Example: if the version is 17.0.16+8, this is 8

.PARAMETER ExeProductVersion
    The full version of the JDK/EXE product. This is used to determine
    Example: if the version is 17.0.16+8, this is "17.0.16.8"

.PARAMETER Arch
    Mostly used to determine default display names like $AppName and $OutputFileName.
    Examples: x86, x64, arm, arm64, aarch64

.PARAMETER JVM
    The JVM used in the JDK/JRE. This is used to determine default display names like $AppName and $OutputFileName.
    Valid values: hotspot, openj9, dragonwell

.PARAMETER ProductCategory
    The category of the product, either jdk or jre. This is used to determine
    default display names like $AppName and $OutputFileName, and Registry Key behavior.
    Valid values: jdk, jre

.PARAMETER AppName
    Optional. The name of the App.
    Example: "Eclipse Temurin JDK with Hotspot 17.0.15+6 (x64)"
    Default: "$VendorBranding $($ProductCategory.ToUpper()) with $CapitalizedJVM $ProductMajorVersion.$ProductMinorVersion.$ProductMaintenanceVersion+$ProductBuildNumber ($Arch)"

.PARAMETER Vendor
    Optional. Default: Eclipse Adoptium

.PARAMETER VendorBranding
    Optional. Helps determine default values for $AppName
    but goes unused if those are both provided.
    Default: Eclipse Temurin

.PARAMETER VendorBrandingLogo
    Optional. The path to the ".ico" file to be used as the logo in the installer.
    This can be a full path to any file, or a relative path to a logo file in the inno_setup/logos folder.
    Default: "logos\logo.ico"

.PARAMETER VendorBrandingDialog
    Optional. The path to the ".bmp" file to be used as the welcome dialog in the installer.
    This can be a full path to any file, or a relative path to a logo file in the inno_setup/logos folder.
    Default: "logos\welcome-dialog.bmp"

.PARAMETER VendorBrandingSmallIcon
    Optional. The path to the ".bmp" file to be used as the small icon in the installer.
    This can be a full path to any file, or a relative path to a logo file in the inno_setup/logos folder.
    Default: "logos\logo_small.bmp"

.PARAMETER OutputFileName
    Optional. The name of the output file. Note: inno setup will automatically add the '.exe' file extension
    Default:
        "OpenJDK${ProductMajorVersion}-$ProductCategory_$Arch-windows-$JVM-$ProductMajorVersion.$ProductMinorVersion.$ProductMaintenanceVersion.ProductPatchVersion.$ProductBuildNumber"

.PARAMETER License
    Optional. The Path to the license file. This can either be a full path to any file, or a relative path to a license file in the inno_setup/licenses folder.
    Default: "licenses/license-GPLv2+CE.en-us.rtf"

.EXAMPLE
    # Only mandatory inputs are defined here
    .\CreateMsix.ps1 `
        -ZipFilePath "C:\path\to\file.zip" `
        -AppName "Eclipse Temurin JDK with Hotspot 17.0.15+6 (x64)" `
        -ProductMajorVersion 17 `
        -ProductMinorVersion 0 `
        -ProductMaintenanceVersion 15 `
        -ProductBuildNumber 6 `
        -Arch "x64" `

.EXAMPLE
    # All inputs are defined here
    .\CreateMsix.ps1 `
        # Mandatory inputs
        -ZipFileUrl "https://example.com/file.zip" `
        -ProductMajorVersion 21 `
        -ProductMinorVersion 0 `
        -ProductMaintenanceVersion 7 `
        -ProductBuildNumber 6 `
        -Arch "aarch64" `
        # Optional inputs: These are the defaults that will be used if not specified
        -Vendor "Eclipse Adoptium" `
        -VendorBranding "Eclipse Temurin" `
        -AppName "Eclipse Temurin 17.0.15+6 (x64)" `
        # Optional Inputs: omitting these inputs will cause their associated process to be skipped
        -OutputFileName "OpenJDK21-jdk_x64_windows_hotspot-21.0.8.0.9" `

.NOTES
    Ensure that you have downloaded the Windows SDK (typically through installing Visual Studio). For more information, please see the #Dependencies section of the README.md file. After doing so, please modify the following environment variables if the defaults shown below are not correct:
    $Env:WIN_SDK_FULL_VERSION = "10.0.22621.0"
    $Env:WIN_SDK_MAJOR_VERSION = "10"
#>

param (
    [Parameter(Mandatory = $false)]
    [string]$ZipFilePath,

    [Parameter(Mandatory = $false)]
    [string]$ZipFileUrl,

    [Parameter(Mandatory = $true)]
    [int]$ProductMajorVersion,

    [Parameter(Mandatory = $true)]
    [int]$ProductMinorVersion,

    [Parameter(Mandatory = $true)]
    [int]$ProductMaintenanceVersion,

    [Parameter(Mandatory = $true)]
    [int]$ProductPatchVersion,

    [Parameter(Mandatory = $true)]
    [int]$ProductBuildNumber,

    [Parameter(Mandatory = $true)]
    [string]$ExeProductVersion,

    [Parameter(Mandatory = $true)]
    [string]$Arch,

    [Parameter(Mandatory = $true)]
    [ValidateSet("hotspot", "openj9", "dragonwell")]
    [string]$JVM,

    [Parameter(Mandatory = $true)]
    [ValidateSet("jdk", "jre")]
    [string]$ProductCategory = "jdk",

    [Parameter(Mandatory = $false)]
    [string]$AppName = "",

    [Parameter(Mandatory = $false)]
    [string]$Vendor = "Eclipse Adoptium",

    [Parameter(Mandatory = $false)]
    [string]$VendorBranding = "Eclipse Temurin",

    [Parameter(Mandatory = $false)]
    [string]$VendorBrandingLogo = "logos\logo.ico",

    [Parameter(Mandatory = $false)]
    [string]$VendorBrandingDialog = "logos\welcome-dialog.bmp",

    [Parameter(Mandatory = $false)]
    [string]$VendorBrandingSmallIcon = "logos\logo_small.bmp",

    [Parameter(Mandatory = $false)]
    [string]$OutputFileName,

    [Parameter(Mandatory = $false)]
    [string]$License = "licenses/license-GPLv2+CE.en-us.rtf"
)

# Get the path to msix folder (parent directory of this script)
$InnoSetupWorkDirPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Find and source the Helpers.ps1 script located in the scripts folder to get access to helper functions
$HelpersScriptPath = Join-Path -Path $InnoSetupWorkDirPath -ChildPath "ps_scripts\Helpers.ps1"
if (-not (Test-Path -Path $HelpersScriptPath)) {
    throw "Error: The Helpers.ps1 script was not found at '$HelpersScriptPath'."
}
. $HelpersScriptPath
# Validate the inputs
## Ensure that either a local zip file path or a URL is provided, but not both
ValidateZipFileInput -ZipFilePath $ZipFilePath -ZipFileUrl $ZipFileUrl

# Set values needed in file
$CapitalizedJVM = CapitalizeString `
    -InputValue $JVM `
    -AllLetters

$VersionMajorToMaintenance = $ProductMajorVersion.$ProductMinorVersion.$ProductMaintenanceVersion

# Set default values if optional parameters are not provided
$AppName = SetDefaultIfEmpty `
    -InputValue $AppName `
    -DefaultValue "$VendorBranding $($ProductCategory.ToUpper()) with $CapitalizedJVM $VersionMajorToMaintenance+$ProductBuildNumber ($Arch)"

## Note: inno setup will add the '.exe' file extension automatically
$OutputFileName = SetDefaultIfEmpty `
    -InputValue $OutputFileName `
    -DefaultValue "OpenJDK${ProductMajorVersion}-$ProductCategory_$Arch_windows_$JVM-$VersionMajorToMaintenance.$ProductPatchVersion.$ProductBuildNumber"

# Clean the srce, workspace, and output folders
$srcFolder = Clear-TargetFolder -TargetFolder (Join-Path -Path $InnoSetupWorkDirPath -ChildPath "src")
$workspaceFolder = Clear-TargetFolder -TargetFolder (Join-Path -Path $InnoSetupWorkDirPath -ChildPath "workspace")
$outputFolder = Clear-TargetFolder -TargetFolder (Join-Path -Path $InnoSetupWorkDirPath -ChildPath "output")
Write-Host "Folders cleaned: $srcFolder, $workspaceFolder, $outputFolder"

# Download zip file if a URL is provided, otherwise use the local path
if ($ZipFileUrl) {
    Write-Host "Downloading zip file from URL: $ZipFileUrl"
    $ZipFilePath = DownloadFileFromUrl -Url $ZipFileUrl -DestinationDirectory $workspaceFolder
}
Write-Host "Using ZipFilePath: $ZipFilePath"
UnzipFile -ZipFilePath $ZipFilePath -DestinationPath $srcFolder

# Move contents of the unzipped file to $srcFolder
# $unzippedFolder = Join-Path -Path $workspaceFolder -ChildPath (Get-ChildItem -Path $workspaceFolder -Directory | Select-Object -First 1).Name
# Move-Item -Path (Join-Path -Path $unzippedFolder -ChildPath "*") -Destination $srcFolder -Force
# Remove-Item -Path $unzippedFolder -Recurse -Force

$exeTemplate = Join-Path -Path $InnoSetupWorkDirPath -ChildPath "create_exe.iss"
$content = Get-Content -Path $exeTemplate

# Replace all instances of placeholders with the provided values
$updatedContent = $content `
    -replace "<APPNAME>", $AppName `
    -replace "<VENDOR>", $Vendor `
    -replace "<VENDOR_BRANDING>", $VendorBranding `
    -replace "<PRODUCT_CATEGORY>", $ProductCategory `
    -replace "<JVM>", $JVM `
    -replace "<PRODUCT_MAJOR_VERSION>", $ProductMajorVersion `
    -replace "<PRODUCT_MINOR_VERSION>", $ProductMinorVersion `
    -replace "<PRODUCT_MAINTENANCE_VERSION>", $ProductMaintenanceVersion `
    # ProductPatchVersion
    -replace "<PRODUCT_BUILD_NUMBER>", $ProductBuildNumber `
    -replace "<EXE_PRODUCT_VERSION>", $ExeProductVersion `
    -replace "<OUTPUT_EXE_NAME>", $OutputFileName `
    -replace "<APP_URL>", "https://adoptium.net/" `
    -replace "<VENDOR_BRANDING_LOGO>", $VendorBrandingLogo `
    -replace "<VENDOR_BRANDING_DIALOG>", $VendorBrandingDialog `
    -replace "<VENDOR_BRANDING_SMALL_ICON>", $VendorBrandingSmallIcon `
    -replace "<LICENSE_FILE>", $License `
    -replace "<SIGNING_TOOL>", "signtool.exe" `
    # Inno setup needs us to escape '{' literals by putting two together. The '}' does not need to be escaped
    -replace "<APPID>", "{{}}" ########################


# Write the updated content to the new create_exe.iss file
$exeIssPath = Join-Path -Path $InnoSetupWorkDirPath -ChildPath "create_exe.iss"
Set-Content -Path $exeIssPath -Value $updatedContent
Write-Host "create_exe.iss created at '$exeIssPath'"


