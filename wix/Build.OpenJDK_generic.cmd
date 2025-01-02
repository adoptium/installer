IF NOT "%DEBUG%" == "true" @ECHO OFF

REM Set version numbers and build option here if being run manually:
REM PRODUCT_MAJOR_VERSION=11
REM PRODUCT_MINOR_VERSION=0
REM PRODUCT_MAINTENANCE_VERSION=0
REM PRODUCT_PATCH_VERSION=0
REM PRODUCT_BUILD_NUMBER=28
REM MSI_PRODUCT_VERSION=11.0.0.28
REM ARCH=x64|x86-32|x86|arm64 or all "x64 x86-32 arm64"
REM JVM=hotspot|openj9|dragonwell|microsoft or both JVM=hotspot openj9
REM PRODUCT_CATEGORY=jre|jdk (only one at a time)
REM SKIP_MSI_VALIDATION=true (Add -sval option to light.exe to skip MSI/MSM validation and skip smoke.exe )
REM UPGRADE_CODE_SEED=thisIsAPrivateSecretSeed ( optional ) for upgradable MSI (If none, new PRODUCT_UPGRADE_CODE is generate for each run)
REM OUTPUT_BASE_FILENAME=customFileName (optional) for setting file names that are not based on the default naming convention
REM WIX_VERSION=5.0.0 (optional) for setting the version of Wix Toolset to use

SETLOCAL ENABLEEXTENSIONS
SET ERR=0
IF NOT DEFINED PRODUCT_MAJOR_VERSION SET ERR=1
IF NOT DEFINED PRODUCT_MINOR_VERSION SET ERR=2
IF NOT DEFINED PRODUCT_MAINTENANCE_VERSION SET ERR=3
IF NOT DEFINED PRODUCT_PATCH_VERSION SET ERR=4
IF NOT DEFINED PRODUCT_BUILD_NUMBER SET ERR=5
IF NOT DEFINED MSI_PRODUCT_VERSION SET ERR=6
IF NOT DEFINED ARCH SET ERR=7
IF NOT DEFINED JVM SET ERR=8
IF NOT DEFINED PRODUCT_CATEGORY SET ERR=9
IF NOT %ERR% == 0 ( ECHO Missing args/variable ERR:%ERR% && GOTO FAILED )

REM default vendor information
IF NOT DEFINED VENDOR SET VENDOR=Eclipse Adoptium
IF NOT DEFINED VENDOR_BRANDING SET VENDOR_BRANDING=Eclipse Temurin
IF NOT DEFINED VENDOR_BRANDING_LOGO SET VENDOR_BRANDING_LOGO=$(var.SetupResourcesDir)\logo.ico
IF NOT DEFINED VENDOR_BRANDING_BANNER SET VENDOR_BRANDING_BANNER=$(var.SetupResourcesDir)\wix-banner.png
IF NOT DEFINED VENDOR_BRANDING_DIALOG SET VENDOR_BRANDING_DIALOG=$(var.SetupResourcesDir)\wix-dialog.png
IF NOT DEFINED PRODUCT_HELP_LINK SET PRODUCT_HELP_LINK=https://github.com/adoptium/adoptium-support/issues/new/choose
IF NOT DEFINED PRODUCT_SUPPORT_LINK SET PRODUCT_SUPPORT_LINK=https://adoptium.net/support
IF NOT DEFINED PRODUCT_UPDATE_INFO_LINK SET PRODUCT_UPDATE_INFO_LINK=https://adoptium.net/temurin/releases
IF NOT DEFINED WIX_HEAT_PATH SET WIX_HEAT_PATH=.\Resources\heat_dir\heat.exe
IF NOT DEFINED WIX_VERSION SET WIX_VERSION=5.0.0

powershell -ExecutionPolicy Bypass -File "%~dp0\helpers\Validate-Input.ps1" ^
    -toValidate '%ARCH%' ^
    -validInputs "x64 x86-32 x86 arm64" ^
    -delimiter " "

IF %ERRORLEVEL% == 1 (
    ECHO ARCH %ARCH% not supported : valid values are any combination of : x64, ^(x86 or x86-32^), arm64
    GOTO FAILED
)

