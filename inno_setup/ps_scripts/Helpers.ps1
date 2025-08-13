<#
.SYNOPSIS
    Helper functions for OpenJDK EXE packaging scripts.

.DESCRIPTION
    This script provides utility functions for validating input, downloading files, unzipping archives, and handling signing parameters.
    Intended for use in the OpenJDK EXE installer build process via Inno Setup.

.NOTES
    File Name:  Helpers.ps1

#>

function ValidateZipFileInput {
    param (
        [string]$ZipFilePath,
        [string]$ZipFileUrl
    )
    if (-not $ZipFilePath -and -not $ZipFileUrl) {
        throw "Error: You must provide either -ZipFilePath or -ZipFileUrl."
    }
    elseif ($ZipFilePath -and $ZipFileUrl) {
        throw "Error: You cannot provide both -ZipFilePath and -ZipFileUrl."
    }
    else {
        Write-Host "ZipFile input validation passed."
    }
}

function SetDefaultIfEmpty {
    param (
        [string]$InputValue,
        [string]$DefaultValue
    )
    if (-not $InputValue) {
        return $DefaultValue
    }
    else {
        return $InputValue
    }
}

function DownloadFileFromUrl {
    param (
        [string]$Url,
        [string]$DestinationDirectory
    )
    if (-not (Test-Path -Path $DestinationDirectory)) {
        New-Item -ItemType Directory -Path $DestinationDirectory | Out-Null
    }
    $fileName = [System.IO.Path]::GetFileName($ZipFileUrl)
    $downloadPath = Join-Path -Path $DestinationDirectory -ChildPath $fileName

    Write-Host "Downloading file from $Url to $DestinationDirectory"

    # download zip file (needs to be silent or it will print the progress bar and take ~30 times as long to download)
    $OriginalLocalProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $Url -OutFile $downloadPath
    $ProgressPreference = $OriginalLocalProgressPreference

    return $downloadPath
}

function UnzipFile {
    param (
        [string]$ZipFilePath,
        [string]$DestinationPath
    )
    if (-not (Test-Path -Path $ZipFilePath)) {
        throw "Error: Zip file not found at path: $ZipFilePath"
    }
    if (-not (Test-Path -Path $DestinationPath)) {
        New-Item -ItemType Directory -Path $DestinationPath | Out-Null
    }
    Write-Host "Unzipping file $ZipFilePath to $DestinationPath"

    # Unzip file (needs to be silent or it will print the progress bar and take much longer)
    $OriginalProgressPreference = $global:ProgressPreference
    $global:ProgressPreference = 'SilentlyContinue'
    Expand-Archive -Path $ZipFilePath -DestinationPath $DestinationPath -Force
    $global:ProgressPreference = $OriginalProgressPreference
}

function CheckForError {
    param (
        [string]$ErrorMessage
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Error: $ErrorMessage"
    }
}

function CapitalizeString {
    param (
        [Parameter(Mandatory=$true)]
        [string]$InputString,
        [Parameter(Mandatory=$false)]
        [switch]$AllLetters
    )

    if ([string]::IsNullOrEmpty($InputString)) {
        return $InputString
    }

    if ($AllLetters) {
        # Capitalize all letters (uppercase)
        return $InputString.ToUpper()
    } else {
        # Capitalize only the first letter
        return $InputString.Substring(0, 1).ToUpper() + $InputString.Substring(1).ToLower()
    }
}

function Clear-TargetFolder {
    param(
        [string]$TargetFolder,
        [string]$ExcludeSubfolder = $null
    )
    if (-not (Test-Path -Path $TargetFolder)) {
        New-Item -ItemType Directory -Path $TargetFolder | Out-Null
        Write-Host "Created folder: $TargetFolder"
    }

    if ($ExcludeSubfolder) {
        Get-ChildItem -Path $TargetFolder -Recurse | Where-Object {
            $_.FullName -notlike "*\$ExcludeSubfolder*"
        } | Remove-Item -Recurse -Force
        Write-Host "Cleaned $TargetFolder, excluding $ExcludeSubfolder."
    }
    else {
        Get-ChildItem -Path $TargetFolder -Recurse | Remove-Item -Recurse -Force
        Write-Host "Cleaned $TargetFolder."
    }

    return $TargetFolder
}

function GenerateGuidFromString {
    param(
        [string] $SeedString = ""
    )
    $md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $utf8 = new-object -TypeName System.Text.UTF8Encoding
    $hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($SeedString))) -replace "-", ""
    $guid = [System.Guid]::Parse($hash)
    Write-Output $guid.ToString('b').ToUpper()
}