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
REM IF EXIST Files-!OUTPUT_BASE_FILENAME!.wixobj "%WIX%bin\light.exe" Main.wixobj Files-!OUTPUT_BASE_FILENAME!.wixobj Src-!OUTPUT_BASE_FILENAME!.wixobj -ext WixUIExtension -ext WixUtilExtension -spdb -out "ReleaseDir\!OUTPUT_BASE_FILENAME!.!CULTURE!.msi" -loc "Lang\%PRODUCT_SKU%.Base.!CULTURE!.wxl" -loc "Lang\%PRODUCT_SKU%.!PACKAGE_TYPE!.!CULTURE!.wxl" -cultures:!CULTURE!

REM Build without extra Source Code feature
IF EXIST Files-!OUTPUT_BASE_FILENAME!.wixobj "%WIX%bin\light.exe" Main.wixobj Files-!OUTPUT_BASE_FILENAME!.wixobj -ext WixUIExtension -ext WixUtilExtension -spdb -out "ReleaseDir\!OUTPUT_BASE_FILENAME!.!CULTURE!.msi" -loc "Lang\%PRODUCT_SKU%.Base.!CULTURE!.wxl" -loc "Lang\%PRODUCT_SKU%.!PACKAGE_TYPE!.!CULTURE!.wxl" -cultures:!CULTURE!

cscript "%ProgramFiles(x86)%\Windows Kits\%WIN_SDK_VERSION%\bin\x64\WiLangId.vbs" ReleaseDir\!OUTPUT_BASE_FILENAME!.!CULTURE!.msi Product %LANGID%
"%ProgramFiles(x86)%\Windows Kits\%WIN_SDK_VERSION%\bin\x86\msitran" -g "ReleaseDir\!OUTPUT_BASE_FILENAME!.MUI.msi" "ReleaseDir\!OUTPUT_BASE_FILENAME!.!CULTURE!.msi" "ReleaseDir\!CULTURE!.mst"
cscript "%ProgramFiles(x86)%\Windows Kits\%WIN_SDK_VERSION%\bin\x64\wisubstg.vbs" ReleaseDir\!OUTPUT_BASE_FILENAME!.MUI.msi ReleaseDir\!CULTURE!.mst %LANGID%
cscript "%ProgramFiles(x86)%\Windows Kits\%WIN_SDK_VERSION%\bin\x64\wisubstg.vbs" ReleaseDir\!OUTPUT_BASE_FILENAME!.MUI.msi

del /Q "ReleaseDir\!OUTPUT_BASE_FILENAME!.!CULTURE!.msi"
del /Q "ReleaseDir\!CULTURE!.mst"
goto exit

:failed
ECHO Failed to generate setup translation of culture "%1" with LangID "%2".

:exit
