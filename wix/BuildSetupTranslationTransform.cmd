REM @ECHO OFF
REM
REM Do not run this file at it's own. The Build.cmd in the same folder will call this file.
REM

IF EXIST "%1" = "" goto failed
IF EXIST "%2" = "" goto failed

SET CULTURE=%1
SET LANGID=%2

SET LANGIDS=%LANGIDS%,%LANGID%

ECHO Building setup translation for culture "%1" with LangID "%2"...
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
    -loc "%WORKDIR%!OUTPUT_BASE_FILENAME!-!PRODUCT_SKU!.!PACKAGE_TYPE!.!CULTURE!.wxl" ^
    -out "ReleaseDir\!OUTPUT_BASE_FILENAME!.!CULTURE!.msi" ^
    -culture !CULTURE! ^
    -pdbtype none
IF ERRORLEVEL 1 (
    ECHO Building msi for culture %CULTURE% failed with errorlevel: %ERRORLEVEL%
    GOTO FAILED
)

cscript "%ProgramFiles(x86)%\Windows Kits\%WIN_SDK_MAJOR_VERSION%\bin\%WIN_SDK_FULL_VERSION%\x64\WiLangId.vbs" //Nologo ReleaseDir\!OUTPUT_BASE_FILENAME!.!CULTURE!.msi Product %LANGID%
IF ERRORLEVEL 1 (
    ECHO WiLangId failed with : %ERRORLEVEL%
    GOTO FAILED
)
"%ProgramFiles(x86)%\Windows Kits\%WIN_SDK_MAJOR_VERSION%\bin\%WIN_SDK_FULL_VERSION%\x86\msitran" -g "ReleaseDir\!OUTPUT_BASE_FILENAME!.msi" "ReleaseDir\!OUTPUT_BASE_FILENAME!.!CULTURE!.msi" "ReleaseDir\!OUTPUT_BASE_FILENAME!.!CULTURE!.mst"
IF ERRORLEVEL 1 (
    ECHO msitran failed with : %ERRORLEVEL%
    GOTO FAILED
)
ECHO.
cscript "%ProgramFiles(x86)%\Windows Kits\%WIN_SDK_MAJOR_VERSION%\bin\%WIN_SDK_FULL_VERSION%\x64\wisubstg.vbs" //Nologo ReleaseDir\!OUTPUT_BASE_FILENAME!.msi ReleaseDir\!OUTPUT_BASE_FILENAME!.!CULTURE!.mst %LANGID%
IF ERRORLEVEL 1 (
    ECHO wisubstg failed with : %ERRORLEVEL%
    GOTO FAILED
)
cscript "%ProgramFiles(x86)%\Windows Kits\%WIN_SDK_MAJOR_VERSION%\bin\%WIN_SDK_FULL_VERSION%\x64\wisubstg.vbs" //Nologo ReleaseDir\!OUTPUT_BASE_FILENAME!.msi

del /Q "ReleaseDir\!OUTPUT_BASE_FILENAME!.!CULTURE!.msi"
del /Q "ReleaseDir\!OUTPUT_BASE_FILENAME!.!CULTURE!.mst"
goto exit

:failed
ECHO Failed to generate setup translation of culture "%1" with LangID "%2".
EXIT /b 3

:exit
