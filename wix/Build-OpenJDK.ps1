<#
    FILEPATH: /c:/dev/openjdk-installer/wix/Build-OpenJDK.ps1
    Script: Build-OpenJDK.ps1
    Description: PowerShell script to build Windows installers for the OpenJDK using the WiX Toolset
    Author: Josh Martin-Jaffe
    Date: Feb. 29, 2024

    .SYNOPSIS
    Build-OpenJDK.ps1 is a script used to build OpenJDK.

    .DESCRIPTION
    This script is used to build OpenJDK. It takes various parameters to configure the build process.

    .PARAMETER ProductMinorVersion
    The product minor version for the JDK.

    .EXAMPLE
    .\Build-OpenJDK.ps1 -ProductMajorVersion "15" -ProductMinorVersion "0" -ProductMaintenanceVersion "0" -ProductPatchVersion "0" -ProductBuildNumber "1" -MSIProductVersion "15.0.0.1" -Arch "x64" -JVM "hotspot" -ProductCategory "jdk"
#>

param (
    # Mandatory parameters
    [Parameter(Mandatory = $true, HelpMessage = "Specify the major version for the JDK.")]
    [string]$ProductMajorVersion,
    [Parameter(Mandatory = $true, HelpMessage = "Specify the minor version for the JDK.")]
    [string]$ProductMinorVersion,
    [Parameter(Mandatory = $true, HelpMessage = "Specify the maintenance version for the JDK.")]
    [string]$ProductMaintenanceVersion,
    [Parameter(Mandatory = $true, HelpMessage = "Specify the patch version for the JDK.")]
    [string]$ProductPatchVersion,
    [Parameter(Mandatory = $true, HelpMessage = "Specify the build number for the JDK.")]
    [string]$ProductBuildNumber,
    [Parameter(Mandatory = $true, HelpMessage = "Specify the MSI product version for the JDK.")]
    [string]$MSIProductVersion,
    [Parameter(Mandatory = $true, HelpMessage = "Specify the architecture for the JDK. Valid values are: x64, x86-32, x86, arm64, or any combination of them separated by spaces.")]
    [string]$Arch,
    [Parameter(Mandatory = $true, HelpMessage = "Specify the JVM for the JDK. Valid values are: hotspot, openj9, or any combination of them separated by spaces.")]
    [string]$JVM,
    [Parameter(Mandatory = $true, HelpMessage = "Specify the product category for the JDK. Valid values are: jdk, jre, or any combination of them separated by spaces.")]
    [string]$ProductCategory,
    # Optional parameters
    [Parameter(Mandatory = $false, HelpMessage = "Specify the product SKU for the JDK.")]
    [string]$Vendor = "Eclipse Adoptium",
    [Parameter(Mandatory = $false, HelpMessage = "Specify the vendor branding.")]
    [string]$VendorBranding = "Eclipse Temurin",
    [Parameter(Mandatory = $false, HelpMessage = "Specify the vendor branding logo.")]
    [string]$VendorBrandingLogo = "$(var.SetupResourcesDir)\logo.ico",
    [Parameter(Mandatory = $false, HelpMessage = "Specify the vendor branding banner.")]
    [string]$VendorBrandingBanner = "$(var.SetupResourcesDir)\wix-banner.png",
    [Parameter(Mandatory = $false, HelpMessage = "Specify the vendor branding dialog.")]
    [string]$VendorBrandingDialog = "$(var.SetupResourcesDir)\wix-dialog.png",
    [Parameter(Mandatory = $false, HelpMessage = "Specify the product help link.")]
    [string]$ProductHelpLink = "https://github.com/adoptium/adoptium-support/issues/new/choose",
    [Parameter(Mandatory = $false, HelpMessage = "Specify the product support link.")]
    [string]$ProductSupportLink = "https://adoptium.net/support",
    [Parameter(Mandatory = $false, HelpMessage = "Specify the product update info link.")]
    [string]$ProductUpdateInfoLink = "https://adoptium.net/temurin/releases"
)

if ($env:DEBUG -eq "true") { 
    $DebugPreference = "Continue"
}
else {
    $DebugPreference = "SilentlyContinue"
}

& powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\helpers\Validate-Input.ps1" `
    -toValidate $ARCH `
    -validInputs "x64", "x86-32", "x86", "arm64" `
    -delimiter " "

if ($LASTEXITCODE -eq 1) {
    Write-Host "ARCH $ARCH not supported : valid values are any combination of : x64, x86-32, arm64"
    exit 1
}

# Update to handle the change of build variant until implications
# of setting this to Temurin can be evaluated
if ($JVM -eq "temurin") {
    $JVM = "hotspot"
}

& powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\helpers\Validate-Input.ps1" `
    -toValidate $JVM `
    -validInputs "hotspot,openj9,dragonwell,openj9 hotspot,hotspot openj9" `
    -delimiter ","

if ($LASTEXITCODE -eq 1) {
    Write-Host "JVM '$JVM' not supported : valid values : hotspot, openj9, dragonwell, hotspot openj9, openj9 hotspot"
    goto FAILED
}

if ($PRODUCT_CATEGORY -ne "jre" -and $PRODUCT_CATEGORY -ne "jdk") {
    Write-Host "PRODUCT_CATEGORY '$PRODUCT_CATEGORY' not supported : valid values : jre, jdk"
    goto FAILED
}

if ($SKIP_MSI_VALIDATION -eq "true") {
    $MSI_VALIDATION_OPTION = " -sval "
}

# Configure available SDK version:
# See folder e.g. "C:\Program Files (x86)\Windows Kits\[10]\bin\[10.0.16299.0]\x64"
$WIN_SDK_MAJOR_VERSION = 10
$WIN_SDK_FULL_VERSION = "10.0.17763.0"
$WORKDIR = "Workdir"
New-Item -ItemType Directory -Path $WORKDIR | Out-Null

# Nothing below this line needs to be changed normally.

# Cultures: https://msdn.microsoft.com/de-de/library/ee825488(v=cs.20).aspx
$PRODUCT_SKU = "OpenJDK"
$PRODUCT_FULL_VERSION = "$PRODUCT_MAJOR_VERSION.$PRODUCT_MINOR_VERSION.$PRODUCT_MAINTENANCE_VERSION.$PRODUCT_PATCH_VERSION.$PRODUCT_BUILD_NUMBER"

$PRODUCT_SHORT_VERSION = "$PRODUCT_MAJOR_VERSION$PRODUCT_MAINTENANCE_VERSION-b$PRODUCT_BUILD_NUMBER"
if ($PRODUCT_CATEGORY -eq "jre") {
    $JRE = "-jre"
}
if ($PRODUCT_MAJOR_VERSION -ge 10) {
    if ($PRODUCT_BUILD_NUMBER) {
        $BUILD_NUM = "+$PRODUCT_BUILD_NUMBER"
    }
    $PRODUCT_SHORT_VERSION = $PRODUCT_MAJOR_VERSION
    if ($PRODUCT_MINOR_VERSION -ne "0") {
        $PRODUCT_SHORT_VERSION = "$PRODUCT_MAJOR_VERSION.$PRODUCT_MINOR_VERSION"
    }
    if ($PRODUCT_MAINTENANCE_VERSION -ne "0") {
        $PRODUCT_SHORT_VERSION = "$PRODUCT_MAJOR_VERSION.$PRODUCT_MINOR_VERSION.$PRODUCT_MAINTENANCE_VERSION"
    }
    if ($PRODUCT_PATCH_VERSION -ne "0") {
        $PRODUCT_SHORT_VERSION = "$PRODUCT_MAJOR_VERSION.$PRODUCT_MINOR_VERSION.$PRODUCT_MAINTENANCE_VERSION.$PRODUCT_PATCH_VERSION"
    }
    $PRODUCT_SHORT_VERSION = "$PRODUCT_SHORT_VERSION$BUILD_NUM"
}

Write-Debug "PRODUCT_FULL_VERSION=$PRODUCT_FULL_VERSION"
Write-Debug "PRODUCT_SHORT_VERSION=$PRODUCT_SHORT_VERSION"


