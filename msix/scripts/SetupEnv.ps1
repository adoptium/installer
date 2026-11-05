<#
.SYNOPSIS
    Helper script for defining functions that help setup the build environment.

.DESCRIPTION
    This script provides a helper function to assist with build environment setup.
    It includes functions to get the path to the Windows SDK and to clean a target folder.

.NOTES
    File Name:  SetupEnv.ps1
#>

function Get-WindowsSdkPath {
    param(
        [string]$Arch,
        [string]$WIN_SDK_FULL_VERSION = $null,
        [string]$WIN_SDK_MAJOR_VERSION = $null
    )

    # Set defaults if parameters are not provided
    if (-not $WIN_SDK_FULL_VERSION) {
        $WIN_SDK_FULL_VERSION = "10.0.22621.0"
    }
    if (-not $WIN_SDK_MAJOR_VERSION) {
        $WIN_SDK_MAJOR_VERSION = "10"
    }

    Write-Host "WIN_SDK_FULL_VERSION is set to $WIN_SDK_FULL_VERSION."
    Write-Host "WIN_SDK_MAJOR_VERSION is set to $WIN_SDK_MAJOR_VERSION."

    $WindowsSdkPath = Join-Path -Path "${Env:ProgramFiles(x86)}\Windows Kits\$WIN_SDK_MAJOR_VERSION\bin\$WIN_SDK_FULL_VERSION" -ChildPath $Arch

    return $WindowsSdkPath
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