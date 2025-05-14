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

.PARAMETER Vendor
    Optional. Example: Eclipse Adoptium.

.PARAMETER VendorBranding
    Optional. Example: Eclipse Temurin

.PARAMETER Description
    Optional. Example: "Development Kit with Hotspot".

.PARAMETER ProductMajorVersion
    Example: if the version is 17.0.15+6, this is 17.

.PARAMETER ProductMinorVersion
    Example: if the version is 17.0.15+6, this is 0.

.PARAMETER ProductMaintenanceVersion
    Example: if the version is 17.0.15+6, this is 15.

.PARAMETER ProductBuildNumber
    Example: if the version is 17.0.15+6, this is 6.

.PARAMETER Arch
    Examples: x86, x64, arm64.

.PARAMETER PublisherCN
    Set this to anything on the right side of your `CN=` field in your .pfx file.
    This may include additional fields in the name, such as 'O=...', 'L=...', 'S=...', and/or others.

.PARAMETER SigningCertPath
    Optional. The path to the signing certificate (.pfx) file used to sign the package.
    If not provided, the script will not sign the package.

.PARAMETER SigningPassword
    Optional. The password for the signing certificate.
    Only needed if the SigningCertPath is provided.

.PARAMETER outputName
    Optional. The name of the output file without the file extension.
    If not provided, a default name will be generated based on the VendorBranding and version information.

.PARAMETER Quiet
    Optional. If specified, suppresses output messages. Recommended for use in automated scripts, or when downloading zip files from a URL.
    This is an alias for -q.

.EXAMPLE
    .\create_msix.ps1 -ZipFilePath "C:\path\to\file.zip" -Vendor "Eclipse Adoptium" -VendorBranding "Eclipse Temurin" -Description "Development Kit with Hotspot" -ProductMajorVersion 17 -ProductMinorVersion 0 -ProductMaintenanceVersion 15 -ProductBuildNumber 6 -Arch "x64" -PublisherCN "ExamplePublisher" -SigningCertPath "C:\path\to\cert.pfx" -SigningPassword "myPass"

.EXAMPLE
    .\create_msix.ps1 -ZipFileUrl "https://example.com/file.zip" -Vendor "Eclipse Adoptium" -VendorBranding "Eclipse Temurin" -Description "Development Kit with Hotspot" -ProductMajorVersion 21 -ProductMinorVersion 0 -ProductMaintenanceVersion 7 -ProductBuildNumber 6 -Arch "aarch64" -PublisherCN "ExamplePublisher" --outputName 'Eclipse-Temurin-21.0.7-aarch64' -Quiet

.NOTES
    Ensure the 'src' folder exists in the current directory before running the script.
#>

param (
    [Parameter(Mandatory = $false)]
    [string]$ZipFilePath,

    [Parameter(Mandatory = $false)]
    [string]$ZipFileUrl,

    [Parameter(Mandatory = $false)]
    [string]$Vendor = "Eclipse Adoptium",

    [Parameter(Mandatory = $false)]
    [string]$VendorBranding = "Eclipse Temurin",

    [Parameter(Mandatory = $false)]
    [string]$Description = "Development Kit with Hotspot",

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

    [Parameter(Mandatory = $true)]
    [string]$PublisherCN,

    [Parameter(Mandatory = $false)]
    [string]$SigningCertPath,

    [Parameter(Mandatory = $false)]
    [string]$SigningPassword,

    [Parameter(Mandatory = $false)]
    [string]$outputName,

    [Parameter(Mandatory = $false, HelpMessage = "Include this flag to output verbose messages.")]
    [Alias("v")]
    [switch]$VerboseOutput
)

###### Validate inputs
if (-not $ZipFilePath -and -not $ZipFileUrl) {
    throw "Error: You must provide either -ZipFilePath or -ZipFileUrl."
}
if ($ZipFilePath -and $ZipFileUrl) {
    throw "Error: You cannot provide both -ZipFilePath and -ZipFileUrl."
}
if (($SigningPassword -and -not $SigningCertPath) -or ($SigningCertPath -and -not $SigningPassword)) {
    throw "Error: Both SigningCertPath and SigningPassword must be provided together."
}
# Set $ProgressPreference to 'SilentlyContinue' if the the verbose flag is not set
if (-not $VerboseOutput) {
    $OriginalProgressPreference = $global:ProgressPreference
    $global:ProgressPreference = 'SilentlyContinue'
}
###### End: Validate inputs

###### Set environment variables
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
# Run the SetupEnv.ps1 script located in the scripts folder
# Sets $Env:Windows_tools_base, $Env:srcFolder, $Env:workspace, $Env:output, $Env:appxTemplate, and $Env:priConfig env vars
# Cleans src and workspace folders
$setupEnvScriptPath = Join-Path -Path $scriptPath -ChildPath "scripts\SetupEnv.ps1"
if (-not (Test-Path -Path $setupEnvScriptPath)) {
    throw "Error: The SetupEnv.ps1 script was not found at '$setupEnvScriptPath'."
}
& $setupEnvScriptPath
Write-Host "Environment setup script executed successfully."
###### End: Set environment variables

