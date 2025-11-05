#ifndef INSTALL_HANDLER_INCLUDED
#define INSTALL_HANDLER_INCLUDED

#include "helpers.iss"
#include "get_constants.iss"
#include "boolean_checks.iss"

[Code]
// Store the user's task choices + metadata in an INI file in the installation directory
// This allows us to read the task selections during uninstallation
procedure StoreTaskSelections(TaskName: string);
var
  TaskStateFile: string;
begin
  // Store each task selection state in an INI file during installation
  TaskStateFile := ExpandConstant('{#IniFile}');

  // Add metadata to the INI file only if TaskName is 'METADATA'
  if TaskName = 'METADATA' then
  begin
    SetIniString('Metadata', 'Publisher', ExpandConstant('{#Vendor}'), TaskStateFile);
    SetIniString('Metadata', 'InstallDate', GetDateTimeString('yyyy/mm/dd hh:nn:ss', #0, #0), TaskStateFile);
    SetIniString('Metadata', 'Version', ExpandConstant('{#ExeProductVersion}'), TaskStateFile);
  end
  // Create the INI file with task selections
  else if WizardIsTaskSelected(TaskName) then
    SetIniString('Tasks', TaskName, '1', TaskStateFile)
  else
    SetIniString('Tasks', TaskName, '0', TaskStateFile);
end;

// Add the JDK to either the System or User PATH environment variable.
procedure AddToPath(AppBinPath: string; EnvRegKey: string; RegRoot: Integer);
var
  UserPath: string;
begin
  // Read current PATH
  if not RegQueryStringValue(RegRoot, EnvRegKey, 'PATH', UserPath) then
    UserPath := '';

  // Check if our path entry is already in PATH (returns 0 if not found)
  if Pos(AppBinPath, UserPath) = 0 then
  begin
    // Prepend our path entry to PATH
    if UserPath <> '' then
      UserPath := AppBinPath + ';' + UserPath
    else
      // If PATH is empty, just set it to our path entry
      UserPath := AppBinPath;

    // Write back to registry
    RegWriteStringValue(RegRoot, EnvRegKey, 'PATH', UserPath);
  end;
end;

// Uninstall the previous version of the same openJDK package if it exists
// Logs if /LOG is passed into compile cli, or if SetupLogging=yes in [Setup] section
//  Without a specified log location, logs to: '%TEMP%\Setup Log YYYY-MM-DD #001.txt' by default
procedure UninstallPreviousVersion();
var
  UninstallKeyExe: string;
  MsiGuid: string;
  UninstallString: string;
  ResultCode: Integer;
  DisplayName: string;
  RegistryRoots: array[0..1] of Integer;
  RootNames: array[0..1] of string;
  i: Integer;
  CurrentRoot: Integer;
  RootName: string;
begin
  // Initialize arrays for registry roots and their names
  RegistryRoots[0] := HKLM;
  RegistryRoots[1] := HKCU;
  RootNames[0] := 'system';
  RootNames[1] := 'user';

  // All EXE uninstall strings are stored here, regardless of vendor
  UninstallKeyExe := ExpandConstant('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#AppID}_is1');

  // Loop through both HKLM and HKCU
  for i := 0 to 1 do
  begin
    CurrentRoot := RegistryRoots[i];
    RootName := RootNames[i];

    // Check for EXE uninstaller. If found, var UninstallString is assigned
    if RegQueryStringValue(CurrentRoot, UninstallKeyExe, 'UninstallString', UninstallString) then
    begin
      if RegQueryStringValue(CurrentRoot, UninstallKeyExe, 'DisplayName', DisplayName) then
      begin
        Log('Found previous ' + RootName + ' installation: ' + DisplayName);
      end;
      Log('Uninstall string (with quotes): ' + UninstallString);
      Log('Uninstall string (quotes removed): ' + RemoveQuotes(UninstallString));

      // Run the uninstaller silently (the Uninstall string has quotes that we need to remove)
      if Exec(RemoveQuotes(UninstallString), '/VERYSILENT /NORESTART', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      begin
        Log('Previous ' + RootName + ' installation uninstalled successfully. Result code: ' + IntToStr(ResultCode));
      end
      else
      begin
        Log('Failed to uninstall previous ' + RootName + ' installation. Result code: ' + IntToStr(ResultCode));
      end;
    end;

    // Check for MSI uninstaller. If found, var MsiGuid is assigned
    if GetInstalledMsiString(CurrentRoot, ExpandConstant('{#AppID}'), MsiGuid) then
    begin
      Log('Found installed MSI: ' + MsiGuid);

      // Uninstall the MSI silently
      if Exec('MsiExec.exe', '/x ' + MsiGuid + ' /qn /norestart', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      begin
        Log('Previous ' + RootName + ' MSI installation uninstalled successfully. Result code: ' + IntToStr(ResultCode));
      end
      else
      begin
        Log('Failed to uninstall previous ' + RootName + ' MSI installation. Result code: ' + IntToStr(ResultCode));
      end;
    end;

  end;
end;

// This function defines installation logic at each step of the installation process:
//    ssInstall     - just before the actual installation starts
//    ssPostInstall - just after the actual installation finishes
//    ssDone        - just before Setup terminates after a successful install
// For more info, see the CurStepChanged section in https://jrsoftware.org/ishelp/index.php?topic=scriptevents
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
  begin
    // Uninstall previous version if it exists
    UninstallPreviousVersion();
  end
  // Store task selections just after the actual installation finishes but before registry entries are created
  else if CurStep = ssPostInstall then
  begin
    StoreTaskSelections('FeatureEnvironment');
    StoreTaskSelections('FeatureJarFileRunWith');
    StoreTaskSelections('FeatureJavaHome');
    StoreTaskSelections('FeatureOracleJavaSoft');
    StoreTaskSelections('METADATA');

    // Add {app}\bin to PATH only if the user requested it
    if WasTaskSelected('FeatureEnvironment') then
      AddToPath(ExpandConstant('{app}\bin'), GetEnvironmentRegPath(), GetRegistryRoot());
  end;
end;

// As the EXE installer initializes, compare the version being installed with any existing version
// If an existing version is newer, abort installation with an error message
// For more info, see https://jrsoftware.org/ishelp/index.php?topic=scriptevents
function InitializeSetup(): Boolean;
var
  UninstallKeyExe: string;
  DisplayVersion: string;
  DisplayName: string;
  RegistryRoots: array[0..1] of Integer;
  i: Integer;
  CurrentRoot: Integer;
  VersionComparison: Integer;
  MsgBoxString: string;
  MsiGuid: string;
begin
  Result := True;

  // Initialize arrays for registry roots and their names
  RegistryRoots[0] := HKLM;
  RegistryRoots[1] := HKCU;

  // All EXE info is stored here, regardless of vendor
  UninstallKeyExe := ExpandConstant('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#AppID}_is1');

  // Loop through both HKLM and HKCU
  for i := 0 to 1 do
  begin
    CurrentRoot := RegistryRoots[i];

    // Check if a previous version was installed via EXE and compare
    if RegQueryStringValue(CurrentRoot, UninstallKeyExe, 'DisplayVersion', DisplayVersion) then
    begin
      RegQueryStringValue(CurrentRoot, UninstallKeyExe, 'DisplayName', DisplayName);
      Log('Previous version to uninstall: ' + DisplayVersion);
      Log('Previous version display name: ' + DisplayName);

      // Compare versions and exit if existing version is higher
      // Note: see helpers.iss for CompareVersions() function
      VersionComparison := CompareVersions(DisplayVersion, ExpandConstant('{#ExeProductVersion}'));
      if VersionComparison > 0 then
      begin
        // This message (translated into all languages supported by Inno Setup), reads:
        //    The existing file is newer than the one Setup is trying to install. version {Existing_ExeProductVersion} > version {Installer_ExeProductVersion}
        // Example:
        //    The existing file is newer than the one Setup is trying to install. version 25.0.1.8 > version 25.0.0.36
        MsgBoxString := SetupMessage(msgExistingFileNewer2) +
          FmtMessage(CustomMessage('NameAndVersion'), ['', DisplayVersion]) +
          ' >' +
          FmtMessage(CustomMessage('NameAndVersion'), ['', ExpandConstant('{#ExeProductVersion}')]);
        // For info on MsgBox(), see https://jrsoftware.org/ishelp/index.php?topic=isxfunc_msgbox
        MsgBox(MsgBoxString, mbError, MB_OK);
        Log('Newer version detected. Exiting installation.');
        Result := False;
        Exit;
      end
      else if VersionComparison = 0 then
      begin
        // This message (translated into all languages supported by Inno Setup), reads:
        //    Setup is preparing to install {APP_NAME} on your computer. The file already exists. Overwrite the existing file?
        // Example:
        //    Setup is preparing to install Eclipse Temurin JDK with Hotspot 25.0.1+8 (x64) on your computer. The file already exists. Overwrite the existing file?
        MsgBoxString := ReplaceSubstring(SetupMessage(msgPreparingDesc), '[name]', ExpandConstant('{#AppName}')) +
                 ' ' + SetupMessage(msgFileExists2) +
                 ' ' + ReplaceSubstring(SetupMessage(msgFileExistsOverwriteExisting), '&', '') + '?';
        // For info on SuppressibleMsgBox(), see https://jrsoftware.org/ishelp/index.php?topic=isxfunc_suppressiblemsgbox
        if SuppressibleMsgBox(MsgBoxString, mbInformation, MB_YESNO, IDYES) = IDYES then
        begin
          Log('Same version detected: "' + DisplayVersion + '". Proceeding with reinstallation.');
          // Exit here since we do not need to ask the user again if they want to overwrite older installations
          Exit;
        end
        else
        begin
          Log('User chose not to reinstall same version.');
          Result := False;
          Exit;
        end;
      end;
    end;

    // Check if a previous version was installed via MSI
    if GetInstalledMsiString(CurrentRoot, ExpandConstant('{#AppID}'), MsiGuid) then
    begin
      // This message (translated into all languages supported by Inno Setup), reads:
      //    Setup is preparing to install {APP_NAME} on your computer. The file already exists. Overwrite the existing file?
      // Example:
      //    Setup is preparing to install Eclipse Temurin JDK with Hotspot 25.0.1+8 (x64) on your computer. The file already exists. Overwrite the existing file?
      MsgBoxString := ReplaceSubstring(SetupMessage(msgPreparingDesc), '[name]', ExpandConstant('{#AppName}')) +
                ' ' + SetupMessage(msgFileExists2) +
                ' ' + ReplaceSubstring(SetupMessage(msgFileExistsOverwriteExisting), '&', '') + '? + MSI';
      // For info on SuppressibleMsgBox(), see https://jrsoftware.org/ishelp/index.php?topic=isxfunc_suppressiblemsgbox
      if SuppressibleMsgBox(MsgBoxString, mbInformation, MB_YESNO, IDYES) = IDYES then
      begin
        Log('Legacy MSI version detected. Proceeding with overwriting.');
      end
      else
      begin
        Log('User chose not to overwrite legacy version.');
        Result := False;
        Exit;
      end;
    end;

  end;
end;

#endif