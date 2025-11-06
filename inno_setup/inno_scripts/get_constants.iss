#ifndef GET_CONSTANTS_INCLUDED
#define GET_CONSTANTS_INCLUDED

[Code]
// Returns appropriate registry root based on installation mode
// (returns an int representing an enum)
function GetRegistryRoot(): Integer;
begin
  if IsAdminInstallMode then
    Result := HKLM
  else
    Result := HKCU;
end;

// Returns path to Registry Key that contains environment variable based on installation mode
function GetEnvironmentRegPath(): string;
begin
  if IsAdminInstallMode then
    Result := 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
  else
    Result := 'Environment';
end;

// Returns the default installation directory based on the installation mode and system architecture
function GetDefaultDir(Param: string): string;
var
  DefaultProductFolder: string;
begin
  //  Example: jdk-25.0.1.8-hotspot
  DefaultProductFolder := Lowercase(ExpandConstant('{#ProductCategory}')) + '-' + ExpandConstant('{#ExeProductVersion}') + '-' + ExpandConstant('{#JVM}');
  if IsAdminInstallMode then
    // Here {commonpf}='C:\Program Files' for x64, aarch64, and x86 Archs since
    //  'ArchitecturesInstallIn64BitMode=win64' was set in [Setup]
    Result := ExpandConstant('{commonpf}\{#Vendor}\' + DefaultProductFolder)
  else
    // {userpf}='C:\Users\<USERNAME>\AppData\Local\Programs'
    Result := ExpandConstant('{userpf}\{#Vendor}\' + DefaultProductFolder);
end;

#endif
