#ifndef UNINSTALL_HANDLER_INCLUDED
#define UNINSTALL_HANDLER_INCLUDED

#include "get_constants.iss"
#include "boolean_checks.iss"

[Code]
procedure RemoveFromPath(AppBinPath: string; EnvRegKey: string; RegRoot: Integer);
var
  UserPath: string;
  PathEntries: TArrayOfString;
  i: Integer;
  NewPath: string;
begin
  // Read current PATH
  if not RegQueryStringValue(RegRoot, EnvRegKey, 'PATH', UserPath) then
    Exit;
  
  // Split PATH into individual entries, excluding empty entries
  PathEntries := StringSplit(UserPath, [';'], stExcludeEmpty);
  NewPath := '';
  
  // Rebuild PATH without our entry
  for i := 0 to GetArrayLength(PathEntries) - 1 do
  begin
    if PathEntries[i] <> AppBinPath  then
    begin
      if NewPath <> '' then
        NewPath := NewPath + ';' + PathEntries[i]
      else
        // Initialize NewPath with the first valid entry
        NewPath := PathEntries[i];
    end;
  end;
  
  // Write back to registry
  RegWriteStringValue(RegRoot, EnvRegKey, 'PATH', NewPath);
end;

// Set registry key HKLM "SOFTWARE\JavaSoft\{#ProductCategory}" to either:
// 1. The name of the subkey that is the highest LTS integer (with FeatureOracleJavaSoft, ignore subkeys that are not integers) under "SOFTWARE\JavaSoft\{#ProductCategory}"
// 2. Delete the value if no other versions are found
procedure SetHighestJavaVersionRemaining();
var
  SubKeys: TArrayOfString;
  i: Integer;
  MaxVersion: Integer;
  CurrentVersion: Integer;
  MaxVersionStr: string;
  CurrentVersionStr: string;
begin
  // Initialize max version
  MaxVersion := -1;
  MaxVersionStr := '';

  // Check that the JavaSoft registry key and corresponding CurrentVersion value exist
  if not RegQueryStringValue(HKLM, ExpandConstant('SOFTWARE\JavaSoft\{#ProductCategory}'), 'CurrentVersion', CurrentVersionStr) then
  begin
    // Key or value does not exist, so nothing to do
    Exit;
  end
  else
  begin
    if CurrentVersionStr <> ExpandConstant('{#ProductMajorVersion}') then
    begin
      // Current version does not match our installed version, so no need to update
      Exit;
    end;
  end;

  // Get subkeys under "SOFTWARE\JavaSoft\{#ProductCategory}"
  if RegGetSubKeyNames(HKLM, ExpandConstant('SOFTWARE\JavaSoft\{#ProductCategory}'), SubKeys) then
  begin
    // Iterate through subkeys to find the highest integer LTS JDK version installed (with FeatureOracleJavaSoft)
    for i := 0 to GetArrayLength(SubKeys) - 1 do
    begin
      CurrentVersion := StrToIntDef(SubKeys[i], -1);
      if (CurrentVersion > MaxVersion) and (SubKeys[i] <> ExpandConstant('{#ProductMajorVersion}')) then
      begin
        MaxVersion := CurrentVersion;
        MaxVersionStr := SubKeys[i];
      end;
    end;
    // Set or delete the CurrentVersion value based on the max version found
    if MaxVersion > 0 then
    begin
      // Set CurrentVersion to the highest LTS version still on the User's system (with FeatureOracleJavaSoft)
      RegWriteStringValue(HKLM, ExpandConstant('SOFTWARE\JavaSoft\{#ProductCategory}'), 'CurrentVersion', MaxVersionStr);
    end
    else
    begin
      // No JDKs with FeatureOracleJavaSoft remaining on the user's system, so delete the RegistryKey
      RegDeleteValue(HKLM, ExpandConstant('SOFTWARE\JavaSoft\{#ProductCategory}'), 'CurrentVersion');
      // Delete the remaining JavaSoft keys if empty
      RegDeleteKeyIfEmpty(HKLM, ExpandConstant('SOFTWARE\JavaSoft\{#ProductCategory}'));
      RegDeleteKeyIfEmpty(HKLM, ExpandConstant('SOFTWARE\JavaSoft'));
    end;
  end;
end;


// This function defines uninstallation logic at each step of the uninstallation process:
//    usUninstall     - just before the actual uninstallation starts
//    usPostUninstall - just after the actual uninstallation finishes
//    usDone          - just before process terminates after a successful uninstall
// For more info, see the CurStepChanged and TUninstallStep sections in https://jrsoftware.org/ishelp/index.php?topic=scriptevents
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  // Action is performed right before uninstallation starts
  if CurUninstallStep = usUninstall then
  begin
    // Remove {app}\bin from PATH only if added during installation
    if WasTaskSelected('FeatureEnvironment') then
    begin
      RemoveFromPath(ExpandConstant('{app}\bin'), GetEnvironmentRegPath(), GetRegistryRoot());
    end;

    if WasTaskSelected('FeatureOracleJavaSoft') then
    begin
      SetHighestJavaVersionRemaining();
    end;
  end;
end;

#endif