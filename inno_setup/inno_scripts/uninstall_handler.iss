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
      RemoveFromPath(ExpandConstant('{app}\bin'), GetEnvironmentRegPath(), GetRegistryRoot());
  end;
end;

#endif