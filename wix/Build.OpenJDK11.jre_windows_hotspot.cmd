@ECHO OFF

REM Set version numbers here if being run manually:
REM PRODUCT_MAJOR_VERSION=11
REM PRODUCT_MINOR_VERSION=0
REM PRODUCT_MAINTENANCE_VERSION=0
REM PRODUCT_PATCH_VERSION=28
REM ARCH=x64

REM Configure available SDK version:
REM See folder e.g. "C:\Program Files (x86)\Windows Kits\[10]\bin\[10.0.16299.0]\x64"
SET WIN_SDK_MAJOR_VERSION=10
SET WIN_SDK_FULL_VERSION=10.0.17763.0

REM
REM Nothing below this line need to be changed normally.
REM

REM Cultures: https://msdn.microsoft.com/de-de/library/ee825488(v=cs.20).aspx
SET PRODUCT_SKU=OpenJDK
SET PRODUCT_VERSION=%PRODUCT_MAJOR_VERSION%.%PRODUCT_MINOR_VERSION%.%PRODUCT_MAINTENANCE_VERSION%.%PRODUCT_PATCH_VERSION%


REM Generate platform specific builds (x86,x64)
SETLOCAL ENABLEDELAYEDEXPANSION
FOR %%G IN (%ARCH%) DO (
  REM We could build both "hotspot,openj9" in one script, but it is not clear if release cycle is the same.
  FOR %%H IN (hotspot) DO (
    ECHO Generate OpenJDK setup "%%H" for "%%G" platform
    ECHO ****************************************************
    SET CULTURE=en-us
    SET LANGIDS=1033
    SET PLATFORM=%%G
    SET PACKAGE_TYPE=%%H
    REM Allowed values: jdk/jre
    SET PRODUCT_CATEGORY=jre
    SET SETUP_RESOURCES_DIR=.\Resources
    SET REPRO_DIR=.\SourceDir\!PRODUCT_SKU!!PRODUCT_MAJOR_VERSION!\!PACKAGE_TYPE!\!PLATFORM!\jdk-%PRODUCT_MAJOR_VERSION%+%PRODUCT_PATCH_VERSION%-!PRODUCT_CATEGORY!
    REM OpenJDK11-jre_x64_windows_hotspot-[version].msi
    SET OUTPUT_BASE_FILENAME=!PRODUCT_SKU!!PRODUCT_MAJOR_VERSION!-!PRODUCT_CATEGORY!_!PLATFORM!_windows_hotspot-!PRODUCT_VERSION!

    REM Generate one ID per release. But do NOT use * as we need to keep the same number for all languages, but not platforms.
    FOR /F %%I IN ('POWERSHELL -COMMAND "$([guid]::NewGuid().ToString('b').ToUpper())"') DO (
      SET PRODUCT_ID=%%I
      ECHO PRODUCT_ID: !PRODUCT_ID!
    )
    FOR /F %%F IN ('POWERSHELL -COMMAND "$([guid]::NewGuid().ToString('b').ToUpper())"') DO (
      SET PRODUCT_UPGRADE_CODE=%%F
      ECHO PRODUCT_UPGRADE_CODE: !PRODUCT_UPGRADE_CODE!
    )

    REM Prevent concurrency issues if multiple builds are running in parallel.
    COPY /Y "Main.!PACKAGE_TYPE!.wxs" "Main-!OUTPUT_BASE_FILENAME!.wxs"

    REM Build with extra Source Code feature (needs work)
    REM "!WIX!bin\heat.exe" file "!REPRO_DIR!\lib\src.zip" -out Src-!OUTPUT_BASE_FILENAME!.wxs -gg -srd -cg "SrcFiles" -var var.ReproDir -dr INSTALLDIR -platform !PLATFORM!
    REM "!WIX!bin\heat.exe" dir "!REPRO_DIR!" -out Files-!OUTPUT_BASE_FILENAME!.wxs -t "!SETUP_RESOURCES_DIR!\heat.tools.xslt" -gg -sfrag -scom -sreg -srd -ke -cg "AppFiles" -var var.ProductMajorVersion -var var.ProductMinorVersion -var var.ProductMaintenanceVersion -var var.ProductPatchVersion -var var.ReproDir -dr INSTALLDIR -platform !PLATFORM!
    REM "!WIX!bin\candle.exe" -arch !PLATFORM! Main.!PACKAGE_TYPE!.wxs Files-!OUTPUT_BASE_FILENAME!.wxs Src-!OUTPUT_BASE_FILENAME!.wxs -ext WixUIExtension -ext WixUtilExtension -dProductSku="!PRODUCT_SKU!" -dProductMajorVersion="!PRODUCT_MAJOR_VERSION!" -dProductMinorVersion="!PRODUCT_MINOR_VERSION!" -dProductMaintenanceVersion="!PRODUCT_MAINTENANCE_VERSION!" -dProductPatchVersion="!PRODUCT_PATCH_VERSION!" -dProductId="!PRODUCT_ID!" -dReproDir="!REPRO_DIR!" -dSetupResourcesDir="!SETUP_RESOURCES_DIR!" -dCulture="!CULTURE!"
    REM "!WIX!bin\light.exe" Main.!PACKAGE_TYPE!.wixobj Files-!OUTPUT_BASE_FILENAME!.wixobj Src-!OUTPUT_BASE_FILENAME!.wixobj -ext WixUIExtension -ext WixUtilExtension -spdb -out "ReleaseDir\!OUTPUT_BASE_FILENAME!.msi" -loc "Lang\!PRODUCT_SKU!.Base.!CULTURE!.wxl" -loc "Lang\!PRODUCT_SKU!.!PACKAGE_TYPE!.!CULTURE!.wxl" -cultures:!CULTURE!

    REM Build without extra Source Code feature
    "!WIX!bin\heat.exe" dir "!REPRO_DIR!" -out Files-!OUTPUT_BASE_FILENAME!.wxs -gg -sfrag -scom -sreg -srd -ke -cg "AppFiles" -var var.ProductMajorVersion -var var.ProductMinorVersion -var var.ProductMaintenanceVersion -var var.ProductPatchVersion -var var.ReproDir -dr INSTALLDIR -platform !PLATFORM!
    "!WIX!bin\candle.exe" -arch !PLATFORM! Main-!OUTPUT_BASE_FILENAME!.wxs Files-!OUTPUT_BASE_FILENAME!.wxs -ext WixUIExtension -ext WixUtilExtension -dProductSku="!PRODUCT_SKU!" -dProductMajorVersion="!PRODUCT_MAJOR_VERSION!" -dProductMinorVersion="!PRODUCT_MINOR_VERSION!" -dProductMaintenanceVersion="!PRODUCT_MAINTENANCE_VERSION!" -dProductPatchVersion="!PRODUCT_PATCH_VERSION!" -dProductId="!PRODUCT_ID!" -dProductUpgradeCode="!PRODUCT_UPGRADE_CODE!" -dReproDir="!REPRO_DIR!" -dSetupResourcesDir="!SETUP_RESOURCES_DIR!" -dCulture="!CULTURE!"
    "!WIX!bin\light.exe" Main-!OUTPUT_BASE_FILENAME!.wixobj Files-!OUTPUT_BASE_FILENAME!.wixobj -ext WixUIExtension -ext WixUtilExtension -spdb -out "ReleaseDir\!OUTPUT_BASE_FILENAME!.msi" -loc "Lang\!PRODUCT_SKU!.Base.!CULTURE!.wxl" -loc "Lang\!PRODUCT_SKU!.!PACKAGE_TYPE!.!CULTURE!.wxl" -cultures:!CULTURE!

    REM Generate setup translations
    CALL BuildSetupTranslationTransform.cmd de-de 1031
    CALL BuildSetupTranslationTransform.cmd es-es 3082
    CALL BuildSetupTranslationTransform.cmd fr-fr 1036
    REM CALL BuildSetupTranslationTransform.cmd it-it 1040
    CALL BuildSetupTranslationTransform.cmd ja-jp 1041
    REM CALL BuildSetupTranslationTransform.cmd ko-kr 1042
    REM CALL BuildSetupTranslationTransform.cmd ru-ru 1049
    CALL BuildSetupTranslationTransform.cmd zh-cn 2052
    CALL BuildSetupTranslationTransform.cmd zh-tw 1028

    REM Add all supported languages to MSI Package attribute
    CSCRIPT "%ProgramFiles(x86)%\Windows Kits\%WIN_SDK_MAJOR_VERSION%\bin\%WIN_SDK_FULL_VERSION%\x64\WiLangId.vbs" ReleaseDir\!OUTPUT_BASE_FILENAME!.msi Package !LANGIDS!

    REM SIGN the MSIs with digital signature.
    REM Dual-Signing with SHA-1/SHA-256 requires Win 8.1 SDK or later.
    "%ProgramFiles(x86)%\Windows Kits\8.1\bin\x64\signtool.exe" sign -f "%SIGNING_CERTIFICATE%" -p "%SIGN_PASSWORD%" -fd sha1 -t http://timestamp.verisign.com/scripts/timstamp.dll "ReleaseDir\!OUTPUT_BASE_FILENAME!.msi"
    "%ProgramFiles(x86)%\Windows Kits\8.1\bin\x64\signtool.exe" sign -f "%SIGNING_CERTIFICATE%" -p "%SIGN_PASSWORD%" -as -fd sha256 -t http://timestamp.verisign.com/scripts/timstamp.dll "ReleaseDir\!OUTPUT_BASE_FILENAME!.msi"

    REM Remove files we do not need any longer.
    DEL "Files-!OUTPUT_BASE_FILENAME!.wxs"
    DEL "Files-!OUTPUT_BASE_FILENAME!.wixobj"
    DEL "Main-!OUTPUT_BASE_FILENAME!.wxs"
    DEL "Main-!OUTPUT_BASE_FILENAME!.wixobj"
  )
)
ENDLOCAL

REM Cleanup variables
SET CULTURE=
SET LANGIDS=
SET OUTPUT_BASE_FILENAME=
SET PACKAGE_TYPE=
SET PRODUCT_CATEGORY=
SET PRODUCT_SKU=
SET PRODUCT_MAJOR_VERSION=
SET PRODUCT_MINOR_VERSION=
SET PRODUCT_MAINTENANCE_VERSION=
SET PRODUCT_PATCH_VERSION=
SET PRODUCT_ID=
SET PRODUCT_VERSION=
SET PLATFORM=
SET REPRO_DIR=
SET SETUP_RESOURCES_DIR=
SET WIN_SDK_FULL_VERSION=
SET WIN_SDK_MAJOR_VERSION=
