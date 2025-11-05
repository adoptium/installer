#ifndef HELPERS_INCLUDED
#define HELPERS_INCLUDED

[Code]

// Replace OldSubstring with the specified NewSubstring in InputString
function ReplaceSubstring(InputString: string; OldSubstring: string; NewSubstring: string): string;
begin
  // For info on StringChangeEx: https://jrsoftware.org/ishelp/index.php?topic=isxfunc_stringchangeex
  Result := InputString;
  StringChangeEx(Result, OldSubstring, NewSubstring, True);
end;

// Compare two version strings in X.X.X.X format
// Returns: -1 if Version1 < Version2, 0 if equal, 1 if Version1 > Version2
function CompareVersions(Version1: string; Version2: string): Integer;
var
  V1Parts, V2Parts: TStringList;
  i, MaxLen, Part1, Part2: Integer;
begin
  Result := 0;
  V1Parts := TStringList.Create;
  V2Parts := TStringList.Create;
  try
    // Split versions by '.'
    V1Parts.Delimiter := '.';
    V1Parts.DelimitedText := Version1;
    V2Parts.Delimiter := '.';
    V2Parts.DelimitedText := Version2;

    // We do not have a Max() function available to us, so we do it manually
    if V1Parts.Count > V2Parts.Count then
      MaxLen := V1Parts.Count
    else
      MaxLen := V2Parts.Count;

    // Compare each part
    for i := 0 to MaxLen do
    begin
      // Get the part as integer (default to 0 if not present)
      if i < V1Parts.Count then
        Part1 := StrToIntDef(V1Parts[i], 0)
      else
        Part1 := 0;

      if i < V2Parts.Count then
        Part2 := StrToIntDef(V2Parts[i], 0)
      else
        Part2 := 0;

      if Part1 < Part2 then
      begin
        Result := -1;
        Exit;
      end
      else if Part1 > Part2 then
      begin
        Result := 1;
        Exit;
      end;
    end;
  finally
    V1Parts.Free;
    V2Parts.Free;
  end;
end;

// Switches each pair of characters in the string
// Example: "A1B2C3" becomes "1A2B3C"
// Note: All MSI GUID segments have even lengths, so no need to handle odd-length strings
function ReversePairs(const s: string): string;
var
  i: Integer;
begin
  Result := '';
  i := 1;
  while i <= Length(s) do
  begin
    Result := Result + s[i+1] + s[i];
    i := i + 2;
  end;
end;

// Reverses the order of characters in the string
// Example: "ABCDEF" becomes "FEDCBA"
function ReverseChars(const s: string): string;
var
  i: Integer;
begin
  Result := '';
  for i := Length(s) downto 1 do
    Result := Result + s[i];
end;

// Reverses an MSI PRODUCT_UPGRADE_CODE to standard GUID format and vice versa
// Needed for determining the mapping between MSI PRODUCT_UPGRADE_CODE and MSI Product Codes in the registry
function ReverseMSIGUID(const RevCode: string; AddFormatting: Boolean): string;
var
  RevCodePlain, part1, part2, part3, part4, part5: string;
begin
  // Remove hyphens if present
  // Revcodes stored in '<ROOT>\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UpgradeCodes' do not have hyphens
  RevCodePlain := ReplaceSubstring(RevCode, '-', '');
  // Remove braces if present -- same issue as above
  RevCodePlain := ReplaceSubstring(RevCodePlain, '{', '');
  RevCodePlain := ReplaceSubstring(RevCodePlain, '}', '');

  // Break into segments
  part1 := Copy(RevCodePlain, 1, 8);
  part2 := Copy(RevCodePlain, 9, 4);
  part3 := Copy(RevCodePlain, 13, 4);
  part4 := Copy(RevCodePlain, 17, 4);
  part5 := Copy(RevCodePlain, 21, 12);

  // Reverse each segment in pairs
  part1 := ReverseChars(part1);
  part2 := ReverseChars(part2);
  part3 := ReverseChars(part3);
  part4 := ReversePairs(part4);
  part5 := ReversePairs(part5);

  // Combine into GUID format
  if AddFormatting then
    Result := '{' + part1 + '-' + part2 + '-' + part3 + '-' + part4 + '-' + part5 + '}'
  else
    Result := part1 + part2 + part3 + part4 + part5;
end;

// Returns true if an MSI installation with the given PRODUCT_UPGRADE_CODE exists in the specified RegistryRoot,
// and sets MsiGuid to the corresponding mapping if found. Otherwise, returns false.
function GetInstalledMsiString(RegistryRoot: Integer; UpgradeCode: string; var MsiGuid: string): Boolean;
var
  ValueNames: TArrayOfString;
  i: Integer;
begin
  if RegGetValueNames(RegistryRoot, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UpgradeCodes\' + ReverseMSIGUID(UpgradeCode, False), ValueNames) then
  begin
    for i := 0 to GetArrayLength(ValueNames)-1 do
    begin
      if ValueNames[i] <> '' then  // skip empty or default
      begin
        MsiGuid := ReverseMSIGUID(ValueNames[i], True);
        Result := True;
        Exit;
      end;
    end;
  end;
  Result := False;
end;

#endif