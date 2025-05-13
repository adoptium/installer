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

.EXAMPLE
    .\create_msix.ps1 -ZipFilePath "C:\path\to\file.zip" -Vendor "Eclipse Adoptium" -VendorBranding "Eclipse Temurin" -Description "Development Kit with Hotspot" -ProductMajorVersion 17 -ProductMinorVersion 0 -ProductMaintenanceVersion 15 -ProductBuildNumber 6 -Arch "x64" -PublisherCN "ExamplePublisher" -SigningCertPath "C:\path\to\cert.pfx" -SigningPassword "myPass"

.EXAMPLE
    .\create_msix.ps1 -ZipFileUrl "https://example.com/file.zip" -Vendor "Eclipse Adoptium" -VendorBranding "Eclipse Temurin" -Description "Development Kit with Hotspot" -ProductMajorVersion 21 -ProductMinorVersion 0 -ProductMaintenanceVersion 7 -ProductBuildNumber 6 -Arch "aarch64" -PublisherCN "ExamplePublisher"

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
    [string]$Description = "Development Kit with Hotspot"

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
)

# Validate inputs
if (-not $ZipFilePath -and -not $ZipFileUrl) {
    throw "Error: You must provide either -ZipFilePath or -ZipFileUrl."
}
if ($ZipFilePath -and $ZipFileUrl) {
    throw "Error: You cannot provide both -ZipFilePath and -ZipFileUrl."
}

# Ensure 'src' folder exists
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcFolder = Join-Path -Path $scriptPath -ChildPath "src"
if (-not (Test-Path -Path $srcFolder)) {
    New-Item -ItemType Directory -Path $srcFolder | Out-Null
}

# Handle ZipFilePath
if ($ZipFilePath) {
    if (-not (Test-Path -Path $ZipFilePath)) {
        throw "Error: The file at path '$ZipFilePath' does not exist."
    }
    $destinationPath = Join-Path -Path $srcFolder -ChildPath (Split-Path -Leaf $ZipFilePath)
    # Copy and unzip the file
    Copy-Item -Path $ZipFilePath -Destination $destinationPath
    Expand-Archive -Path $destinationPath -DestinationPath $srcFolder -Force
    # Remove the zip file since contents are extracted
    Remove-Item -Path $destinationPath -Force
    Write-Host "Zip file copied and extracted to 'src' folder."
}

# Handle ZipFileUrl
if ($ZipFileUrl) {
    $fileName = [System.IO.Path]::GetFileName($ZipFileUrl)
    $downloadPath = Join-Path -Path $srcFolder -ChildPath $fileName
    # download zip file
    Invoke-WebRequest -Uri $ZipFileUrl -OutFile $downloadPath
    # unzip file
    Expand-Archive -Path $downloadPath -DestinationPath $srcFolder -Force
    # remove zip file since conentets are extracted
    Remove-Item -Path $downloadPath -Force
    Write-Host "Zip file downloaded and extracted to 'src' folder."
}

## Update the file content of AppXManifest.xml
# Define the path to the file
$appxTemplate = Join-Path -Path $scriptPath -ChildPath "tempaltes\AppXManifestTemplate.xml"
$priConfig = Join-Path -Path $scriptPath -ChildPath "tempaltes\pri_config.xml"

# Read the content of the file
$content = Get-Content -Path $appxTemplate

# Create a variable by replacing spaces and underscores with dashes in $VendorBranding
$vendorBrandingDashes = $VendorBranding -replace "[ _]", "-"

# Replace all instances of placeholders with the provided values
$updatedContent = $content `
    -replace "\{VENDOR\}", $Vendor `
    -replace "\{VENDORBRANDING\}", $VendorBranding `
    -replace "\{VENDORBRANDINGDASHES\}", $vendorBrandingDashes `
    -replace "\{DESCRIPTION\}", $Description `
    -replace "\{PRODUCTMAJORVERSION\}", $ProductMajorVersion `
    -replace "\{PRODUCTMINORVERSION\}", $ProductMinorVersion `
    -replace "\{PRODUCTMAINTENANCEVERSION\}", $ProductMaintenanceVersion `
    -replace "\{PRODUCTBUILDNUMBER\}", $ProductBuildNumber `
    -replace "\{ARCH\}", $Arch `
    -replace "\{PUBLISHERCN\}", $PublisherCN


# Ensure there is only one folder in the 'src' directory
$subFolders = Get-ChildItem -Path $srcFolder -Directory
if ($subFolders.Count -ne 1) {
    throw "Error: The 'src' folder must contain exactly one subfolder."
}

# Define the path to the new AppXManifest.xml file
$targetFolder = $subFolders[0].FullName
$appxManifestPath = Join-Path -Path $targetFolder -ChildPath "AppXManifest.xml"

# Write the updated content to the new AppXManifest.xml file
Set-Content -Path $appxManifestPath -Value $updatedContent
Write-Host "AppXManifest.xml created at '$appxManifestPath'"

# Copy pri_config.xml to the target folder
Copy-Item -Path $priConfig -Destination $targetFolder -Force
Write-Host "pri_config.xml copied to '$targetFolder'"

makepri.exe new `
    /o `
    /pr $targetFolder `
    /cf $targetFolder\pri_config.xml `
    /of $targetFolder\_resources.pri `
    /mf appx

makeappx.exe pack `
    /o `
    /d $targetFolder `
    /p $vendorBrandingDashes-$ProductMajorVersion.$ProductMinorVersion.$ProductMaintenanceVersion-$ProductBuildNumber-$Arch.msix


if ($SigningCertPath) {
    # Run signtool to sign the package without printing to logs (keeps password secret)
    Start-Process -FilePath "signtool.exe" -ArgumentList @(
        "sign",
        "/fd", "SHA256",
        "/a",
        "/f", $SigningCertPath,
        "/p", $SigningPassword,
        ".\$vendorBrandingDashes-$ProductMajorVersion.$ProductMinorVersion.$ProductMaintenanceVersion-$ProductBuildNumber-$Arch.msix"
    ) -NoNewWindow -Wait -PassThru | Out-Null
    Write-Host "MSIX package signed successfully."
} else {
    Write-Host "SigningCertPath not provided. Skipping signing process."
}