# Handles local zip file
if ($ZipFilePath) {
    if (-not (Test-Path -Path $ZipFilePath)) {
        throw "Error: The file at path '$ZipFilePath' does not exist."
    }
    # Copy and unzip the file
    Expand-Archive -Path $ZipFilePath -DestinationPath $Env:workspace -Force
    Write-Host "Zip file extracted to 'workspace' folder."
}
# Handles zip from URL
elseif ($ZipFileUrl) {
    $fileName = [System.IO.Path]::GetFileName($ZipFileUrl)
    $downloadPath = Join-Path -Path $Env:workspace -ChildPath $fileName

    # download zip file (needs to be silent or it will print the progress bar and take ~10 times as long to download)
    $OriginalLocalProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $ZipFileUrl -OutFile $downloadPath
    $ProgressPreference = $OriginalLocalProgressPreference

    # unzip file
    Expand-Archive -Path $downloadPath -DestinationPath $Env:workspace -Force
    # remove zip file since conentets are extracted
    Remove-Item -Path $downloadPath -Force
    Write-Host "Zip file downloaded and extracted to 'workspace' folder."
}

# Move contents of the unzipped file to $Env:srcFolder
$unzippedFolder = Join-Path -Path $Env:workspace -ChildPath (Get-ChildItem -Path $Env:workspace -Directory | Select-Object -First 1).Name
Move-Item -Path (Join-Path -Path $unzippedFolder -ChildPath "*") -Destination $Env:srcFolder -Force
Remove-Item -Path $unzippedFolder -Recurse -Force

# Read the content of the appx template (path from SetupEnv.ps1)
$content = Get-Content -Path $Env:appxTemplate

# Create a variable by replacing spaces and underscores with dashes in $VendorBranding
$vendorBrandingDashes = $VendorBranding -replace "[ _]", "-"
if (-not $outputName) {
    $outputName = "$vendorBrandingDashes-$ProductMajorVersion.$ProductMinorVersion.$ProductMaintenanceVersion-$ProductBuildNumber-$Arch"
}
# Replace all instances of placeholders with the provided values
$updatedContent = $content `
    -replace "\{VENDOR\}", $Vendor `
    -replace "\{VENDOR_BRANDING\}", $VendorBranding `
    -replace "\{VENDOR_BRANDING_DASHES\}", $vendorBrandingDashes `
    -replace "\{OUTPUT_NAME\}", $outputName `
    -replace "\{DESCRIPTION\}", $Description `
    -replace "\{PRODUCT_MAJOR_VERSION\}", $ProductMajorVersion `
    -replace "\{PRODUCT_MINOR_VERSION\}", $ProductMinorVersion `
    -replace "\{PRODUCT_MAINTENANCE_VERSION\}", $ProductMaintenanceVersion `
    -replace "\{PRODUCT_BUILD_NUMBER\}", $ProductBuildNumber `
    -replace "\{ARCH\}", $Arch `
    -replace "\{PUBLISHER_CN\}", $PublisherCN


# Write the updated content to the new AppXManifest.xml file
$appxManifestPath = Join-Path -Path $Env:srcFolder -ChildPath "AppXManifest.xml"
Set-Content -Path $appxManifestPath -Value $updatedContent
Write-Host "AppXManifest.xml created at '$appxManifestPath'"

# Copy pri_config.xml to the target folder (path from SetupEnv.ps1)
Copy-Item -Path $Env:priConfig -Destination $Env:srcFolder -Force
Write-Host "pri_config.xml copied to '$Env:srcFolder'"

& "$Env:Windows_tools_base\makepri.exe" new `
    /o `
    /pr $Env:srcFolder `
    /cf "$Env:srcFolder\pri_config.xml" `
    /of "$Env:srcFolder\_resources.pri" `
    /mf appx

& "$Env:Windows_tools_base\makeappx.exe" pack `
    /o `
    /d "$Env:srcFolder" `
    /p "$Env:output\$outputName.msix"


if ($SigningCertPath) {
    & "$Env:Windows_tools_base\signtool.exe" sign `
        /fd SHA256 `
        /a `
        /f $SigningCertPath `
        /p "$SigningPassword" `
        "$Env:output\$outputName.msix"
    Write-Host "MSIX package signed successfully."
}
else {
    Write-Host "SigningCertPath not provided. Skipping signing process."
}

# Set $ProgressPreference back to its original value
if (-not $VerboseOutput) {
    $global:ProgressPreference = $OriginalProgressPreference
}