REM Update to handle the change of build variant until implications
REM of setting this to Temurin can be evaluated
IF "%JVM%" == "temurin" SET JVM=hotspot
@REM Microsoft update to handle similar situation
IF "%JVM%" == "microsoft" SET TEMPLATE_NAME=microsoft
IF "%JVM%" == "microsoft" SET JVM=hotspot

powershell -ExecutionPolicy Bypass -File "%~dp0\helpers\Validate-Input.ps1" ^
    -toValidate '%JVM%' ^
    -validInputs "hotspot,openj9,dragonwell,microsoft,openj9 hotspot,hotspot openj9" ^
    -delimiter ","

IF %ERRORLEVEL% == 1 (
    ECHO JVM "%JVM%" not supported : valid values : hotspot, openj9, dragonwell, hotspot openj9, openj9 hotspot
    GOTO FAILED
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
SET WIN_SDK_FULL_VERSION=10.0.22621.0
SET WORKDIR=Workdir\
mkdir %WORKDIR%

@REM Add necessary wix extensions here
wix extension add WixToolset.UI.wixext/%WIX_VERSION%
wix extension add WixToolset.Util.wixext/%WIX_VERSION%

REM
REM Nothing below this line need to be changed normally.
REM

REM Cultures: https://msdn.microsoft.com/de-de/library/ee825488(v=cs.20).aspx
SET PRODUCT_SKU=OpenJDK
SET PRODUCT_FULL_VERSION=%PRODUCT_MAJOR_VERSION%.%PRODUCT_MINOR_VERSION%.%PRODUCT_MAINTENANCE_VERSION%.%PRODUCT_PATCH_VERSION%.%PRODUCT_BUILD_NUMBER%

SETLOCAL ENABLEDELAYEDEXPANSION
SET PRODUCT_SHORT_VERSION=%PRODUCT_MAJOR_VERSION%u%PRODUCT_MAINTENANCE_VERSION%-b%PRODUCT_BUILD_NUMBER%
IF %PRODUCT_CATEGORY% EQU jre SET JRE=-jre
IF %PRODUCT_MAJOR_VERSION% GEQ 10 (
    IF DEFINED PRODUCT_BUILD_NUMBER (
        SET BUILD_NUM=+%PRODUCT_BUILD_NUMBER%
    )
    SET PRODUCT_SHORT_VERSION=%PRODUCT_MAJOR_VERSION%
    IF "%PRODUCT_MINOR_VERSION%" NEQ "0" SET PRODUCT_SHORT_VERSION=%PRODUCT_MAJOR_VERSION%.%PRODUCT_MINOR_VERSION%
    IF "%PRODUCT_MAINTENANCE_VERSION%" NEQ "0" SET PRODUCT_SHORT_VERSION=%PRODUCT_MAJOR_VERSION%.%PRODUCT_MINOR_VERSION%.%PRODUCT_MAINTENANCE_VERSION%
    IF "%PRODUCT_PATCH_VERSION%" NEQ "0" SET PRODUCT_SHORT_VERSION=%PRODUCT_MAJOR_VERSION%.%PRODUCT_MINOR_VERSION%.%PRODUCT_MAINTENANCE_VERSION%.%PRODUCT_PATCH_VERSION%
    SET PRODUCT_SHORT_VERSION=!PRODUCT_SHORT_VERSION!!BUILD_NUM!
)

REM ECHO Basic      =%PRODUCT_MAJOR_VERSION%.%PRODUCT_MINOR_VERSION%.%PRODUCT_MAINTENANCE_VERSION%.%PRODUCT_PATCH_VERSION%.%PRODUCT_BUILD_NUMBER%
ECHO PRODUCT_FULL_VERSION=!PRODUCT_FULL_VERSION!
ECHO PRODUCT_SHORT_VERSION=!PRODUCT_SHORT_VERSION!


REM Generate platform specific builds (x86-32,x64, arm64)
FOR %%A IN (%ARCH%) DO (
  REM We could build both "hotspot,openj9" in one script, but it is not clear if release cycle is the same.
  FOR %%J IN (%JVM%) DO (
    SET PACKAGE_TYPE=%%J
    SET PLATFORM=%%A

    @REM TEMPLATE_NAME is only used to allow vendors to have their own
    @REM custom templates without changing their GUID.
    IF NOT DEFINED TEMPLATE_NAME SET TEMPLATE_NAME=!PACKAGE_TYPE!

    ECHO Generate OpenJDK setup "!TEMPLATE_NAME!" for "!PLATFORM!" platform "!PRODUCT_CATEGORY!"
    ECHO ****************************************************
    SET CULTURE=en-us
    SET LANGIDS=1033
    SET FOLDER_PLATFORM=!PLATFORM!
    IF !PLATFORM! == x86-32 (
        SET PLATFORM=x86
    )

    SET SETUP_RESOURCES_DIR=.\Resources

    FOR %%P IN (
        !PRODUCT_SKU!!PRODUCT_MAJOR_VERSION!\!TEMPLATE_NAME!\!FOLDER_PLATFORM!\jdk-%PRODUCT_MAJOR_VERSION%.%PRODUCT_MINOR_VERSION%.%PRODUCT_MAINTENANCE_VERSION%
        !PRODUCT_SKU!!PRODUCT_MAJOR_VERSION!\!TEMPLATE_NAME!\!FOLDER_PLATFORM!\jdk%PRODUCT_MAJOR_VERSION%u%PRODUCT_MAINTENANCE_VERSION%-b%PRODUCT_BUILD_NUMBER%
        !PRODUCT_SKU!!PRODUCT_MAJOR_VERSION!\!TEMPLATE_NAME!\!FOLDER_PLATFORM!\jdk-%PRODUCT_MAJOR_VERSION%+%PRODUCT_BUILD_NUMBER%
        !PRODUCT_SKU!!PRODUCT_MAJOR_VERSION!\!TEMPLATE_NAME!\!FOLDER_PLATFORM!\jdk-%PRODUCT_MAJOR_VERSION%.%PRODUCT_MINOR_VERSION%.%PRODUCT_MAINTENANCE_VERSION%+%PRODUCT_BUILD_NUMBER%
        !PRODUCT_SKU!!PRODUCT_MAJOR_VERSION!\!TEMPLATE_NAME!\!FOLDER_PLATFORM!\jdk-%PRODUCT_MAJOR_VERSION%.%PRODUCT_MINOR_VERSION%.%PRODUCT_MAINTENANCE_VERSION%.%PRODUCT_PATCH_VERSION%+%PRODUCT_BUILD_NUMBER%
        !PRODUCT_SKU!-Latest\!TEMPLATE_NAME!\!FOLDER_PLATFORM!\jdk-!PRODUCT_SHORT_VERSION!
    ) DO (
        SET REPRO_DIR=.\SourceDir\%%P
        IF "!PRODUCT_CATEGORY!" == "jre" (
            SET REPRO_DIR=!REPRO_DIR!-!PRODUCT_CATEGORY!
        )
        ECHO looking for !REPRO_DIR!
        IF EXIST "!REPRO_DIR!" (
            goto CONTINUE
        )
    )
    
    ECHO SOURCE Dir not found / failed
    ECHO Listing directory :
    dir /a:d /s /b /o:n SourceDir
    GOTO FAILED

    :CONTINUE
    ECHO Source dir used : !REPRO_DIR!

    IF NOT DEFINED OUTPUT_BASE_FILENAME SET OUTPUT_BASE_FILENAME=!PRODUCT_SKU!!PRODUCT_MAJOR_VERSION!-!PRODUCT_CATEGORY!_!FOLDER_PLATFORM!_windows_!TEMPLATE_NAME!-!PRODUCT_FULL_VERSION!
    REM find all *.wxi.template,*.wxl.template,*.wxs.template files and replace text with configurations
    FOR /f %%i IN ('dir /s /b *.wxi.template, *.Base.*.wxl.template *.!TEMPLATE_NAME!.*.wxl.template,*.wxs.template') DO (
        SET INPUT_FILE=%%~ni
        REM Prevent concurrency issues if multiple builds are running in parallel.
        SET OUTPUT_FILE=%WORKDIR%!OUTPUT_BASE_FILENAME!-!INPUT_FILE:.template=%!
        ECHO string replacement input !INPUT_FILE! output !OUTPUT_FILE!
        powershell -Command "(gc -Raw -encoding utf8 %%i) -replace '{vendor}', '!VENDOR!' -replace '{vendor_branding_logo}', '!VENDOR_BRANDING_LOGO!' -replace '{vendor_branding_banner}', '!VENDOR_BRANDING_BANNER!' -replace '{vendor_branding_dialog}', '!VENDOR_BRANDING_DIALOG!' -replace '{vendor_branding}', '!VENDOR_BRANDING!' -replace '{product_help_link}', '!PRODUCT_HELP_LINK!' -replace '{product_support_link}', '!PRODUCT_SUPPORT_LINK!' -replace '{product_update_info_link}', '!PRODUCT_UPDATE_INFO_LINK!' | Out-File -encoding utf8 !OUTPUT_FILE!"
	IF ERRORLEVEL 1 (
	    ECHO Unable to make string replacement
	    GOTO FAILED
	)
    )

    SET CACHE_BASE_FOLDER=Cache
    REM Each build his own cache for concurrent build
    SET CACHE_FOLDER=!CACHE_BASE_FOLDER!\!OUTPUT_BASE_FILENAME!

    REM Generate one ID per release. But do NOT use * as we need to keep the same number for all languages, but not platforms.
    FOR /F %%I IN ('POWERSHELL -COMMAND "$([guid]::NewGuid().ToString('b').ToUpper())"') DO (
      SET PRODUCT_ID=%%I
      ECHO PRODUCT_ID: !PRODUCT_ID!
    )

    IF NOT DEFINED UPGRADE_CODE_SEED (
        REM If no UPGRADE_CODE_SEED given .. we are not trying to build upgradable MSI and generate always a new PRODUCT_UPGRADE_CODE
        FOR /F %%F IN ('POWERSHELL -COMMAND "$([guid]::NewGuid().ToString('b').ToUpper())"') DO (
          SET PRODUCT_UPGRADE_CODE=%%F
          ECHO Unique PRODUCT_UPGRADE_CODE: !PRODUCT_UPGRADE_CODE!
        )
    ) ELSE (
        REM It will be better if we can generate "Name-based UUID" as specified here https://tools.ietf.org/html/rfc4122#section-4.3
        REM but it's too difficult so fallback to random like guid based on md5 hash with getGuid.ps1
        REM We use md5 hash to always get the same PRODUCT_UPGRADE_CODE(GUID) for each MSI build with same GUID_SSED to allow upgrade from Adoptium
        REM IF PRODUCT_UPGRADE_CODE change from build to build, upgrade is not proposed by Windows Installer
        REM Never change what compose SOURCE_TEXT_GUID and args0 for getGuid.ps1 or you will never get the same GUID as previous build and MSI upgradable feature wont work
        SET SOURCE_TEXT_GUID=!PRODUCT_CATEGORY!-!PRODUCT_MAJOR_VERSION!-!PLATFORM!-!PACKAGE_TYPE!
        ECHO SOURCE_TEXT_GUID ^(without displaying secret UPGRADE_CODE_SEED^) : !SOURCE_TEXT_GUID!
        FOR /F %%F IN ('powershell -File getGuid.ps1 !SOURCE_TEXT_GUID!-%UPGRADE_CODE_SEED%') DO (
          SET PRODUCT_UPGRADE_CODE=%%F
          ECHO Constant PRODUCT_UPGRADE_CODE: !PRODUCT_UPGRADE_CODE!
        )
    )

    REM Clean .cab cache for each run .. Cache is only used inside BuildSetupTranslationTransform.cmd to speed up MST generation
    IF EXIST !CACHE_FOLDER! rmdir /S /Q !CACHE_FOLDER!
    MKDIR !CACHE_FOLDER!
	IF ERRORLEVEL 1 (
		ECHO Unable to create cache folder : !CACHE_FOLDER!
	    GOTO FAILED
	)

    REM Set default variable
    SET ICEDTEAWEB_DIR=.\SourceDir\icedtea-web-image
    SET BUNDLE_ICEDTEAWEB=false
    IF !PLATFORM! == x64 (
        IF !PRODUCT_MAJOR_VERSION! == 8 (
            IF EXIST !ICEDTEAWEB_DIR! (
                ECHO IcedTeaWeb Directory Exists!
                SET BUNDLE_ICEDTEAWEB=true
                SET ITW_WXS="%WORKDIR%IcedTeaWeb-!OUTPUT_BASE_FILENAME!.wxs"
                ECHO HEAT IcedTeaWeb
                @ECHO ON
                !WIX_HEAT_PATH! dir "!ICEDTEAWEB_DIR!" ^
                    -out !ITW_WXS! ^
                    -t "!SETUP_RESOURCES_DIR!\heat.icedteaweb.xslt" ^
                    -gg ^
                    -sfrag ^
                    -scom ^
                    -sreg ^
                    -srd ^
                    -ke ^
                    -cg "IcedTeaWebFiles" ^
                    -var var.IcedTeaWebDir ^
                    -dr INSTALLDIR ^
                    -platform !PLATFORM!
                IF ERRORLEVEL 1 (
                    ECHO "Failed to generate Windows Installer XML Source files for IcedTea-Web (.wxs)"
                    GOTO FAILED
                )
                @ECHO OFF

                @REM Add suffix to declaration and references of the IcedTeaWebDir 'bin' subfolder
                @REM This is to avoid dubplicate Id conflict with INSTALLDER 'bin' subfolder
                powershell -ExecutionPolicy Bypass -File "%~dp0\helpers\Update-id.ps1" ^
                    -FilePath !ITW_WXS! ^
                    -Name bin ^
                    -Suffix IcedTea

            ) ELSE (
                ECHO IcedTeaWeb Directory Does Not Exist!
            )
        )
    )
    
    ECHO HEAT
    @ECHO ON
    !WIX_HEAT_PATH! dir "!REPRO_DIR!" ^
        -out %WORKDIR%!OUTPUT_BASE_FILENAME!-Files.wxs ^
        -gg -sfrag -scom -sreg -srd -ke ^
        -cg "AppFiles" ^
        -var var.ProductMajorVersion ^
        -var var.ProductMinorVersion ^
        -var var.ProductVersionString ^
        -var var.MSIProductVersion ^
        -var var.ReproDir ^
        -dr INSTALLDIR ^
        -platform !PLATFORM!
    IF ERRORLEVEL 1 (
        ECHO Failed to generate Windows Installer XML Source files ^(.wxs^)
        GOTO FAILED
    )
    @ECHO OFF

    ECHO BUILD
    @ECHO ON
    wix build -arch !PLATFORM! ^
        %WORKDIR%!OUTPUT_BASE_FILENAME!-Main.wxs ^
        %WORKDIR%!OUTPUT_BASE_FILENAME!-Files.wxs ^
        !ITW_WXS! ^
        -ext WixToolset.UI.wixext ^
        -ext WixToolset.Util.wixext ^
        -d IcedTeaWebDir="!ICEDTEAWEB_DIR!" ^
        -d OutputBaseFilename="!OUTPUT_BASE_FILENAME!" ^
        -d ProductSku="!PRODUCT_SKU!" ^
        -d ProductMajorVersion="!PRODUCT_MAJOR_VERSION!" ^
        -d ProductMinorVersion="!PRODUCT_MINOR_VERSION!" ^
        -d ProductVersionString="!PRODUCT_SHORT_VERSION!" ^
        -d MSIProductVersion="!MSI_PRODUCT_VERSION!" ^
        -d ProductId="!PRODUCT_ID!" ^
        -d ProductUpgradeCode="!PRODUCT_UPGRADE_CODE!" ^
        -d ReproDir="!REPRO_DIR!" ^
        -d SetupResourcesDir="!SETUP_RESOURCES_DIR!" ^
        -d Culture="!CULTURE!" ^
        -d JVM="!PACKAGE_TYPE!" ^
        -cc !CACHE_FOLDER! ^
        -loc "%WORKDIR%!OUTPUT_BASE_FILENAME!-!PRODUCT_SKU!.Base.!CULTURE!.wxl" ^
        -loc "%WORKDIR%!OUTPUT_BASE_FILENAME!-!PRODUCT_SKU!.!TEMPLATE_NAME!.!CULTURE!.wxl" ^
        -out "ReleaseDir\!OUTPUT_BASE_FILENAME!.msi" ^
        -culture !CULTURE! ^
        -pdbtype none
    IF ERRORLEVEL 1 (
        ECHO Failed to process and compile Windows Installer XML Source files ^(.wxs^) into installer ^(.msi^)
        dir /s /b /o:n %WORKDIR%
        GOTO FAILED
    )
    @ECHO OFF

    REM Generate setup translations
    FOR /F "tokens=1-2" %%L IN (Lang\LanguageList.config) do (
        CALL BuildSetupTranslationTransform.cmd %%L %%M
        IF ERRORLEVEL 1 (
            ECHO failed to build translation %%L %%M
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
		ECHO VALIDATE
		@ECHO ON
		wix msi validate "ReleaseDir\!OUTPUT_BASE_FILENAME!.msi"
		IF ERRORLEVEL 1 (
			ECHO Failed to validate MSI
		    GOTO FAILED
		) ELSE (
            ECHO MSI validation passed
        )
		@ECHO OFF
	) ELSE (
        ECHO MSI validation was skipped by option SKIP_MSI_VALIDATION=true
    )

    REM SIGN the MSIs with digital signature.
    REM Dual-Signing with SHA-1/SHA-256 requires Win 8.1 SDK or later.
    IF DEFINED SIGNING_CERTIFICATE (
        set timestampErrors=0
        for /L %%a in (1,1,15) do (
            for /F %%s IN (serverTimestamp.config) do (
	        ECHO try !timestampErrors! / sha256 / timestamp server : %%s
		REM Always hide password here
		@ECHO OFF
                "%ProgramFiles(x86)%\Windows Kits\%WIN_SDK_MAJOR_VERSION%\bin\%WIN_SDK_FULL_VERSION%\x64\signtool.exe" sign -f "%SIGNING_CERTIFICATE%" -p "%SIGN_PASSWORD%" -fd sha256 -d "Adoptium" -t %%s "ReleaseDir\!OUTPUT_BASE_FILENAME!.msi"
		@ECHO ON
		IF NOT "%DEBUG%" == "true" @ECHO OFF

                REM check the return value of the timestamping operation and retry a max of ten times...
                if ERRORLEVEL 0 if not ERRORLEVEL 1 GOTO succeeded

                echo Signing failed. Probably cannot find the timestamp server at %%s
                set /a timestampErrors+=1
            )
            REM always wait more than seconds after each retry
            choice /N /T:%%a /C:Y /D:Y >NUL
        )

        REM return an error code...
        echo sign.bat exit code is 1. There were %timestampErrors% timestamping errors.
        exit /b 1

    ) ELSE (
        ECHO Ignoring signing step : certificate not configured
    )

    :succeeded
    REM return a successful code...
    echo sign.bat exit code is 0. There were %timestampErrors% timestamping errors.

    REM Remove files we do not need any longer.
    DEL "%WORKDIR%!OUTPUT_BASE_FILENAME!-Files.wxs"
    DEL "%WORKDIR%!OUTPUT_BASE_FILENAME!-Main.wxs"
    DEL "%WORKDIR%!OUTPUT_BASE_FILENAME!-!PRODUCT_SKU!.!TEMPLATE_NAME!.*.wxl"
    DEL "%WORKDIR%!OUTPUT_BASE_FILENAME!-!PRODUCT_SKU!.Base.*.wxl"
    DEL "%WORKDIR%!OUTPUT_BASE_FILENAME!-!PRODUCT_SKU!.Variables.wxi"
    IF DEFINED ITW_WXS (
        DEL !ITW_WXS!
    )
    RMDIR /S /Q !CACHE_FOLDER!
    SET TEMPLATE_NAME=
  )
  SET ITW_WXS=
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
SET PRODUCT_BUILD_NUMBER=
SET MSI_PRODUCT_VERSION=
SET PRODUCT_ID=
SET PRODUCT_VERSION=
SET PLATFORM=
SET FOLDER_PLATFORM=
SET REPRO_DIR=
SET SETUP_RESOURCES_DIR=
SET WIN_SDK_FULL_VERSION=
SET WIN_SDK_MAJOR_VERSION=
SET ICEDTEAWEB_DIR=
SET BUNDLE_ICEDTEAWEB=

EXIT /b 0

:FAILED
EXIT /b 2
