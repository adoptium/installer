<#
.SYNOPSIS
    Script to handle a zip file by either copying it from a local location or downloading it from a URL.

.DESCRIPTION
    This script accepts one of two optional inputs:
    1. A local zip file path to copy and unzip into the 'src' folder.
    2. A URL to download a zip file and unzip it into the 'src' folder.
    If neither or both inputs are provided, the script will throw an error.

.PARAMETER ZipFilePath
    Optional. The local path to a zip file to be copied and unzipped.

.PARAMETER ZipFileUrl
    Optional. The URL of a zip file to be downloaded and unzipped.

.PARAMETER PackageName
    Optional. The name of the package -- cannot contain spaces or underscores.
    IMPORTANT: This needs to be consistent with previous releases for upgrades to work as expected
    Note: The output file will be named: $PackageName.msix
    If not provided, a default name will have the following format: "OpenJDK${ProductMajorVersion}U-jdk-$Arch-windows-hotspot-$ProductMajorVersion"

.PARAMETER Vendor
    Optional. Default: Eclipse Adoptium.

.PARAMETER VendorBranding
    Optional. Default: Eclipse Temurin

.PARAMETER MsixDisplayName
    Optional. Example: "Eclipse Temurin 17.0.15+6 (x64)".
    This is the display name of the MSIX package.
    Default: "$VendorBranding $ProductMajorVersion.$ProductMinorVersion.$ProductMaintenanceVersion+$ProductBuildNumber ($Arch)".

.PARAMETER Description
    Optional. Example: "Eclipse Temurin Development Kit with Hotspot".
    Default: $VendorBranding.

.PARAMETER ProductMajorVersion
    Example: if the version is 17.0.15+6, this is 17.

.PARAMETER ProductMinorVersion
    Example: if the version is 17.0.15+6, this is 0.

.PARAMETER ProductMaintenanceVersion
    Example: if the version is 17.0.15+6, this is 15.

.PARAMETER ProductBuildNumber
    Example: if the version is 17.0.15+6, this is 6.

.PARAMETER Arch
    Valid architectures: x86, x64, arm, arm64, x86a64, neutral

.PARAMETER PublisherCN
    Set this to anything on the right side of your `CN=` field in your .pfx file.
    This may include additional fields in the name, such as 'O=...', 'L=...', 'S=...', and/or others.

.PARAMETER SigningCertPath
    Optional. The path to the signing certificate (.pfx) file used to sign the package.
    If not provided, the script will not sign the package.

.PARAMETER SigningPassword
    Optional. The password for the signing certificate.
    Only needed if the SigningCertPath is provided.

.PARAMETER OutputFileName
    Optional. The name of the output file.
    If not provided, a default name will be generated based on the VendorBranding and version information.

.PARAMETER VerboseOutput
    Optional. If specified, $global:ProgressPreference is not set to 'SilentlyContinue'.
    Note: Unzipping binaries is much faster if not verbose. (Because the progress bar is not shown)
    Alias: -v.

