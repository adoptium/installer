#ifndef INSTALL_HANDLER_INCLUDED
#define INSTALL_HANDLER_INCLUDED

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
  UninstallKey: string;
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
  UninstallKey := ExpandConstant('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#AppID}_is1');

  // Loop through both HKLM and HKCU
  for i := 0 to 1 do
  begin
    CurrentRoot := RegistryRoots[i];
    RootName := RootNames[i];

    if RegQueryStringValue(CurrentRoot, UninstallKey, 'UninstallString', UninstallString) then
    begin
      if RegQueryStringValue(CurrentRoot, UninstallKey, 'DisplayName', DisplayName) then
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
    end
    else
    begin
      Log('No previous ' + RootName + ' installation found.');
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
    StoreTaskSelections('pathMod');
    StoreTaskSelections('jarfileMod');
    StoreTaskSelections('javaHomeMod');
    StoreTaskSelections('javasoftMod');
    StoreTaskSelections('METADATA');

    // Add {app}\bin to PATH only if the user requested it
    if WasTaskSelected('pathMod') then
      AddToPath(ExpandConstant('{app}\bin'), GetEnvironmentRegPath(), GetRegistryRoot());
  end;
end;

#endif