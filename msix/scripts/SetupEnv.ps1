
# Set default windows SDK version to use if not already set
if (-not $Env:WIN_SDK_FULL_VERSION) {
    $Env:WIN_SDK_FULL_VERSION = "10.0.22621.0"
}
if (-not $Env:WIN_SDK_MAJOR_VERSION) {
    $Env:WIN_SDK_MAJOR_VERSION = "10"
}
Write-Host "WIN_SDK_FULL_VERSION is set to $Env:WIN_SDK_FULL_VERSION."
Write-Host "WIN_SDK_MAJOR_VERSION is set to $Env:WIN_SDK_MAJOR_VERSION."
$Env:Windows_tools_base = "$Env:ProgramFiles (x86)\Windows Kits\$Env:WIN_SDK_MAJOR_VERSION\bin\$Env:WIN_SDK_FULL_VERSION\$Arch"

# Set path to src folder
$Env:srcFolder = Join-Path -Path $scriptPath -ChildPath "src"
# Clean src folder by deleting all contents of the src folder except what is in src\_msix_logos
Get-ChildItem -Path $Env:srcFolder -Recurse | Where-Object {
    $_.FullName -notlike "*\_msix_logos*"
} | Remove-Item -Recurse -Force

# Ensure 'workspace' folder exists
$Env:workspace = Join-Path -Path $scriptPath -ChildPath "workspace"
if (-not (Test-Path -Path $Env:workspace)) {
    New-Item -ItemType Directory -Path $Env:workspace | Out-Null
}
# Clean workspace folder by deleting all contents
Get-ChildItem -Path $Env:workspace -Recurse | Remove-Item -Recurse -Force

# Ensure 'output' folder exists
$Env:output = Join-Path -Path $scriptPath -ChildPath "output"
if (-not (Test-Path -Path $Env:output)) {
    New-Item -ItemType Directory -Path $Env:output | Out-Null
}
# Clean output folder by deleting all contents
Get-ChildItem -Path $Env:output -Recurse | Remove-Item -Recurse -Force

## Update the file content of AppXManifest.xml
# Define the path to the file
$Env:appxTemplate = Join-Path -Path $scriptPath -ChildPath "templates\AppXManifestTemplate.xml"
$Env:priConfig = Join-Path -Path $scriptPath -ChildPath "templates\pri_config.xml"