.EXAMPLE
    .\CreateMsix.ps1 `
        -ZipFilePath "C:\path\to\file.zip" `
        -PackageName "OpenJDK17U-jdk-x64-windows-hotspot" `
        -PublisherCN "ExamplePublisher" `
        -ProductMajorVersion 17 `
        -ProductMinorVersion 0 `
        -ProductMaintenanceVersion 15 `
        -ProductBuildNumber 6 `
        -Arch "x64" `

.EXAMPLE
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
        -Description "Eclipse Temurin" `
        # Optional Inputs: omitting these inputs will cause their associated process to be skipped
        -SigningCertPath "C:\path\to\cert.pfx"
        -SigningPassword "your cert's password"
        -OutputFileName "OpenJDK21U-jdk_x64_windows_hotspot_21.0.7_6.msix" `
        -VerboseOutput

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
    [string]$PackageName,

    [Parameter(Mandatory = $true)]
    [string]$PublisherCN,

    [Parameter(Mandatory = $true)]
    [int]$ProductMajorVersion,

    [Parameter(Mandatory = $true)]
    [int]$ProductMinorVersion,

    [Parameter(Mandatory = $true)]
    [int]$ProductMaintenanceVersion,

    [Parameter(Mandatory = $true)]
    [int]$ProductBuildNumber,

    [Parameter(Mandatory = $true)]
    [string]$Arch,

    [Parameter(Mandatory = $false)]
    [string]$Vendor = "Eclipse Adoptium",

    [Parameter(Mandatory = $false)]
    [string]$VendorBranding = "Eclipse Temurin",

    [Parameter(Mandatory = $false)]
    [string]$MsixDisplayName = "",

    [Parameter(Mandatory = $false)]
    [string]$Description = "",

    [Parameter(Mandatory = $false)]
    [string]$SigningCertPath,

    [Parameter(Mandatory = $false)]
    [string]$SigningPassword,

    [Parameter(Mandatory = $false)]
    [string]$OutputFileName,

    [Parameter(Mandatory = $false, HelpMessage = "Include this flag to output verbose messages.")]
    [Alias("v")]
    [switch]$VerboseOutput
)

# Set $ProgressPreference to 'SilentlyContinue' if the verbose flag is not set
$OriginalProgressPreference = $global:ProgressPreference
if (-not $VerboseOutput) {
    $global:ProgressPreference = 'SilentlyContinue'
}

# Get the path to msix folder (parent directory of this script)
$MsixDirPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Find and source the Helpers.ps1 script located in the scripts folder to get access to helper functions
$HelpersScriptPath = Join-Path -Path $MsixDirPath -ChildPath "scripts\Helpers.ps1"
if (-not (Test-Path -Path $HelpersScriptPath)) {
    throw "Error: The Helpers.ps1 script was not found at '$HelpersScriptPath'."
}
. $HelpersScriptPath
# Validate the inputs
## Ensure that either a local zip file path or a URL is provided, but not both
ValidateZipFileInput -ZipFilePath $ZipFilePath -ZipFileUrl $ZipFileUrl
## Ensure that both or neither of the signing inputs are provided
ValidateSigningInput -SigningCertPath $SigningCertPath -SigningPassword $SigningPassword

# Set default values if optional parameters are not provided
$MsixDisplayName = SetDefaultIfEmpty `
                    -InputValue $MsixDisplayName `
                    -DefaultValue "$VendorBranding $ProductMajorVersion.$ProductMinorVersion.$ProductMaintenanceVersion+$ProductBuildNumber ($Arch)"

$Description = SetDefaultIfEmpty `
                -InputValue $Description `
                -DefaultValue "$VendorBranding"

$OutputFileName = SetDefaultIfEmpty `
                    -InputValue $OutputFileName `
                    -DefaultValue "OpenJDK${ProductMajorVersion}U-jdk-$Arch-windows-hotspot-$ProductMajorVersion.$ProductMinorVersion.$ProductMaintenanceVersion_$ProductBuildNumber.msix"

# Ensure SetupEnv.ps1 exists, then source it for access to functions
$SetupEnvScriptPath = Join-Path -Path $MsixDirPath -ChildPath "scripts\SetupEnv.ps1"
if (-not (Test-Path -Path $SetupEnvScriptPath)) {
    throw "Error: The SetupEnv.ps1 script was not found at '$SetupEnvScriptPath'."
}
. $SetupEnvScriptPath
# Get the path to the Windows SDK tools
$WindowsSdkPath = Get-WindowsSdkPath `
    -WIN_SDK_FULL_VERSION $Env:WIN_SDK_FULL_VERSION `
    -WIN_SDK_MAJOR_VERSION $Env:WIN_SDK_MAJOR_VERSION `
    -Arch $Arch
Write-Host "Windows SDK path: $WindowsSdkPath"

