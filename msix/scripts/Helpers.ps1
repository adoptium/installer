
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
        Write-Output "ZipFile input validation passed."
    }
}

function ValidateSigningInput {
    param (
        [string]$SigningCertPath,
        [string]$SigningPassword
    )
    if (
        ($SigningPassword -and -not $SigningCertPath)
        -or
        ($SigningCertPath -and -not $SigningPassword)
        ) {
        throw "Error: Both SigningCertPath and SigningPassword must be provided together."
    }
    else {
        Write-Output "Signing input validation passed."
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

    Write-Output "Downloading file from $Url to $DestinationDirectory"

    # download zip file (needs to be silent or it will print the progress bar and take ~10 times as long to download)
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
    Write-Output "Unzipping file $ZipFilePath to $DestinationPath"
    Expand-Archive -Path $ZipFilePath -DestinationPath $DestinationPath -Force
}

