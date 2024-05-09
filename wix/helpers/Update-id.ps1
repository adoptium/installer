<#
.SYNOPSIS
This script appends a suffix to Directory IDs to ensure they're unique> This is necessary because IDs are hashes of folder names and some subdirectories have the same name (like 'bin').

.DESCRIPTION
The script takes a .wxs file path, a directory name, and a suffix as input parameters. It reads the content of the .wxs file, searches for the line that matches the pattern of the specified directory name, and appends the suffix to the corresponding Directory ID. It then writes the updated content back to the file.

.PARAMETER FilePath
The path of the .wxs file to be updated.

.PARAMETER Name
The name of the directory whose ID needs to be updated.

.PARAMETER Suffix
The suffix to be appended to the Directory ID.

.EXAMPLE
Update-id.ps1 -FilePath "C:\Path\To\File.wxs" -Name "bin" -Suffix "_unique"

This example updates the Directory ID of the "bin" directory in the specified .wxs file by appending "_unique" to the existing ID.

#>

param (
    [Parameter(Mandatory = $true)]
    [string]$FilePath,

    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$Suffix
)

# Read the content of the .wxs file
$fileContent = Get-Content -Path $FilePath

# Search for the line that matches the pattern
$pattern = '<Directory Id="(.*)" Name="' + [regex]::Escape($Name) + '"'

# Find the first match
$firstMatch = $fileContent | Where-Object { $_ -match $pattern } | Select-Object -First 1
if ($firstMatch -match $pattern) {
    $directoryId = $matches[1]
}

# If the directory ID is found, append the suffix to it's ID
if (-not $directoryId) {
    Write-Host "Directory '$Name' not found in the file."
}
else {
    $updatedDirectoryId = $directoryId + $Suffix

    # Replace declaration and references of the old ID with the updated ID
    $IdRegex = $('Id="' + [regex]::Escape($directoryId) + '"')
    $updatedContent = $fileContent | ForEach-Object {
        if ($_ -match $IdRegex) {
            # Replace Id declaration with the updated ID if IdRegex matches
            $_ -replace $IdRegex, $('Id="' + [regex]::Escape($updatedDirectoryId) + '"')
        }
        else {
            # Replace all Directory ID references to the old ID with the updated ID
            $_ -replace $('Directory="' + [regex]::Escape($directoryId) + '"'), $('Directory="' + [regex]::Escape($updatedDirectoryId) + '"')
        }
    }

    # Write the updated content back to the file
    $updatedContent | Set-Content -Path $FilePath
}
