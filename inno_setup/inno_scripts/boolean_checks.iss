#ifndef BOOLEAN_CHECKS_INCLUDED
#define BOOLEAN_CHECKS_INCLUDED

#include "get_constants.iss"

[Code]
// Check if we should update the Java version:
//    True if NewMajorVersion > UsersMajorVersion or if UsersMajorVersion == 1.8 (Java 8)
function ShouldUpdateJavaVersion(): Boolean;
var
  CurrentVersion: String;
  CurrentMajorVersion: Integer;
  NewMajorVersion: Integer;
begin
  // Convert our new version to integer for comparison
  NewMajorVersion := StrToInt('{#ProductMajorVersion}');
  
  // Check if the registry key exists
  if RegQueryStringValue(HKLM, 'SOFTWARE\JavaSoft\' + '{#ProductCategory}', 'CurrentVersion', CurrentVersion) then
  begin
    // Special case: Always update if current version is 1.8
    if CurrentVersion = '1.8' then
      Result := True
    else
    begin
      // Try to convert the existing version to an integer for comparison
      // If conversion fails, the default value of 0 will be used
      CurrentMajorVersion := StrToIntDef(CurrentVersion, 0);
      
      // Update only if our version is higher
      Result := NewMajorVersion > CurrentMajorVersion;
    end;
  end
  else
  begin
    // Key doesn't exist, so we should update
    Result := True;
  end;
end;

// Reads local INI file to check if a task was selected during installation
//  During installation: INI file is not needed yet, task is equivalent to WizardIsTaskSelected
//  During uninstallation: INI file is read to determine keys + env vars to remove
function WasTaskSelected(TaskName: string): Boolean;
var
  TaskValue: string;
  TaskStateFile: string;
begin
  // During installation, use WizardIsTaskSelected
  if not IsUninstaller then
    Result := WizardIsTaskSelected(TaskName)
  else
  begin
    // During uninstallation, read from INI file
    TaskStateFile := ExpandConstant('{#IniFile}');
    if FileExists(TaskStateFile) then
    begin
      TaskValue := GetIniString('Tasks', TaskName, '0', TaskStateFile);
      Result := TaskValue = '1';
    end
    else
      Result := False;
  end;
end;

#endif