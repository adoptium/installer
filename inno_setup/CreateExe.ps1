<#
.SYNOPSIS
    Script that uses Inno Setup to create an EXE installer (for a JDK/JRE) from a zip file by either copying it from a local directory or downloading it from a URL.

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

.PARAMETER UpgradeCodeSeed
    Optional. A seed string used to generate a deterministic PRODUCT_UPGRADE_CODE.
    This is used to ensure that the PRODUCT_UPGRADE_CODE is consistent across builds.
    If this is not provided, a random PRODUCT_UPGRADE_CODE will be generated.
    Default: ""

.PARAMETER SigningCommand
    Optional. The command to sign the resulting EXE file. This is typically a command that
    uses signtool.exe to sign the EXE file. If this is not provided, the EXE will not be signed.
    See the following link for more info on input variables that can be used within the command: https://jrsoftware.org/ishelp/index.php?topic=setup_signtool
    Examples:
        'signtool.exe sign /fd SHA256 $f'
        'signtool.exe sign /a /n $qMy Common Name$q /t http://timestamp.comodoca.com/authenticode /d $qMy Program$q $f'
    Default: ""

.EXAMPLE
    # Only mandatory inputs are defined here
    .\CreateExe.ps1 `
        -ZipFilePath "C:\path\to\file.zip" `
        -ProductMajorVersion 17 `
        -ProductMinorVersion 0 `
        -ProductMaintenanceVersion 16 `
        -ProductPatchVersion 0 `
        -ProductBuildNumber 8 `
        -ExeProductVersion "17.0.16.8" `
        -Arch "x64" `
        -JVM "hotspot" `
        -ProductCategory "jdk"

.EXAMPLE
    # All inputs are defined here
    .\CreateExe.ps1 `
        # Mandatory inputs
        -ZipFileUrl "https://example.com/file.zip" `
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
        -VendorBrandingDialog "logos\welcome-dialog.bmp" `
        -VendorBrandingSmallIcon "logos\logo_small.bmp" `
        -OutputFileName "OpenJDK21-jdk_aarch64_windows_hotspot-21.0.8.0.9" `
        -License "licenses/license-GPLv2+CE.en-us.rtf" `
        # Additional Optional Inputs: Omitting these inputs will cause their associated process to be skipped
        -SigningCommand "signtool.exe sign /f C:\path\to\cert"

.NOTES
    Ensure that you have downloaded Inno Setup (can be done through winget or directly from their website: https://jrsoftware.org/isdl.php). For more information, please see the #Dependencies section of the README.md file.
    If you do not have inno setup installed, you can install it using the following command:
        winget install --id JRSoftware.InnoSetup -e -s winget --scope <machine|user>
    Or directly by modifying this link to the latest version:
        https://files.jrsoftware.org/is/6/innosetup-#.#.#.exe
        Example: https://files.jrsoftware.org/is/6/innosetup-6.5.0.exe
    Afterwards, please set the following environment variable to the path of the inno setup executable (if the default, machine-scope path below is incorrect):
        $env:INNO_SETUP_PATH = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
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
    [string]$License = "licenses/license-GPLv2+CE.en-us.rtf",

    [Parameter(Mandatory = $false)]
    [string]$UpgradeCodeSeed = "",

    [Parameter(Mandatory = $false)]
    [string]$SigningCommand = ""
)

