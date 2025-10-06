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
    The full version of the JDK/EXE product as written with only '.' and numbers.
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

.PARAMETER ProductPublisherLink
    Optional. The URL that represents the product publisher. Default: "https://adoptium.net"

.PARAMETER ProductSupportLink
    Optional. The URL for where customers can go to for support. Default: "https://adoptium.net/support"

.PARAMETER ProductUpdateInfoLink
    Optional. The URL for product update information. Default: "https://adoptium.net/temurin/releases"

.PARAMETER OutputFileName
    Optional. The name of the output file. Note: Inno Setup will automatically add the '.exe' file extension
    Default:
        "OpenJDK${ProductMajorVersion}-$ProductCategory_$Arch_windows_$JVM-$ProductMajorVersion.$ProductMinorVersion.$ProductMaintenanceVersion.$ProductPatchVersion.$ProductBuildNumber"

.PARAMETER License
    Optional. The path to the license file. This can either be a full path to any file, or a relative path to a license file in the inno_setup/licenses folder.
    Default: "licenses/license-GPLv2+CE.en-us.rtf"

.PARAMETER UpgradeCodeSeed
    Optional. A seed string used to generate a deterministic PRODUCT_UPGRADE_CODE.
    This is used to ensure that the PRODUCT_UPGRADE_CODE is consistent across builds.
    If this is not provided, a random PRODUCT_UPGRADE_CODE will be generated.
    Default: ""

.PARAMETER TranslationFile
    Optional. The path to the translation file .iss containing text translations for the installer's custom messages.
    This can be a path relative to the `installer/inno_setup` directory, or this can be an absolute path.
    Default: "translations\default.iss"

.PARAMETER IncludeUnofficialTranslations
    Optional. Set this flag to support unofficial Inno Setup translations like Chinese.
    ## Note: Here, unofficial means that there are a few default messages that do not
    ##       have translations (from English) supported by Inno Setup yet.
    Default: "false"

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
        -ProductPublisherLink "https://adoptium.net" `
        -ProductSupportLink "https://adoptium.net/support" `
        -ProductUpdateInfoLink "https://adoptium.net/temurin/releases" `
        -OutputFileName "OpenJDK21-jdk_aarch64_windows_hotspot-21.0.8.0.9" `
        -License "licenses/license-GPLv2+CE.en-us.rtf" `
        -UpgradeCodeSeed "MySecretSeedCode(SameAsWix)" `
        -TranslationFile "translations/default.iss" `
        # Additional Optional Inputs: Omitting these inputs will cause their associated process to be skipped
        -IncludeUnofficialTranslations "true" `
        -SigningCommand "signtool.exe sign /f C:\path\to\cert"

.NOTES
    Ensure that you have downloaded Inno Setup (can be done through winget or directly from their website: https://jrsoftware.org/isdl.php). For more information, please see the #Dependencies section of the README.md file.
    If you do not have Inno Setup installed, you can install it using the following command:
        winget install --id JRSoftware.InnoSetup -e -s winget --scope <machine|user>
    Or directly download the installation exe by modifying this link to the latest version:
        https://files.jrsoftware.org/is/6/innosetup-#.#.#.exe
        Example: https://files.jrsoftware.org/is/6/innosetup-6.5.0.exe
    Afterwards, please set the following environment variable to the path of the Inno Setup executable (if the default, machine-scope path below is incorrect):
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
    [string]$ProductPublisherLink = "https://adoptium.net",

    [Parameter(Mandatory = $false)]
    [string]$ProductSupportLink = "https://adoptium.net/support",

    [Parameter(Mandatory = $false)]
    [string]$ProductUpdateInfoLink = "https://adoptium.net/temurin/releases",

    [Parameter(Mandatory = $false)]
    [string]$OutputFileName,

    [Parameter(Mandatory = $false)]
    [string]$License = "licenses/license-GPLv2+CE.en-us.rtf",

    [Parameter(Mandatory = $false)]
    [string]$UpgradeCodeSeed = "",

    [Parameter(Mandatory = $false)]
    [string]$TranslationFile = "translations\default.iss",

    [Parameter(Mandatory = $false)]
    [string]$IncludeUnofficialTranslations = "false",

    [Parameter(Mandatory = $false)]
    [string]$SigningCommand = ""
)

# Get the path to Inno Setup folder (parent directory of this script)
$InnoSetupRootDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Validate Architecture input and get ArchitecturesAllowed value for template input
$ArchitecturesAllowed = GetArchitectureAllowedTemplateInput -Arch $Arch

# Find and source the Helpers.ps1 script located in the scripts folder to get access to helper functions
$HelpersScriptPath = Join-Path -Path $InnoSetupRootDir -ChildPath "ps_scripts\Helpers.ps1"
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

## Note: Inno Setup will add the '.exe' file extension automatically
$OutputFileName = SetDefaultIfEmpty `
    -InputValue $OutputFileName `
    -DefaultValue "OpenJDK${ProductMajorVersion}-${ProductCategory}_${Arch}_windows_${JVM}-${VersionMajorToMaintenance}.${ProductPatchVersion}.${ProductBuildNumber}"

