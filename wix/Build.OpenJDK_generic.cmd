@ECHO OFF

REM Set version numbers and build option here if being run manually:
REM PRODUCT_MAJOR_VERSION=11
REM PRODUCT_MINOR_VERSION=0
REM PRODUCT_MAINTENANCE_VERSION=0
REM PRODUCT_PATCH_VERSION=28
REM ARCH=x64|x86-32 or both "x64 x86-32"
REM JVM=hotspot|openj9 or both JVM=hotspot openj9
REM PRODUCT_CATEGORY=jre|jdk (only one at a time)
REM SKIP_MSI_VALIDATION=true (Add -sval option to light.exe to skip MSI/MSM validation and skip smoke.exe )

SETLOCAL ENABLEEXTENSIONS
SET ERR=0
IF NOT DEFINED PRODUCT_MAJOR_VERSION SET ERR=1
IF NOT DEFINED PRODUCT_MINOR_VERSION SET ERR=2
IF NOT DEFINED PRODUCT_MAINTENANCE_VERSION SET ERR=3
IF NOT DEFINED PRODUCT_PATCH_VERSION SET ERR=4
IF NOT DEFINED ARCH SET ERR=5
IF NOT DEFINED JVM SET ERR=6
IF NOT DEFINED PRODUCT_CATEGORY SET ERR=7
IF NOT %ERR% == 0 ( echo Missing args/variable ERR:%ERR% && GOTO FAILED )

IF NOT "%ARCH%" == "x64" (
	IF NOT "%ARCH%" == "x86-32" (
		IF NOT "%ARCH%" == "x86-32 x64" (
			IF NOT "%ARCH%" == "x64 x86-32" (
				ECHO ARCH %ARCH% not supported : valid values : x86-32, x64, x86-32 x64, x64 x86-32
				GOTO FAILED
			)
		)
	)
)

IF NOT "%JVM%" == "hotspot" (
	IF NOT "%JVM%" == "openj9" (
		IF NOT "%JVM%" == "openj9 hotspot" (
			IF NOT "%JVM%" == "hotspot openj9" (
				ECHO JVM "%JVM%" not supported : valid values : hotspot, openj9, hotspot openj9, openj9 hotspot
				GOTO FAILED
			)
		)
	)
)

IF NOT "%PRODUCT_CATEGORY%" == "jre" (
	IF NOT "%PRODUCT_CATEGORY%" == "jdk" (
		ECHO PRODUCT_CATEGORY "%PRODUCT_CATEGORY%" not supported : valid values : jre, jdk
		GOTO FAILED
	)
)


IF "%SKIP_MSI_VALIDATION%" == "true" (
	SET "MSI_VALIDATION_OPTION= -sval " 
)

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