# Generate platform specific builds (x86-32,x64, arm64)
foreach ($A in $ARCH.Split(',')) {
    # We could build both "hotspot,openj9" in one script, but it is not clear if release cycle is the same.
    foreach ($J in $JVM.Split(',')) {
        $PACKAGE_TYPE = $J
        $PLATFORM = $A
        Write-Debug "Generate OpenJDK setup '$PACKAGE_TYPE' for '$PLATFORM' platform '$PRODUCT_CATEGORY'"
        Write-Debug "****************************************************"
        $CULTURE = "en-us"
        $LANGIDS = 1033
        $FOLDER_PLATFORM = $PLATFORM
        if ($PLATFORM -eq "x86-32") {
            $PLATFORM = "x86"
        }

        $SETUP_RESOURCES_DIR = ".\Resources"

        foreach ($P in @(
                "$PRODUCT_SKU$PRODUCT_MAJOR_VERSION\$PACKAGE_TYPE\$FOLDER_PLATFORM\jdk-$PRODUCT_MAJOR_VERSION.$PRODUCT_MINOR_VERSION.$PRODUCT_MAINTENANCE_VERSION",
                "$PRODUCT_SKU$PRODUCT_MAJOR_VERSION\$PACKAGE_TYPE\$FOLDER_PLATFORM\jdk$PRODUCT_MAJOR_VERSIONu$PRODUCT_MAINTENANCE_VERSION-b$PRODUCT_BUILD_NUMBER",
                "$PRODUCT_SKU$PRODUCT_MAJOR_VERSION\$PACKAGE_TYPE\$FOLDER_PLATFORM\jdk-$PRODUCT_MAJOR_VERSION+$PRODUCT_BUILD_NUMBER",
                "$PRODUCT_SKU$PRODUCT_MAJOR_VERSION\$PACKAGE_TYPE\$FOLDER_PLATFORM\jdk-$PRODUCT_MAJOR_VERSION.$PRODUCT_MINOR_VERSION.$PRODUCT_MAINTENANCE_VERSION+$PRODUCT_BUILD_NUMBER",
                "$PRODUCT_SKU$PRODUCT_MAJOR_VERSION\$PACKAGE_TYPE\$FOLDER_PLATFORM\jdk-$PRODUCT_MAJOR_VERSION.$PRODUCT_MINOR_VERSION.$PRODUCT_MAINTENANCE_VERSION.$PRODUCT_PATCH_VERSION+$PRODUCT_BUILD_NUMBER",
                "$PRODUCT_SKU-Latest\$PACKAGE_TYPE\$FOLDER_PLATFORM\jdk-$PRODUCT_SHORT_VERSION"
            )) {
            $REPRO_DIR = ".\SourceDir\$P"
            if ($PRODUCT_CATEGORY -eq "jre") {
                $REPRO_DIR = "$REPRO_DIR-$PRODUCT_CATEGORY"
            }
            Write-Debug "looking for $REPRO_DIR"
            if (Test-Path $REPRO_DIR) {
                goto CONTINUE
            }
        }
    
        Write-Debug "SOURCE Dir not found / failed"
        Write-Debug "Listing directory :"
        Get-ChildItem -Path SourceDir -Recurse -Directory | Select-Object -ExpandProperty FullName
        goto FAILED

        :CONTINUE
        Write-Debug "Source dir used: $REPRO_DIR"

        $OUTPUT_BASE_FILENAME = "$PRODUCT_SKU$PRODUCT_MAJOR_VERSION-$PRODUCT_CATEGORY`_$FOLDER_PLATFORM`_windows_$PACKAGE_TYPE-$PRODUCT_FULL_VERSION"
        # find all *.wxi.template,*.wxl.template,*.wxs.template files and replace text with configurations
        Get-ChildItem -Path . -Recurse -Include *.wxi.template, *.Base.*.wxl.template, *.!JVM!.*.wxl.template, *.wxs.template | ForEach-Object {
            $INPUT_FILE = $_.Name
            # Prevent concurrency issues if multiple builds are running in parallel.
            $OUTPUT_FILE = "$WORKDIR$OUTPUT_BASE_FILENAME-$($INPUT_FILE -replace '.template$')"
            Write-Debug "string replacement input $INPUT_FILE output $OUTPUT_FILE"
            try {
                $content = Get-Content -Path $_.FullName -Raw -Encoding UTF8
                $content = $content -replace '{vendor}', '!VENDOR!' -replace '{vendor_branding_logo}', '!VENDOR_BRANDING_LOGO!' -replace '{vendor_branding_banner}', '!VENDOR_BRANDING_BANNER!' -replace '{vendor_branding_dialog}', '!VENDOR_BRANDING_DIALOG!' -replace '{vendor_branding}', '!VENDOR_BRANDING!' -replace '{product_help_link}', '!PRODUCT_HELP_LINK!' -replace '{product_support_link}', '!PRODUCT_SUPPORT_LINK!' -replace '{product_update_info_link}', '!PRODUCT_UPDATE_INFO_LINK!'
                $content | Out-File -Encoding UTF8 -FilePath $OUTPUT_FILE
            }
            catch {
                Write-Debug "Unable to make string replacement"
                goto FAILED
            }
        }

        $CACHE_BASE_FOLDER = "Cache"
        # Each build has its own cache for concurrent build
        $CACHE_FOLDER = "$CACHE_BASE_FOLDER\$OUTPUT_BASE_FILENAME"

        # Generate one ID per release. But do NOT use * as we need to keep the same number for all languages, but not platforms.
        $PRODUCT_ID = [guid]::NewGuid().ToString('B').ToUpper()
        Write-Debug "PRODUCT_ID: $PRODUCT_ID"

        if (-not $env:UPGRADE_CODE_SEED) {
            # If no UPGRADE_CODE_SEED given .. we are not trying to build upgradable MSI and generate always a new PRODUCT_UPGRADE_CODE
            $PRODUCT_UPGRADE_CODE = [guid]::NewGuid().ToString('B').ToUpper()
            Write-Debug "Uniq PRODUCT_UPGRADE_CODE: $PRODUCT_UPGRADE_CODE"
        }
        else {
            # It will be better if we can generate "Name-based UUID" as specified here https://tools.ietf.org/html/rfc4122#section-4.3
            # but it's too difficult so fallback to random like guid based on md5 hash with getGuid.ps1
            # We use md5 hash to always get the same PRODUCT_UPGRADE_CODE(GUID) for each MSI build with same GUID_SSED to allow upgrade from Adoptium
            # IF PRODUCT_UPGRADE_CODE change from build to build, upgrade is not proposed by Windows Installer
            # Never change what compose SOURCE_TEXT_GUID and args0 for getGuid.ps1 or you will never get the same GUID as previous build and MSI upgradable feature wont work
            $SOURCE_TEXT_GUID = "$PRODUCT_CATEGORY-$PRODUCT_MAJOR_VERSION-$PLATFORM-$PACKAGE_TYPE"
            Write-Debug "SOURCE_TEXT_GUID (without displaying secret UPGRADE_CODE_SEED): $SOURCE_TEXT_GUID"
            $PRODUCT_UPGRADE_CODE = .\getGuid.ps1 "$SOURCE_TEXT_GUID-$env:UPGRADE_CODE_SEED"
            Write-Debug "Constant PRODUCT_UPGRADE_CODE: $PRODUCT_UPGRADE_CODE"
        }


        # # Build with extra Source Code feature (needs work)
        # & "$WIX\bin\heat.exe" file "$REPRO_DIR\lib\src.zip" -out "Src-$OUTPUT_BASE_FILENAME.wxs" -gg -srd -cg "SrcFiles" -var var.ReproDir -dr INSTALLDIR -platform $PLATFORM
        # & "$WIX\bin\heat.exe" dir "$REPRO_DIR" -out "Files-$OUTPUT_BASE_FILENAME.wxs" -t "$SETUP_RESOURCES_DIR\heat.tools.xslt" -gg -sfrag -scom -sreg -srd -ke -cg "AppFiles" -var var.ProductMajorVersion -var var.ProductMinorVersion -var var.ProductVersionString -var var.MSIProductVersion -var var.ReproDir -dr INSTALLDIR -platform $PLATFORM
        # & "$WIX\bin\candle.exe" -arch $PLATFORM "$OUTPUT_BASE_FILENAME-Main.wxs" "Files-$OUTPUT_BASE_FILENAME.wxs" "Src-$OUTPUT_BASE_FILENAME.wxs" -ext WixUIExtension -ext WixUtilExtension -dProductSku="$PRODUCT_SKU" -dProductMajorVersion="$PRODUCT_MAJOR_VERSION" -dProductMinorVersion="$PRODUCT_MINOR_VERSION" -dProductVersionString="$PRODUCT_SHORT_VERSION" -dMSIProductVersion="$MSI_PRODUCT_VERSION" -dProductId="$PRODUCT_ID" -dReproDir="$REPRO_DIR" -dSetupResourcesDir="$SETUP_RESOURCES_DIR" -dCulture="$CULTURE"
        # & "$WIX\bin\light.exe" $MSI_VALIDATION_OPTION "Main-$OUTPUT_BASE_FILENAME.wixobj" "Files-$OUTPUT_BASE_FILENAME.wixobj" "Src-$OUTPUT_BASE_FILENAME.wixobj" -cc $CACHE_FOLDER -ext WixUIExtension -ext WixUtilExtension -spdb -out "ReleaseDir\$OUTPUT_BASE_FILENAME.msi" -loc "Lang\$OUTPUT_BASE_FILENAME-$PRODUCT_SKU.Base.$CULTURE.wxl" -loc "Lang\$OUTPUT_BASE_FILENAME-$PRODUCT_SKU.$PACKAGE_TYPE.$CULTURE.wxl" -cultures:$CULTURE

        # Clean .cab cache for each run .. Cache is only used inside BuildSetupTranslationTransform.cmd to speed up MST generation
        if (Test-Path -Path "!CACHE_FOLDER!") {
            Remove-Item -Path "!CACHE_FOLDER!" -Recurse -Force
        }
        New-Item -ItemType Directory -Path "!CACHE_FOLDER!" | Out-Null
        if (-not (Test-Path -Path "!CACHE_FOLDER!")) {
            Write-Debug "Unable to create cache folder : !CACHE_FOLDER!"
            goto FAILED
        }

        # Build without extra Source Code feature

        # Set default variables
        $ICEDTEAWEB_DIR = ".\SourceDir\icedtea-web-image"
        $BUNDLE_ICEDTEAWEB = $false

        if ($PLATFORM -eq "x64" -and $PRODUCT_MAJOR_VERSION -eq 8 -and (Test-Path $ICEDTEAWEB_DIR)) {
            Write-Debug "IcedTeaWeb Directory Exists!"
            $BUNDLE_ICEDTEAWEB = $true
            $ITW_WXS = "IcedTeaWeb-$OUTPUT_BASE_FILENAME.wxs"
            $ITW_WIXOBJ = "$WORKDIR$IcedTeaWeb-$OUTPUT_BASE_FILENAME.wixobj"

            Write-Debug "HEAT"
            & "$WIX\bin\heat.exe" dir "$ICEDTEAWEB_DIR" -out $ITW_WXS -t "$SETUP_RESOURCES_DIR\heat.icedteaweb.xslt" -gg -sfrag -scom -sreg -srd -ke -cg "IcedTeaWebFiles" -var var.IcedTeaWebDir -dr INSTALLDIR -platform $PLATFORM

            if ($LASTEXITCODE -ne 0) {
                Write-Debug "Failed to generate Windows Installer XML Source files for IcedTea-Web (.wxs)"
                goto FAILED
            }
        }
        else {
            Write-Debug "IcedTeaWeb Directory Does Not Exist!"
        }
    
        Write-Debug "HEAT"
        & "$WIX\bin\heat.exe" dir "$REPRO_DIR" -out "$WORKDIR$OUTPUT_BASE_FILENAME-Files.wxs" -gg -sfrag -scom -sreg -srd -ke -cg "AppFiles" -var var.ProductMajorVersion -var var.ProductMinorVersion -var var.ProductVersionString -var var.MSIProductVersion -var var.ReproDir -dr INSTALLDIR -platform $PLATFORM
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to generate Windows Installer XML Source files (.wxs)"
            goto FAILED
        }

        Write-Debug "CANDLE"
        & "$WIX\bin\candle.exe" -arch $PLATFORM -out "$WORKDIR" "$WORKDIR$OUTPUT_BASE_FILENAME-Main.wxs" "$WORKDIR$OUTPUT_BASE_FILENAME-Files.wxs" $ITW_WXS -ext WixUIExtension -ext WixUtilExtension -dIcedTeaWebDir="$ICEDTEAWEB_DIR" -dOutputBaseFilename="$OUTPUT_BASE_FILENAME" -dProductSku="$PRODUCT_SKU" -dProductMajorVersion="$PRODUCT_MAJOR_VERSION" -dProductMinorVersion="$PRODUCT_MINOR_VERSION" -dProductVersionString="$PRODUCT_SHORT_VERSION" -dMSIProductVersion="$MSI_PRODUCT_VERSION" -dProductId="$PRODUCT_ID" -dProductUpgradeCode="$PRODUCT_UPGRADE_CODE" -dReproDir="$REPRO_DIR" -dSetupResourcesDir="$SETUP_RESOURCES_DIR" -dCulture="$CULTURE" -dJVM="$PACKAGE_TYPE"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to preprocess and compile WiX source files into object files (.wixobj)"
            Get-ChildItem -Path $WORKDIR -Recurse | Sort-Object -Property Name
            goto FAILED
        }

        Write-Debug "LIGHT"
        & "$WIX\bin\light.exe" "$WORKDIR$OUTPUT_BASE_FILENAME-Main.wixobj" "$WORKDIR$OUTPUT_BASE_FILENAME-Files.wixobj" $ITW_WIXOBJ $MSI_VALIDATION_OPTION -cc $CACHE_FOLDER -ext WixUIExtension -ext WixUtilExtension -spdb -out "ReleaseDir\$OUTPUT_BASE_FILENAME.msi" -loc "$WORKDIR$OUTPUT_BASE_FILENAME-$PRODUCT_SKU.Base.$CULTURE.wxl" -loc "$WORKDIR$OUTPUT_BASE_FILENAME-$PRODUCT_SKU.$PACKAGE_TYPE.$CULTURE.wxl" -cultures:$CULTURE
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to link and bind one or more .wixobj files and create a Windows Installer database (.msi or .msm)"
            Get-ChildItem -Path $WORKDIR -Recurse | Sort-Object -Property Name
            goto FAILED
        }

        # Clean up variables
        $ICEDTEAWEB_DIR = ""
        $BUNDLE_ICEDTEAWEB = ""

        # Generate setup translations
        Get-Content "Lang\LanguageList.config" | ForEach-Object {
            $language = $_ -split " "
            $languageCode = $language[0]
            $languageName = $language[1]
            & "BuildSetupTranslationTransform.cmd" $languageCode $languageName
            if ($LASTEXITCODE -ne 0) {
                Write-Debug "Failed to build translation $languageCode $languageName"
                goto FAILED
            }
        }

        # Add all supported languages to MSI Package attribute
        $wiLangIdScript = "$env:ProgramFiles(x86)\Windows Kits\$env:WIN_SDK_MAJOR_VERSION\bin\$env:WIN_SDK_FULL_VERSION\x64\WiLangId.vbs"
        $msiPath = "ReleaseDir\$OUTPUT_BASE_FILENAME.msi"
        $arguments = "//Nologo $msiPath Package $LANGIDS"
        Start-Process -FilePath "CSCRIPT" -ArgumentList $wiLangIdScript, $arguments -NoNewWindow -Wait
        if ($LASTEXITCODE -ne 0) {
            Write-Debug "Failed to pack all languages into MSI : $LANGIDS"
            goto FAILED
        }

        # For temporarily disable the smoke test - use OPTION SKIP_MSI_VALIDATION=true
        # To validate MSI only once at the end
        if ($env:SKIP_MSI_VALIDATION -ne "true") {
            Write-Debug "SMOKE"
            & "$WIX\bin\smoke.exe" "ReleaseDir\$OUTPUT_BASE_FILENAME.msi"
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Failed to validate MSI"
                goto FAILED
            }
        }
        else {
            Write-Debug "MSI validation was skipped by option SKIP_MSI_VALIDATION=true"
        }

        # SIGN the MSIs with digital signature.
        # Dual-Signing with SHA-1/SHA-256 requires Win 8.1 SDK or later.
        if ($env:SIGNING_CERTIFICATE) {
            $timestampErrors = 0
            for ($i = 1; $i -le 15; $i++) {
                Get-Content "serverTimestamp.config" | ForEach-Object {
                    Write-Debug "try $timestampErrors / sha256 / timestamp server : $_"
                    # Always hide password here
                    $signtoolArgs = @(
                        "sign",
                        "-f",
                        $env:SIGNING_CERTIFICATE,
                        "-p",
                        $env:SIGN_PASSWORD,
                        "-fd",
                        "sha256",
                        "-d",
                        "Adoptium",
                        "-t",
                        $_,
                        "ReleaseDir\$OUTPUT_BASE_FILENAME.msi"
                    )
                    & "$env:ProgramFiles(x86)\Windows Kits\$env:WIN_SDK_MAJOR_VERSION\bin\$env:WIN_SDK_FULL_VERSION\x64\signtool.exe" @signtoolArgs

                    # check the return value of the timestamping operation and retry a max of ten times...
                    if ($LASTEXITCODE -eq 0) {
                        goto succeeded
                    }

                    Write-Debug "Signing failed. Probably cannot find the timestamp server at $_"
                    $timestampErrors++
                }

                # always wait for more seconds after each retry
                Start-Sleep -Seconds $i
            }

            # return an error code...
            Write-Debug "sign.bat exit code is 1. There were $timestampErrors timestamping errors."
            exit 1
        }
        else {
            Write-Debug "Ignoring signing step: no certificate configured"
        }

        :succeeded
        # return a successful code...
        Write-Debug "sign.bat exit code is 0. There were $timestampErrors timestamping errors."

        # Remove files we do not need any longer.
        Remove-Item -Path "$WORKDIR\$OUTPUT_BASE_FILENAME-Files.wxs" -Force
        Remove-Item -Path "$WORKDIR\$OUTPUT_BASE_FILENAME-Files.wixobj" -Force
        Remove-Item -Path "$WORKDIR\$OUTPUT_BASE_FILENAME-Main.wxs" -Force
        Remove-Item -Path "$WORKDIR\$OUTPUT_BASE_FILENAME-Main.wixobj" -Force
        Remove-Item -Path "$WORKDIR\$OUTPUT_BASE_FILENAME-$PRODUCT_SKU.$JVM.*.wxl" -Force
        Remove-Item -Path "$WORKDIR\$OUTPUT_BASE_FILENAME-$PRODUCT_SKU.Base.*.wxl" -Force
        Remove-Item -Path "$WORKDIR\$OUTPUT_BASE_FILENAME-$PRODUCT_SKU.Variables.wxi" -Force

        if ($ITW_WXS) {
            Remove-Item -Path $ITW_WXS -Force
            Remove-Item -Path $ITW_WIXOBJ -Force
        }

        Remove-Item -Path $CACHE_FOLDER -Recurse -Force
    }

    $ITW_WXS = $null
    $ITW_WIXOBJ = $null
}

# Cleanup variables
$CULTURE = $null
$LANGIDS = $null
$OUTPUT_BASE_FILENAME = $null
$PACKAGE_TYPE = $null
$PRODUCT_CATEGORY = $null
$PRODUCT_SKU = $null
$PRODUCT_MAJOR_VERSION = $null
$PRODUCT_MINOR_VERSION = $null
$PRODUCT_MAINTENANCE_VERSION = $null
$PRODUCT_PATCH_VERSION = $null
$PRODUCT_BUILD_NUMBER = $null
$MSI_PRODUCT_VERSION = $null
$PRODUCT_ID = $null
$PRODUCT_VERSION = $null
$PLATFORM = $null
$FOLDER_PLATFORM = $null
$REPRO_DIR = $null
$SETUP_RESOURCES_DIR = $null
$WIN_SDK_FULL_VERSION = $null
$WIN_SDK_MAJOR_VERSION = $null

exit 0

:FAILED
exit 2
