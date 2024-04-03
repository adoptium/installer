<#
.SYNOPSIS
    This script extracts the contents of a zip file to a directory structure that is expected by the Wix toolset.

.DESCRIPTION
    The script takes a zip file and extracts its contents to a directory structure that is expected by the Wix toolset.
    The script also performs some cleanup on the extracted files.

.PARAMETER openjdk_filename_regex
    A regular expression that matches the OpenJDK filename. Default is ^OpenJDK(?<major>\d*).

.PARAMETER platform_regex
    A regular expression that matches the platform. Default is (?<platform>x86-32|x64|aarch64).

.PARAMETER jvm_regex
    A regular expression that matches the JVM. Default is (?<jvm>hotspot|openj9|dragonwell).

.PARAMETER jvm
    The JVM to be used. If not provided, the script will attempt to extract the JVM from the filename.

.PARAMETER wix_version
    The version wix that is currently installed.
    Used to determine WixToolset.Heat version to be installed. Default is 4.0.5.

.NOTES
    File Name: CreateSourceFolder.AdoptOpenJDK.ps1
    Author   : AdoptOpenJDK
    Version  : 1.0
    Date     : March. 01, 2024

.EXAMPLE
    PS> .\CreateSourceFolder.AdoptOpenJDK.ps1 -openjdk_filename_regex "^OpenJDK(?<major>\d*)" -platform_regex "(?<platform>x86-32|x64|aarch64)" -jvm_regex "(?<jvm>hotspot|openj9|dragonwell)" -jvm "hotspot"

#>

param (
    [Parameter(Mandatory = $false)]
    [string]$openjdk_filename_regex = "^OpenJDK(?<major>\d*)",
    [Parameter(Mandatory = $false)]
    [string]$platform_regex = "(?<platform>x86-32|x64|aarch64)",
    [Parameter(Mandatory = $false)]
    [string]$jvm_regex = "(?<jvm>hotspot|openj9|dragonwell)",
    [Parameter(Mandatory = $false)]
    [string]$jvm = "",
    [Parameter(Mandatory = $false)]
    [string]$wix_version = "4.0.5"
)

Get-ChildItem -Path .\ -Filter *.zip -File -Name| ForEach-Object {
  
  $filename = [System.IO.Path]::GetFileName($_)
  Write-Output "Processing filename : $filename"

  # validate that the zip file is OpenJDK with an optional major version number
  $openjdk_found = $filename -match $openjdk_filename_regex
  if (!$openjdk_found) {
    Write-Output "filename : $filename doesn't match regex $openjdk_filename_regex"
    exit 2
  }

  $openjdk_basedir="OpenJDK"
  if ([string]::IsNullOrEmpty($matches.major)) {
    # put unnumbered OpenJDK filename into OpenJDK-Latest directory
    # see Build.OpenJDK_generic.cmd who's going to look at it
    $major=$openjdk_basedir + "-Latest"
  } else {
    $major=$openjdk_basedir + $Matches.major
  }

  if ([string]::IsNullOrEmpty($jvm)) {

    $jvm_found = $filename -match $jvm_regex
    if (!$jvm_found) {
      Write-Output "filename : $filename doesn't match regex $jvm_regex"
      exit 2
    }
    $jvm = $Matches.jvm

  }

  # Windows Architecture supported
  $platform_found = $filename -match $platform_regex
  if (!$platform_found) {
    Write-Output "filename : $filename doesn't match regex $platform_regex"
    exit 2
  }
  $platform = $Matches.platform

  # Wix toolset expects this to be called arm64
  if ($platform -eq "aarch64") {
    $platform="arm64"
  }

  # extract now
  $unzip_dest = ".\$major\$jvm\$platform"
  Write-Output "Extracting $filename to $unzip_dest"
  Expand-Archive -Force -Path $filename -DestinationPath $unzip_dest

  # do some cleanup in path
  Get-ChildItem -Directory $unzip_dest | Where-Object {$_ -match ".*_.*"} | ForEach-Object {
    $SourcePath = [System.IO.Path]::GetDirectoryName($_.FullName)

    if ( $_.Name -Match "(.*)_(.*)-jre$" ) {
        $NewName = $_.Name -replace "(.*)_(.*)$",'$1-jre'
    } elseif ( $_.Name -Match "(.*)_(.*)$" ) {
        $NewName = $_.Name -replace "(.*)_(.*)$",'$1'
    }

    $Destination = Join-Path -Path $SourcePath -ChildPath $NewName

    if (Test-Path $Destination) { Remove-Item $Destination -Recurse; }
    Move-Item -Path $_.FullName -Destination $Destination -Force
  }
}

# Install wixtoolset.heat.4.0.5
Write-Host "Installing WixToolset.Heat version $wix_version"
mkdir wix_extension
$sourceURI = 'https://www.nuget.org/api/v2/package/WixToolset.Heat/' + $wix_version
$outFile = '.\wix_extension\wixtoolset.heat.' + $wix_version + '.zip'
Invoke-WebRequest -Uri $sourceURI -OutFile $outFile
Expand-Archive -Path "$outFile" -DestinationPath ./wix_extension/

# Determine the architecture of the operating system
if ([Environment]::Is64BitOperatingSystem) {
  Write-Output "x64 operating system"
  $current_arch = "x64"
}
else {
  Write-Output "x86 operating system"
  $current_arch = "x86"
}

# Set the path to heat.exe for later use
$env:WIX_HEAT_PATH = (Get-ChildItem -Path .\wix_extension -Recurse -Filter "heat.exe").FullName | Select-String -Pattern "$current_arch"
Write-Host "wixtoolset.heat.exe path saved at location $env:WIX_HEAT_PATH"