REM Generate platform specific builds (x86-32,x64)
SETLOCAL ENABLEDELAYEDEXPANSION
FOR %%G IN (%ARCH%) DO (
  REM We could build both "hotspot,openj9" in one script, but it is not clear if release cycle is the same.
  FOR %%H IN (%JVM%) DO (
    ECHO Generate OpenJDK setup "%%H" for "%%G" platform "!PRODUCT_CATEGORY!"
    ECHO ****************************************************
    SET CULTURE=en-us
    SET LANGIDS=1033
    SET PLATFORM=%%G
    SET FOLDER_PLATFORM=%%G
    IF %%G == x86-32 (
        SET PLATFORM=x86
    )

    SET PACKAGE_TYPE=%%H
    SET SETUP_RESOURCES_DIR=.\Resources
    IF !PRODUCT_MAJOR_VERSION! == 8 (
        SET REPRO_DIR=.\SourceDir\!PRODUCT_SKU!!PRODUCT_MAJOR_VERSION!\!PACKAGE_TYPE!\!FOLDER_PLATFORM!\jdk%PRODUCT_MAJOR_VERSION%u%PRODUCT_MAINTENANCE_VERSION%-b%PRODUCT_PATCH_VERSION%
        IF !PRODUCT_CATEGORY! == jre (
            SET REPRO_DIR=!REPRO_DIR!-!PRODUCT_CATEGORY!
        )
    ) ELSE (
        REM NEW REPRO_DIR format for JDK version 11 12 etc ..
        SET REPRO_DIR=.\SourceDir\!PRODUCT_SKU!!PRODUCT_MAJOR_VERSION!\!PACKAGE_TYPE!\!FOLDER_PLATFORM!\jdk-%PRODUCT_MAJOR_VERSION%+%PRODUCT_PATCH_VERSION%

        IF NOT EXIST "!REPRO_DIR!" (
            ECHO First !REPRO_DIR! not exists
            SET REPRO_DIR=.\SourceDir\!PRODUCT_SKU!!PRODUCT_MAJOR_VERSION!\!PACKAGE_TYPE!\!FOLDER_PLATFORM!\jdk-%PRODUCT_MAJOR_VERSION%.%PRODUCT_MINOR_VERSION%.%PRODUCT_MAINTENANCE_VERSION%+%PRODUCT_PATCH_VERSION%
            IF !PRODUCT_CATEGORY! == jre (
                SET REPRO_DIR=!REPRO_DIR!-!PRODUCT_CATEGORY!
            )
            IF NOT EXIST "!REPRO_DIR!" (
                ECHO Second !REPRO_DIR! not exists
                ECHO SOURCE Dir not found / failed
                GOTO FAILED
            )
        )
    )

    SET OUTPUT_BASE_FILENAME=!PRODUCT_SKU!!PRODUCT_MAJOR_VERSION!-!PRODUCT_CATEGORY!_!FOLDER_PLATFORM!_windows_!PACKAGE_TYPE!-!PRODUCT_VERSION!
    SET CACHE_BASE_FOLDER=Cache
    REM Each build his own cache for concurrent build
    SET CACHE_FOLDER=!CACHE_BASE_FOLDER!\!OUTPUT_BASE_FILENAME!

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
	ECHO copy "Main.!PACKAGE_TYPE!.wxs"
    COPY /Y "Main.!PACKAGE_TYPE!.wxs" "Main-!OUTPUT_BASE_FILENAME!.wxs"

    REM Build with extra Source Code feature (needs work)
    REM "!WIX!bin\heat.exe" file "!REPRO_DIR!\lib\src.zip" -out Src-!OUTPUT_BASE_FILENAME!.wxs -gg -srd -cg "SrcFiles" -var var.ReproDir -dr INSTALLDIR -platform !PLATFORM!
    REM "!WIX!bin\heat.exe" dir "!REPRO_DIR!" -out Files-!OUTPUT_BASE_FILENAME!.wxs -t "!SETUP_RESOURCES_DIR!\heat.tools.xslt" -gg -sfrag -scom -sreg -srd -ke -cg "AppFiles" -var var.ProductMajorVersion -var var.ProductMinorVersion -var var.ProductMaintenanceVersion -var var.ProductPatchVersion -var var.ReproDir -dr INSTALLDIR -platform !PLATFORM!
    REM "!WIX!bin\candle.exe" -arch !PLATFORM! Main-!OUTPUT_BASE_FILENAME!.wxs Files-!OUTPUT_BASE_FILENAME!.wxs Src-!OUTPUT_BASE_FILENAME!.wxs -ext WixUIExtension -ext WixUtilExtension -dProductSku="!PRODUCT_SKU!" -dProductMajorVersion="!PRODUCT_MAJOR_VERSION!" -dProductMinorVersion="!PRODUCT_MINOR_VERSION!" -dProductMaintenanceVersion="!PRODUCT_MAINTENANCE_VERSION!" -dProductPatchVersion="!PRODUCT_PATCH_VERSION!" -dProductId="!PRODUCT_ID!" -dReproDir="!REPRO_DIR!" -dSetupResourcesDir="!SETUP_RESOURCES_DIR!" -dCulture="!CULTURE!"
    REM "!WIX!bin\light.exe" !MSI_VALIDATION_OPTION! Main-!OUTPUT_BASE_FILENAME!.wixobj Files-!OUTPUT_BASE_FILENAME!.wixobj Src-!OUTPUT_BASE_FILENAME!.wixobj -cc !CACHE_FOLDER! -ext WixUIExtension -ext WixUtilExtension -spdb -out "ReleaseDir\!OUTPUT_BASE_FILENAME!.msi" -loc "Lang\!PRODUCT_SKU!.Base.!CULTURE!.wxl" -loc "Lang\!PRODUCT_SKU!.!PACKAGE_TYPE!.!CULTURE!.wxl" -cultures:!CULTURE!

    REM Clean .cab cache for each run .. Cache is only used inside BuildSetupTranslationTransform.cmd to speed up MST generation
    IF EXIST !CACHE_FOLDER! rmdir /S /Q !CACHE_FOLDER!
    MKDIR !CACHE_FOLDER!
	IF ERRORLEVEL 1 (
		echo "Unable to create cache folder : !CACHE_FOLDER!"
	    GOTO FAILED
	)

    REM Build without extra Source Code feature
    
	ECHO HEAT
	@ECHO ON
    "!WIX!bin\heat.exe" dir "!REPRO_DIR!" -out Files-!OUTPUT_BASE_FILENAME!.wxs -gg -sfrag -scom -sreg -srd -ke -cg "AppFiles" -var var.ProductMajorVersion -var var.ProductMinorVersion -var var.ProductMaintenanceVersion -var var.ProductPatchVersion -var var.ReproDir -dr INSTALLDIR -platform !PLATFORM!
	IF ERRORLEVEL 1 (
		ECHO "Failed to generating Windows Installer XML Source files (.wxs)"
	    GOTO FAILED
	)
	@ECHO OFF
	
	ECHO CANDLE
	@ECHO ON
    "!WIX!bin\candle.exe" -arch !PLATFORM! Main-!OUTPUT_BASE_FILENAME!.wxs Files-!OUTPUT_BASE_FILENAME!.wxs -ext WixUIExtension -ext WixUtilExtension -dProductSku="!PRODUCT_SKU!" -dProductMajorVersion="!PRODUCT_MAJOR_VERSION!" -dProductMinorVersion="!PRODUCT_MINOR_VERSION!" -dProductMaintenanceVersion="!PRODUCT_MAINTENANCE_VERSION!" -dProductPatchVersion="!PRODUCT_PATCH_VERSION!" -dProductId="!PRODUCT_ID!" -dProductUpgradeCode="!PRODUCT_UPGRADE_CODE!" -dReproDir="!REPRO_DIR!" -dSetupResourcesDir="!SETUP_RESOURCES_DIR!" -dCulture="!CULTURE!"
	IF ERRORLEVEL 1 (
	    ECHO "Failed to preprocesses and compiles WiX source files into object files (.wixobj)"
	    GOTO FAILED
	)
	@ECHO OFF
	
	ECHO "LIGHT"
	@ECHO ON
    "!WIX!bin\light.exe" Main-!OUTPUT_BASE_FILENAME!.wixobj Files-!OUTPUT_BASE_FILENAME!.wixobj !MSI_VALIDATION_OPTION! -cc !CACHE_FOLDER! -ext WixUIExtension -ext WixUtilExtension -spdb -out "ReleaseDir\!OUTPUT_BASE_FILENAME!.msi" -loc "Lang\!PRODUCT_SKU!.Base.!CULTURE!.wxl" -loc "Lang\!PRODUCT_SKU!.!PACKAGE_TYPE!.!CULTURE!.wxl" -cultures:!CULTURE!
	IF ERRORLEVEL 1 (
	    ECHO "Failed to links and binds one or more .wixobj files and creates a Windows Installer database (.msi or .msm)"
	    GOTO FAILED
	)
	@ECHO OFF

    REM Generate setup translations
    FOR /F "tokens=1-2" %%G IN (Lang\LanguageList.config) do (
        CALL BuildSetupTranslationTransform.cmd %%G %%H
        IF ERRORLEVEL 1 (
            ECHO failed to build translation %%G %%H
            GOTO FAILED
        )
    )

    REM Add all supported languages to MSI Package attribute
    CSCRIPT "%ProgramFiles(x86)%\Windows Kits\%WIN_SDK_MAJOR_VERSION%\bin\%WIN_SDK_FULL_VERSION%\x64\WiLangId.vbs" //Nologo ReleaseDir\!OUTPUT_BASE_FILENAME!.msi Package !LANGIDS!
    IF ERRORLEVEL 1 (
		ECHO Failed to pack all languages into MSI : !LANGIDS!
	    GOTO FAILED
	)

	REM For temporarily disable the smoke test - use OPTION SKIP_MSI_VALIDATION=true 
	REM To validate MSI only once at the end
	IF NOT "%SKIP_MSI_VALIDATION%" == "true" (
		ECHO "SMOKE"
		@ECHO ON
		"!WIX!bin\smoke.exe" "ReleaseDir\!OUTPUT_BASE_FILENAME!.msi"
		IF ERRORLEVEL 1 (
			ECHO Failed to validate MSI
		    GOTO FAILED
		)
		@ECHO OFF
	) ELSE (
        ECHO "MSI validation was skipped by option SKIP_MSI_VALIDATION=true"
    )

    REM SIGN the MSIs with digital signature.
    REM Dual-Signing with SHA-1/SHA-256 requires Win 8.1 SDK or later.
    IF DEFINED SIGNING_CERTIFICATE (
        "%ProgramFiles(x86)%\Windows Kits\%WIN_SDK_MAJOR_VERSION%\bin\%WIN_SDK_FULL_VERSION%\x64\signtool.exe" sign -f "%SIGNING_CERTIFICATE%" -p "%SIGN_PASSWORD%" -fd sha1 -d "AdoptOpenJDK" -t http://timestamp.verisign.com/scripts/timstamp.dll "ReleaseDir\!OUTPUT_BASE_FILENAME!.msi"
        IF ERRORLEVEL 1 (
            ECHO Failed to sign with SHA1
            GOTO FAILED
        )
        "%ProgramFiles(x86)%\Windows Kits\%WIN_SDK_MAJOR_VERSION%\bin\%WIN_SDK_FULL_VERSION%\x64\signtool.exe" sign -f "%SIGNING_CERTIFICATE%" -p "%SIGN_PASSWORD%" -fd sha256 -d "AdoptOpenJDK" -t http://timestamp.verisign.com/scripts/timstamp.dll "ReleaseDir\!OUTPUT_BASE_FILENAME!.msi"
        IF ERRORLEVEL 1 (
            ECHO Failed to sign with SHA256
            GOTO FAILED
        )
    ) ELSE (
        ECHO "Ignoring signing step : not certificate configured"
    )
    

    REM Remove files we do not need any longer.
    DEL "Files-!OUTPUT_BASE_FILENAME!.wxs"
    DEL "Files-!OUTPUT_BASE_FILENAME!.wixobj"
    DEL "Main-!OUTPUT_BASE_FILENAME!.wxs"
    DEL "Main-!OUTPUT_BASE_FILENAME!.wixobj"
    RMDIR /S /Q !CACHE_FOLDER!
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
SET FOLDER_PLATFORM=
SET REPRO_DIR=
SET SETUP_RESOURCES_DIR=
SET WIN_SDK_FULL_VERSION=
SET WIN_SDK_MAJOR_VERSION=

EXIT /b 0

:FAILED
EXIT /b 2