## If $env:INNO_SETUP_PATH is not set, default to the standard installation path for a machine-scope installation
$INNO_SETUP_PATH = SetDefaultIfEmpty `
    -InputValue $env:INNO_SETUP_PATH `
    -DefaultValue "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"

# Clean the src, workspace, and output folders
$srcFolder = Clear-TargetFolder -TargetFolder (Join-Path -Path $InnoSetupRootDir -ChildPath "src")
$workspaceFolder = Clear-TargetFolder -TargetFolder (Join-Path -Path $InnoSetupRootDir -ChildPath "workspace")
$outputFolder = Clear-TargetFolder -TargetFolder (Join-Path -Path $InnoSetupRootDir -ChildPath "output")
Write-Host "Folders cleaned: $srcFolder, $workspaceFolder, $outputFolder"

# Download zip file if a URL is provided, otherwise use the local path
if ($ZipFileUrl) {
    Write-Host "Downloading zip file from URL: $ZipFileUrl"
    $ZipFilePath = DownloadFileFromUrl -Url $ZipFileUrl -DestinationDirectory $workspaceFolder
}
Write-Host "Using ZipFilePath: $ZipFilePath"
UnzipFile -ZipFilePath $ZipFilePath -DestinationPath $srcFolder
$unzippedFolder = (Get-ChildItem -Path $srcFolder -Directory | Select-Object -First 1).FullName

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
    $getGuidScriptPath = Join-Path -Path $InnoSetupRootDir -ChildPath "getGuid.ps1"
    $PRODUCT_UPGRADE_CODE = GenerateGuidFromString -SeedString "${SOURCE_TEXT_GUID}-${UpgradeCodeSeed}"
    Write-Host "Constant PRODUCT_UPGRADE_CODE: $PRODUCT_UPGRADE_CODE"
}
# /DAppId: Inno setup needs us to escape '{' literals by putting two together. The '}' does not need to be escaped
$AppId = "{" + "${PRODUCT_UPGRADE_CODE}"

# Sign only if $SigningCommand is not empty or null
# See the following link for more info on Inno Setup signing: https://jrsoftware.org/ishelp/index.php?topic=setup_signtool
# See here for info on /S flag format: https://jrsoftware.org/ishelp/index.php?topic=compilercmdline
if (![string]::IsNullOrEmpty($SigningCommand)) {
    Write-Host "Executing Inno Setup with signing."
    $SigningArg = "/SsigningCommand=$SigningCommand"
    $ExtraArgs = '/DsignFiles="true"' # set this flag to enable signing with above command
} else {
    Write-Host "Executing Inno Setup without signing."
    $SigningArg = ""
    $ExtraArgs = ""
}

# Set this flag to support unofficial inno_setup translations like Chinese
## Note: Here, unofficial means that there are a few default messages that do not
##       have translations (from English) supported by Inno Setup yet
if ($IncludeUnofficialTranslations -ne "false") {
    Write-Host "Including unofficial translations."
    $ExtraArgs += ' /DINCLUDE_UNOFFICIAL_TRANSLATIONS="true"'
}

# For info on CLI options: https://jrsoftware.org/ishelp/index.php?topic=isppcc
# and https://jrsoftware.org/ishelp/index.php?topic=compilercmdline
# Create .exe file based on create_exe.template.iss.
& "$INNO_SETUP_PATH" $SigningArg `
    /J$TranslationFile `
    /DArchitecturesAllowed="$ArchitecturesAllowed" `
    /DAppName="$AppName" `
    /DVendor="$Vendor" `
    /DProductCategory="$ProductCategory" `
    /DJVM="$JVM" `
    /DProductMajorVersion="$ProductMajorVersion" `
    /DProductMinorVersion="$ProductMinorVersion" `
    /DProductMaintenanceVersion="$ProductMaintenanceVersion" `
    /DProductPatchVersion="$ProductPatchVersion" `
    /DProductBuildNumber="$ProductBuildNumber" `
    /DExeProductVersion="$ExeProductVersion" `
    /DAppPublisherURL="$ProductPublisherLink" `
    /DAppSupportURL="$ProductSupportLink" `
    /DAppUpdatesURL="$ProductUpdateInfoLink" `
    /DOutputFileName="$OutputFileName" `
    /DVendorBrandingLogo="$VendorBrandingLogo" `
    /DVendorBrandingDialog="$VendorBrandingDialog" `
    /DVendorBrandingSmallIcon="$VendorBrandingSmallIcon" `
    /DLicenseFile="$License" `
    /DAppId="$AppId" `
    /DSourceFiles="$unzippedFolder" `
    $ExtraArgs "${InnoSetupRootDir}\create_exe.template.iss"

CheckForError -ErrorMessage "ISCC.exe failed to create .exe file."

Write-Host "EXE file created successfully in '$outputFolder'"