# Get the path to inno setup folder (parent directory of this script)
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
    -InputString $JVM `

$VersionMajorToMaintenance = "${ProductMajorVersion}.${ProductMinorVersion}.${ProductMaintenanceVersion}"

# Set default values if optional parameters are not provided
$AppName = SetDefaultIfEmpty `
    -InputValue $AppName `
    -DefaultValue "$VendorBranding $($ProductCategory.ToUpper()) with ${CapitalizedJVM} ${VersionMajorToMaintenance}+${ProductBuildNumber} ($Arch)"

## Note: inno setup will add the '.exe' file extension automatically
$OutputFileName = SetDefaultIfEmpty `
    -InputValue $OutputFileName `
    -DefaultValue "OpenJDK${ProductMajorVersion}-${ProductCategory}_${Arch}_windows_${JVM}-${VersionMajorToMaintenance}.${ProductPatchVersion}.${ProductBuildNumber}"

# Clean the src, workspace, and output folders
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
$unzippedFolder = (Get-ChildItem -Path $srcFolder -Directory | Select-Object -First 1).FullName

$exeTemplate = Join-Path -Path $InnoSetupWorkDirPath -ChildPath "templates\create_exe.template.iss"
$content = Get-Content -Path $exeTemplate

if (-not $UpgradeCodeSeed) {
    # If no UpgradeCodeSeed is given, generate a new PRODUCT_UPGRADE_CODE (random GUID, not upgradable)
    $PRODUCT_UPGRADE_CODE = [guid]::NewGuid().ToString("B").ToUpper()
    Write-Host "Unique PRODUCT_UPGRADE_CODE: $PRODUCT_UPGRADE_CODE"
} else {
    # Generate a deterministic PRODUCT_UPGRADE_CODE based on input values and UpgradeCodeSeed
    # Compose SOURCE_TEXT_GUID similar to the original script
    $SOURCE_TEXT_GUID = "${ProductCategory}-${ProductMajorVersion}-${Arch}-${JVM}"
    Write-Host "SOURCE_TEXT_GUID (without displaying secret UpgradeCodeSeed): $SOURCE_TEXT_GUID"
    # Call getGuid.ps1 to generate a GUID based on SOURCE_TEXT_GUID and UpgradeCodeSeed
    $getGuidScriptPath = Join-Path -Path $InnoSetupWorkDirPath -ChildPath "getGuid.ps1"
    $PRODUCT_UPGRADE_CODE = GenerateGuidFromString -SeedString "${SOURCE_TEXT_GUID}-${UpgradeCodeSeed}"
    Write-Host "Constant PRODUCT_UPGRADE_CODE: $PRODUCT_UPGRADE_CODE"
}

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
    -replace "<PRODUCT_PATCH_VERSION>", $ProductPatchVersion `
    -replace "<PRODUCT_BUILD_NUMBER>", $ProductBuildNumber `
    -replace "<EXE_PRODUCT_VERSION>", $ExeProductVersion `
    -replace "<OUTPUT_EXE_NAME>", $OutputFileName `
    -replace "<APP_URL>", "https://adoptium.net/" `
    -replace "<VENDOR_BRANDING_LOGO>", $VendorBrandingLogo `
    -replace "<VENDOR_BRANDING_DIALOG>", $VendorBrandingDialog `
    -replace "<VENDOR_BRANDING_SMALL_ICON>", $VendorBrandingSmallIcon `
    -replace "<LICENSE_FILE>", $License `
    -replace "<PRODUCT_UPGRADE_CODE>", $PRODUCT_UPGRADE_CODE `
    -replace "<SOURCE_FILES>", $unzippedFolder

# Write the updated content to the new create_exe.iss file
$exeIssPath = Join-Path -Path $InnoSetupWorkDirPath -ChildPath "create_exe.iss"
Set-Content -Path $exeIssPath -Value $updatedContent
Write-Host "create_exe.iss created at '$exeIssPath'"

# if $env:INNO_SETUP_PATH is not set, default to the standard installation path for a machine-scope installation
if ([string]::IsNullOrEmpty($env:INNO_SETUP_PATH)) {
    $INNO_SETUP_PATH = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    Write-Host "env:INNO_SETUP_PATH not set. Defaulting to '$INNO_SETUP_PATH'"
} else {
    $INNO_SETUP_PATH = $env:INNO_SETUP_PATH
}

# Create .exe file based on create_exe.iss. Sign it only if $SigningCommand is not empty or null
# See the following link for more info on issc.exe: https://jrsoftware.org/ishelp/index.php?topic=compilercmdline
if (![string]::IsNullOrEmpty($SigningCommand)) {
    Write-Host "Executing Inno Setup with signing."
    & "$INNO_SETUP_PATH" `
        /S $SigningCommand `
        $exeIssPath `
} else {
    Write-Host "Executing Inno Setup without signing."
    & "$INNO_SETUP_PATH" $exeIssPath
}

CheckForError -ErrorMessage "Error: iscc.exe failed to create .exe file."

Write-Host "EXE file created successfully in '$outputFolder'"

Move-Item -Path $exeIssPath -Destination $workspaceFolder -Force
Write-Host "Moved create_exe.iss to '$workspaceFolder'"
