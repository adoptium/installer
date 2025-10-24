#ifndef HELPERS_INCLUDED
#define HELPERS_INCLUDED

[Code]

// Replace OldSubstring with the specified NewSubstring in InputString
function ReplaceSubstring(InputString: string; OldSubstring: string; NewSubstring: string): string;
begin
  // For info on StringChangeEx: https://jrsoftware.org/ishelp/index.php?topic=isxfunc_stringchange
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

#endif