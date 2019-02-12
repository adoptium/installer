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
REM Build with extra Source Code feature (needs work)
REM IF EXIST Files-!OUTPUT_BASE_FILENAME!.wixobj "%WIX%bin\light.exe" Main-!OUTPUT_BASE_FILENAME!.wixobj Files-!OUTPUT_BASE_FILENAME!.wixobj Src-!OUTPUT_BASE_FILENAME!.wixobj -cc !CACHE_FOLDER! -reusecab -ext WixUIExtension -ext WixUtilExtension -spdb -out "ReleaseDir\!OUTPUT_BASE_FILENAME!.!CULTURE!.msi" -loc "Lang\%PRODUCT_SKU%.Base.!CULTURE!.wxl" -loc "Lang\%PRODUCT_SKU%.!PACKAGE_TYPE!.!CULTURE!.wxl" -cultures:!CULTURE!

REM Build without extra Source Code feature
IF EXIST Files-!OUTPUT_BASE_FILENAME!.wixobj "%WIX%bin\light.exe" Main-!OUTPUT_BASE_FILENAME!.wixobj Files-!OUTPUT_BASE_FILENAME!.wixobj -cc !CACHE_FOLDER! -reusecab -sval -ext WixUIExtension -ext WixUtilExtension -spdb -out "ReleaseDir\!OUTPUT_BASE_FILENAME!.!CULTURE!.msi" -loc "Lang\%PRODUCT_SKU%.Base.!CULTURE!.wxl" -loc "Lang\%PRODUCT_SKU%.!PACKAGE_TYPE!.!CULTURE!.wxl" -cultures:!CULTURE!
IF ERRORLEVEL 1 (
    GOTO FAILED
)

cscript "%ProgramFiles(x86)%\Windows Kits\%WIN_SDK_MAJOR_VERSION%\bin\%WIN_SDK_FULL_VERSION%\x64\WiLangId.vbs" ReleaseDir\!OUTPUT_BASE_FILENAME!.!CULTURE!.msi Product %LANGID%
IF ERRORLEVEL 1 (
    GOTO FAILED
)
"%ProgramFiles(x86)%\Windows Kits\%WIN_SDK_MAJOR_VERSION%\bin\%WIN_SDK_FULL_VERSION%\x86\msitran" -g "ReleaseDir\!OUTPUT_BASE_FILENAME!.msi" "ReleaseDir\!OUTPUT_BASE_FILENAME!.!CULTURE!.msi" "ReleaseDir\!OUTPUT_BASE_FILENAME!.!CULTURE!.mst"
IF ERRORLEVEL 1 (
    GOTO FAILED
)
cscript "%ProgramFiles(x86)%\Windows Kits\%WIN_SDK_MAJOR_VERSION%\bin\%WIN_SDK_FULL_VERSION%\x64\wisubstg.vbs" ReleaseDir\!OUTPUT_BASE_FILENAME!.msi ReleaseDir\!OUTPUT_BASE_FILENAME!.!CULTURE!.mst %LANGID%
IF ERRORLEVEL 1 (
    GOTO FAILED
)
cscript "%ProgramFiles(x86)%\Windows Kits\%WIN_SDK_MAJOR_VERSION%\bin\%WIN_SDK_FULL_VERSION%\x64\wisubstg.vbs" ReleaseDir\!OUTPUT_BASE_FILENAME!.msi

del /Q "ReleaseDir\!OUTPUT_BASE_FILENAME!.!CULTURE!.msi"
del /Q "ReleaseDir\!OUTPUT_BASE_FILENAME!.!CULTURE!.mst"
goto exit

:failed
ECHO Failed to generate setup translation of culture "%1" with LangID "%2".
EXIT /b 3

:exit
