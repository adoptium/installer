<#
.SYNOPSIS
    Script to handle a zip file by either copying it from a local location or downloading it from a URL.

.DESCRIPTION
    This script automates the process of creating an MSIX package for OpenJDK distributions. It accepts either a local zip file path or a URL to a zip file (containing a zip file of the JDK binaries), extracts the contents, and prepares the necessary folder structure. The script generates an AppXManifest.xml file using provided metadata, copies required configuration files, and uses Windows SDK tools to package the files into an MSIX installer. Optionally, it can sign the resulting MSIX package if a signing certificate and password are provided. The script supports customization of package metadata such as display name, description, vendor, and output file name.

.PARAMETER ZipFilePath
    Optional. The local path to a zip file to be copied and unzipped.

.PARAMETER ZipFileUrl
    Optional. The URL of a zip file to be downloaded and unzipped.

.PARAMETER PackageName
    Optional. The name of the package. Cannot contain spaces or underscores.
    IMPORTANT: This needs to be consistent with previous releases for upgrades to work as expected
    Note: The output file will be named: $PackageName.msix
    If not provided, a default name will have the following format: "OpenJDK${ProductMajorVersion}U-jdk-$Arch-windows-hotspot-$ProductMajorVersion"

.PARAMETER Vendor
    Optional. Default: Eclipse Adoptium

.PARAMETER VendorBranding
    Optional. Helps determine default values for $MSIXDisplayName and $Description,
    but goes unused if those are both provided.
    Default: Eclipse Temurin

.PARAMETER MsixDisplayName
    Optional. Example: "Eclipse Temurin 17.0.15+6 (x64)".
    This is the display name of the MSIX package.
    Default: "$VendorBranding $ProductMajorVersion.$ProductMinorVersion.$ProductMaintenanceVersion+$ProductBuildNumber ($Arch)".

.PARAMETER Description
    Optional. Example: "Eclipse Temurin Development Kit with Hotspot".
    Default: $VendorBranding

.PARAMETER ProductMajorVersion
    Example: if the version is 17.0.15+6, this is 17

.PARAMETER ProductMinorVersion
    Example: if the version is 17.0.15+6, this is 0

.PARAMETER ProductMaintenanceVersion
    Example: if the version is 17.0.15+6, this is 15

.PARAMETER ProductBuildNumber
    Example: if the version is 17.0.15+6, this is 6

.PARAMETER Arch
    Valid architectures: x86, x64, arm, arm64, x86a64, neutral

.PARAMETER PublisherCN
    Set this to everything on the right side of your `CN=` field in your .pfx file.
    This may include additional fields in the name, such as 'O=...', 'L=...', 'S=...', and/or others.

.PARAMETER SigningCertPath
    Optional. The path to the signing certificate (.pfx) file used to sign the package.
    If not provided, the script will not sign the package.

.PARAMETER SigningPassword
    Optional. The password for the signing certificate.
    Only needed if the SigningCertPath is provided.

.PARAMETER OutputFileName
    Optional. The name of the output file.
    If not provided, a default name will be generated based of the following format:
    "OpenJDK${ProductMajorVersion}U-jdk-$Arch-windows-hotspot-$ProductMajorVersion.$ProductMinorVersion.$ProductMaintenanceVersion_$ProductBuildNumber.msix"

.PARAMETER VerboseTools
    Optional. If set to $true, the script will output verbose messages.
    Default: $false

.EXAMPLE
    # Only mandatory inputs are defined here
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
    # All inputs are defined here
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
    [string]$OutputFileName,

    [Parameter(Mandatory = $false)]
    [string]$Description = "",

    [Parameter(Mandatory = $false)]
    [string]$SigningCertPath,

    [Parameter(Mandatory = $false)]
    [string]$SigningPassword,

    [Parameter(Mandatory = $false)]
    [Alias("v")]
    [switch]$VerboseTools
)

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
$srcFolder = Clean-TargetFolder `
    -TargetFolder (Join-Path -Path $MsixDirPath -ChildPath "src") `
    -ExcludeSubfolder "_msix_logos"
$workspaceFolder = Clean-TargetFolder -TargetFolder (Join-Path -Path $MsixDirPath -ChildPath "workspace")
$outputFolder = Clean-TargetFolder -TargetFolder (Join-Path -Path $MsixDirPath -ChildPath "output")
Write-Host "Folders cleaned: $srcFolder, $workspaceFolder, $outputFolder"

# Download zip file if a URL is provided, otherwise use the local path
if ($ZipFileUrl) {
    Write-Host "Downloading zip file from URL: $ZipFileUrl"
    $ZipFilePath = DownloadFileFromUrl -Url $ZipFileUrl -DestinationDirectory $workspaceFolder
}
Write-Host "Using ZipFilePath: $ZipFilePath"
UnzipFile -ZipFilePath $ZipFilePath -DestinationPath $workspaceFolder

# Move contents of the unzipped file to $srcFolder
$unzippedFolder = Join-Path -Path $workspaceFolder -ChildPath (Get-ChildItem -Path $workspaceFolder -Directory | Select-Object -First 1).Name
Move-Item -Path (Join-Path -Path $unzippedFolder -ChildPath "*") -Destination $srcFolder -Force
Remove-Item -Path $unzippedFolder -Recurse -Force

$appxTemplate = Join-Path -Path $MsixDirPath -ChildPath "templates\AppXManifestTemplate.xml"
$content = Get-Content -Path $appxTemplate

# Replace all instances of placeholders with the provided values
$updatedContent = $content `
    -replace "\{VENDOR\}", $Vendor `
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
$priConfig = Join-Path -Path $MsixDirPath -ChildPath "templates\pri_config.xml"
Copy-Item -Path $priConfig -Destination $srcFolder -Force
Write-Host "pri_config.xml copied to '$srcFolder'"

# Set EXTRA_ARGS to '/v' if VerboseTools is specified
if ($VerboseTools) {
    $EXTRA_ARGS = '/v'
}
else {
    $EXTRA_ARGS = ''
}

# Create _resources.pri file based on pri_config.xml
& "$WindowsSdkPath\makepri.exe" new $EXTRA_ARGS `
    /Overwrite `
    /ProjectRoot $srcFolder `
    /ConfigXml "$srcFolder\pri_config.xml" `
    /OutputFile "$srcFolder\_resources.pri" `
    /MappingFile appx

# Create the MSIX package
& "$WindowsSdkPath\makeappx.exe" pack $EXTRA_ARGS `
    /overwrite `
    /d "$srcFolder" `
    /p "$outputFolder\$OutputFileName"

# Sign the MSIX package if a signing certificate is provided
if ($SigningCertPath) {
    & "$WindowsSdkPath\signtool.exe" sign $EXTRA_ARGS `
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
