@ECHO OFF
SETLOCAL ENABLEEXTENSIONS

IF "%~1" == "" GOTO USAGE
IF "%~2" == "" GOTO USAGE

SET "TARGET_ARCH=%~1"
SET "OUTPUT_PATH=%~2"
FOR %%I IN ("%OUTPUT_PATH%") DO SET "OUTPUT_PATH=%%~fI"

IF /I "%TARGET_ARCH%" == "x86" (
    SET "VCVARS_ARCH=x86"
) ELSE IF /I "%TARGET_ARCH%" == "x64" (
    SET "VCVARS_ARCH=amd64"
) ELSE IF /I "%TARGET_ARCH%" == "arm64" (
    SET "VCVARS_ARCH=amd64_arm64"
) ELSE (
    ECHO Unsupported advert custom action architecture: %TARGET_ARCH%
    EXIT /b 2
)

SET "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
IF EXIST "%VSWHERE%" (
    FOR /F "usebackq tokens=*" %%I IN (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) DO SET "VS_INSTALL_PATH=%%I"
)

IF DEFINED VS_INSTALL_PATH (
    CALL "%VS_INSTALL_PATH%\VC\Auxiliary\Build\vcvarsall.bat" %VCVARS_ARCH% >NUL
    IF ERRORLEVEL 1 (
        ECHO Failed to configure the Visual C++ compiler for %TARGET_ARCH%.
        EXIT /b 2
    )
) ELSE (
    WHERE cl.exe >NUL 2>NUL
    IF ERRORLEVEL 1 (
        ECHO Visual C++ Build Tools were not found. Install the Desktop development with C++ workload.
        EXIT /b 2
    )

    IF DEFINED VSCMD_ARG_TGT_ARCH IF /I NOT "%VSCMD_ARG_TGT_ARCH%" == "%TARGET_ARCH%" (
        ECHO The active Visual C++ target is %VSCMD_ARG_TGT_ARCH%, not %TARGET_ARCH%.
        EXIT /b 2
    )
)

SET "SOURCE_DIR=%~dp0..\CustomActions\Advert"
SET "BUILD_DIR=%TEMP%\adoptium-advert-%RANDOM%-%RANDOM%"
MKDIR "%BUILD_DIR%"
IF ERRORLEVEL 1 (
    ECHO Failed to create temporary advert custom action build directory.
    EXIT /b 2
)

cl.exe /nologo /O2 /GL /GS /MT /W4 /WX /EHsc /LD ^
    /DUNICODE /D_UNICODE /D_WIN32_WINNT=0x0601 ^
    "%SOURCE_DIR%\AdvertCustomAction.cpp" ^
    /Fo"%BUILD_DIR%\AdvertCustomAction.obj" ^
    /Fe"%OUTPUT_PATH%" ^
    /link /NOLOGO /LTCG /DYNAMICBASE /NXCOMPAT /OPT:REF /OPT:ICF ^
    /PDB:"%BUILD_DIR%\AdvertCustomAction.pdb" ^
    /IMPLIB:"%BUILD_DIR%\AdvertCustomAction.lib" ^
    msi.lib winhttp.lib
SET "BUILD_RESULT=%ERRORLEVEL%"

RMDIR /S /Q "%BUILD_DIR%"
IF NOT "%BUILD_RESULT%" == "0" (
    ECHO Failed to build the advert custom action for %TARGET_ARCH%.
    EXIT /b %BUILD_RESULT%
)

ECHO Built advert custom action: %OUTPUT_PATH%
EXIT /b 0

:USAGE
ECHO Usage: Build-AdvertCustomAction.cmd ^<x86^|x64^|arm64^> ^<output-dll^>
EXIT /b 2