# Clean the srce, workspace, and output folders
$srcFolder = Clean-ChildFolder `
    -TargetFolder (Join-Path -Path $MsixDirPath -ChildPath "src") `
    -ExcludeSubfolder "_msix_logos"
$workspaceFolder = Clean-ChildFolder -TargetFolder (Join-Path -Path $MsixDirPath -ChildPath "workspace")
$outputFolder = Clean-ChildFolder -TargetFolder (Join-Path -Path $MsixDirPath -ChildPath "output")
Write-Host "Folders cleaned: $srcFolder, $workspaceFolder, $outputFolder"

# Download zip file if a URL is provided, otherwise use the local path
if ($ZipFileUrl) {
    $ZipFilePath = DownloadFileFromUrl -Url $ZipFileUrl -DestinationDirectory $workspaceFolder
}
UnzipFile -ZipFilePath $ZipFilePath -DestinationPath $workspaceFolder

# Move contents of the unzipped file to $srcFolder
$unzippedFolder = Join-Path -Path $workspaceFolder -ChildPath (Get-ChildItem -Path $workspaceFolder -Directory | Select-Object -First 1).Name
Move-Item -Path (Join-Path -Path $unzippedFolder -ChildPath "*") -Destination $srcFolder -Force
Remove-Item -Path $unzippedFolder -Recurse -Force

$appxTemplate = Join-Path -Path $scriptPath -ChildPath "templates\AppXManifestTemplate.xml"
$content = Get-Content -Path $appxTemplate

# Replace all instances of placeholders with the provided values
$updatedContent = $content `
    -replace "\{VENDOR\}", $Vendor `
    -replace "\{VENDOR_BRANDING\}", $VendorBranding `
    -replace "\{MSIX_DISPLAYNAME\}", $MsixDisplayName `
    -replace "\{PACKAGE_NAME\}", $PackageName `
    -replace "\{DESCRIPTION\}", $Description `
    -replace "\{PRODUCT_MAJOR_VERSION\}", $ProductMajorVersion `
    -replace "\{PRODUCT_MINOR_VERSION\}", $ProductMinorVersion `
    -replace "\{PRODUCT_MAINTENANCE_VERSION\}", $ProductMaintenanceVersion `
    -replace "\{PRODUCT_BUILD_NUMBER\}", $ProductBuildNumber `
    -replace "\{ARCH\}", $Arch `
    -replace "\{PUBLISHER_CN\}", $PublisherCN


# Write the updated content to the new AppXManifest.xml file
$appxManifestPath = Join-Path -Path $srcFolder -ChildPath "AppXManifest.xml"
Set-Content -Path $appxManifestPath -Value $updatedContent
Write-Host "AppXManifest.xml created at '$appxManifestPath'"

# Copy pri_config.xml to the target folder (path from SetupEnv.ps1)
$priConfig = Join-Path -Path $scriptPath -ChildPath "templates\pri_config.xml"
Copy-Item -Path $priConfig -Destination $srcFolder -Force
Write-Host "pri_config.xml copied to '$srcFolder'"

# Create _resources.pri file based on pri_config.xml
& "$WindowsSdkPath\makepri.exe" new `
    /o `
    /pr $srcFolder `
    /cf "$srcFolder\pri_config.xml" `
    /of "$srcFolder\_resources.pri" `
    /mf appx

# Create the MSIX package
& "$WindowsSdkPath\makeappx.exe" pack `
    /o `
    /d "$srcFolder" `
    /p "$outputFolder\$OutputFileName"

# Sign the MSIX package if a signing certificate is provided
if ($SigningCertPath) {
    & "$WindowsSdkPath\signtool.exe" sign `
        /fd SHA256 `
        /a `
        /f $SigningCertPath `
        /p "$SigningPassword" `
        "$outputFolder\$OutputFileName"
    Write-Host "MSIX package signed successfully."
}
else {
    Write-Host "SigningCertPath not provided. Skipping signing process."
}

$global:ProgressPreference = $OriginalProgressPreference