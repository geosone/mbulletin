program mbulletin;

{$mode objfpc}{$H+}

uses Classes, SysUtils, IniFiles, msha256;

const
    Version = '0.2.0';
    IniName = 'mbulletin.ini';
    Prefix = 'bullet';
    BaseWidth = 80;
    MaxBulletins = 999;
    MaxTextSize = 4194304;

type
    TStringArr = array of string;

    TVariant = record
        KeyName: string;         // INI key, e.g. BlankFileC132
        BlankPath: string;       // resolved blank template path
        Directory: string;       // blank directory with trailing delimiter
        Tail: string;            // filename part after '.blank', e.g. '.c132.ans'
        Width: Integer;
        Top, Bottom: Integer;    // report rows, 1-based
        LeftX, RightX: Integer;  // report column window, 1-based (Mystic style)
    end;

    TTheme = record
        Name: string;
        Variants: array of TVariant;
    end;

    TThemeArr = array of TTheme;

    TLines = record
        Values: TStringArr;
        TrailingNewline: Boolean;
    end;

    TPair = record
        B0, B1, CP437: Byte;
        Ascii: string[2];
    end;

{ German umlaut/sharp-s pairs: UTF-8 byte pair, CP437 byte and ASCII fallback. }
const
    Pairs: array[0..6] of TPair = (
        (B0: $C3; B1: $A4; CP437: $84; Ascii: 'ae'),
        (B0: $C3; B1: $84; CP437: $8E; Ascii: 'Ae'),
        (B0: $C3; B1: $B6; CP437: $94; Ascii: 'oe'),
        (B0: $C3; B1: $96; CP437: $99; Ascii: 'Oe'),
        (B0: $C3; B1: $BC; CP437: $81; Ascii: 'ue'),
        (B0: $C3; B1: $9C; CP437: $9A; Ascii: 'Ue'),
        (B0: $C3; B1: $9F; CP437: $E1; Ascii: 'ss'));

    { The same umlauts as bare CP437 bytes, in the same order as Pairs. }
    CP437Umlauts: array[0..6] of Byte = ($84, $8E, $94, $99, $81, $9A, $E1);

    { ... and as bare Latin-1/CP850 bytes, also in the same order. }
    Latin1Umlauts: array[0..6] of Byte = ($E4, $C4, $F6, $D6, $FC, $DC, $DF);

    VariantKeys: array[0..5] of string = ('BlankFile', 'BlankFileC132', 'BlankFileC160', 'BlankFileAsc', 'BlankFileC132Asc', 'BlankFileC160Asc');
    VariantTails: array[0..5] of string = ('.ans', '.c132.ans', '.c160.ans', '.asc', '.c132.asc', '.c160.asc');

    { coordinate keys follow the BlankFile keys: plain Coord1/Coord2 belong to
      the base .ans template, the suffixed ones to the other variants }
    Coord1Keys: array[0..5] of string = ('Coord1', 'Coord1C132', 'Coord1C160', 'Coord1Asc', 'Coord1C132Asc', 'Coord1C160Asc');
    Coord2Keys: array[0..5] of string = ('Coord2', 'Coord2C132', 'Coord2C160', 'Coord2Asc', 'Coord2C132Asc', 'Coord2C160Asc');

{ --------------------------------------------------------------------- }
{ Path helpers                                                          }
{ --------------------------------------------------------------------- }

function ToolIniPath: string;
begin
    Result := IncludeTrailingPathDelimiter(ExtractFilePath(ExpandFileName(
        ParamStr(0)))) + IniName;
end;

function IsAbsolutePath(const P: string): Boolean;
begin
    Result := (Length(P) > 0) and ((P[1] = '/') or (P[1] = '\') or
        ((Length(P) > 2) and (P[2] = ':')));
end;

{ --------------------------------------------------------------------- }
{ Byte helpers                                                          }
{ --------------------------------------------------------------------- }

function ReadFileBytes(const Path: string): TBytes;
var
    Stream: TFileStream;
begin
    Result := nil;
    if not FileExists(Path) then
        raise Exception.Create('File not found: ' + Path);
    Stream := TFileStream.Create(Path, fmOpenRead or fmShareDenyNone);
    try
        if Stream.Size > MaxTextSize then
            raise Exception.Create('File exceeds the supported size: ' + Path);
        SetLength(Result, Stream.Size);
        if Length(Result) > 0 then
            Stream.ReadBuffer(Result[0], Length(Result));
    finally
        Stream.Free;
    end;
end;

procedure WriteFileNew(const Path: string; const Data: TBytes);
var
    Temporary: string;
    Stream: TFileStream;
begin
    Temporary := ExtractFilePath(Path) + '.mbulletin-tmp.' + ExtractFileName(Path);
    if FileExists(Temporary) then
        SysUtils.DeleteFile(Temporary);
    Stream := TFileStream.Create(Temporary, fmCreate or fmShareDenyNone);
    try
        if Length(Data) > 0 then
            Stream.WriteBuffer(Data[0], Length(Data));
    finally
        Stream.Free;
    end;
    if not RenameFile(Temporary, Path) then
        raise Exception.Create('Cannot create the file: ' + Path);
end;

function BytesToString(const Data: TBytes): string;
begin
    SetLength(Result, Length(Data));
    if Length(Data) > 0 then
        Move(Data[0], Result[1], Length(Data));
end;

procedure StripBOM(var Data: TBytes);
var
    I: Integer;
begin
    if Length(Data) >= 3 then
        if (Data[0] = $EF) and (Data[1] = $BB) and (Data[2] = $BF) then begin
            for I := 0 to Length(Data) - 4 do
                Data[I] := Data[I + 3];
            SetLength(Data, Length(Data) - 3);
        end;
end;

{ Replace the German umlaut/sharp-s characters. Detects UTF-8 two-byte pairs
  and bare CP437 bytes. For ANSI output they become CP437 bytes; for ASCII
  output they are spelled out and every other high byte becomes a blank. }
procedure TranslateGerman(var Data: TBytes; Ascii: Boolean);
var
    OutData: TBytes;
    I, K, OutLength, Match, N, Step: Integer;
    B, BN: Byte;
    SingleByte: Boolean;
begin
    SetLength(OutData, Length(Data) + 8);
    OutLength := 0;
    I := 0;
    while I < Length(Data) do begin
        B := Data[I];
        BN := 0;
        if I + 1 < Length(Data) then
            BN := Data[I + 1];
        if B < $80 then begin
            OutData[OutLength] := B;
            Inc(OutLength);
            Inc(I);
        end
        else begin
            K := -1;
            for Match := 0 to High(Pairs) do
                if (Pairs[Match].B0 = B) and (Pairs[Match].B1 = BN) then
                    K := Match;
            SingleByte := K < 0;
            if SingleByte then
                for Match := 0 to High(CP437Umlauts) do
                    if (B = CP437Umlauts[Match]) or (B = Latin1Umlauts[Match]) then
                        K := Match;
            if K >= 0 then begin
                Step := 1;
                if not SingleByte then
                    Step := 2;
                if Ascii then begin
                    if OutLength + Length(Pairs[K].Ascii) > Length(OutData) then
                        SetLength(OutData, Length(OutData) + 8);
                    for N := 1 to Length(Pairs[K].Ascii) do begin
                        OutData[OutLength] := Ord(Pairs[K].Ascii[N]);
                        Inc(OutLength);
                    end;
                end
                else begin
                    OutData[OutLength] := Pairs[K].CP437;
                    Inc(OutLength);
                end;
                Inc(I, Step);
            end
            else if Ascii then begin
                OutData[OutLength] := Ord(' ');
                Inc(OutLength);
                Inc(I);
            end
            else begin
                OutData[OutLength] := B;
                Inc(OutLength);
                Inc(I);
            end;
        end;
    end;
    SetLength(OutData, OutLength);
    Data := OutData;
end;

{ --------------------------------------------------------------------- }
{ Line helpers                                                          }
{ --------------------------------------------------------------------- }

procedure AppendLine(var Values: TStringArr; const Line: string);
begin
    SetLength(Values, Length(Values) + 1);
    Values[High(Values)] := Line;
end;

{ Split byte data into lines. CRLF and LF are accepted, CR is dropped from
  the line ends and TrailingNewline records a final line break. }
function SplitLines(const Data: TBytes): TLines;
var
    Text: string;
    I, Start, Len: Integer;
begin
    Result.Values := nil;
    Result.TrailingNewline := False;
    Text := BytesToString(Data);
    Start := 1;
    for I := 1 to Length(Text) do
        if Text[I] = #10 then begin
            Len := I - Start;
            if (Len > 0) and (Text[Start + Len - 1] = #13) then
                Dec(Len);
            AppendLine(Result.Values, Copy(Text, Start, Len));
            Start := I + 1;
            if Start > Length(Text) then
                Result.TrailingNewline := True;
        end;
    if Start <= Length(Text) then begin
        Len := Length(Text) - Start + 1;
        if Text[Length(Text)] = #13 then
            Dec(Len);
        AppendLine(Result.Values, Copy(Text, Start, Len));
    end;
end;

function JoinLines(const Lines: TLines): TBytes;
var
    I, OutLength, LineLength: Integer;
    Data: TBytes;
begin
    SetLength(Data, 0);
    OutLength := 0;
    for I := 0 to Length(Lines.Values) - 1 do begin
        LineLength := Length(Lines.Values[I]);
        SetLength(Data, OutLength + LineLength + 2);
        if LineLength > 0 then
            Move(Lines.Values[I][1], Data[OutLength], LineLength);
        Data[OutLength + LineLength] := 13;
        Data[OutLength + LineLength + 1] := 10;
        OutLength := OutLength + LineLength + 2;
    end;
    if not Lines.TrailingNewline then begin
        if OutLength >= 2 then
            SetLength(Data, OutLength - 2)
        else
            SetLength(Data, 0);
    end;
    Result := Data;
end;

{ Hard-wrap one line into chunks of at most Width characters. }
function WrapLine(const Line: string; Width: Integer): TStringArr;
var
    Start, Chunk: Integer;
begin
    Result := nil;
    if Width < 1 then
        raise Exception.Create('Text area width is too small.');
    if Line = '' then begin
        AppendLine(Result, '');
        Exit;
    end;
    Start := 1;
    while Start <= Length(Line) do begin
        Chunk := Width;
        if Start + Chunk - 1 > Length(Line) then
            Chunk := Length(Line) - Start + 1;
        AppendLine(Result, Copy(Line, Start, Chunk));
        Start := Start + Chunk;
    end;
end;

{ Remove ANSI escape sequences, pipe codes |XX and control characters. }
function StripDisplayCodes(const Line: string): string;var
    I: Integer;
    C: Char;
begin
    Result := '';
    I := 1;
    while I <= Length(Line) do begin
        C := Line[I];
        if C = #27 then begin
            Inc(I);
            if (I <= Length(Line)) and (Line[I] = '[') then begin
                Inc(I);
                while (I <= Length(Line)) and not (Line[I] in ['A'..'Z', 'a'..'z', '@', '\']) do
                    Inc(I);
                if I <= Length(Line) then
                    Inc(I);
            end
            else if I <= Length(Line) then
                Inc(I);
        end
        else if (C = '|') and (I + 2 <= Length(Line)) and
                (Line[I + 1] in ['0'..'9', 'A'..'F']) and
                (Line[I + 2] in ['0'..'9', 'A'..'Z']) then
            Inc(I, 3)
        else if Ord(C) in [1..31] then
            Inc(I)
        else begin
            Result := Result + C;
            Inc(I);
        end;
    end;
end;

function TrimBlanks(const S: string): string;
var
    A, B: Integer;
begin
    A := 1;
    B := Length(S);
    while (A <= B) and (S[A] = ' ') do
        Inc(A);
    while (B >= A) and (S[B] = ' ') do
        Dec(B);
    Result := Copy(S, A, B - A + 1);
end;

{ Shifting template lines down breaks absolute row addressing: when a line
  starts with an ESC[r;...H/f/d cursor position the row value is incremented
  by Delta so the rest of the template keeps its place. Lines without a
  leading cursor position just scroll along. }
function ShiftCursorPosition(const Line: string; Delta: Integer): string;
var
    I, J, Row, Terminated: Integer;
    K: Char;
begin
    Result := Line;
    if (Delta = 0) or (Length(Line) < 4) then
        Exit;
    if (Line[1] <> #27) or (Line[2] <> '[') then
        Exit;
    I := 3;
    while (I <= Length(Line)) and (Line[I] in ['0'..'9']) do
        Inc(I);
    if I = 3 then
        Exit;
    Row := StrToIntDef(Copy(Line, 3, I - 3), -1);
    if Row < 0 then
        Exit;
    { the row must be the first parameter of a position sequence (H, f or d) }
    J := I;
    if (J <= Length(Line)) and (Line[J] = ';') then begin
        while (J <= Length(Line)) and
              (Line[J] in ['0'..'9', ';', '.', ':', '?', ' ', '"']) do
            Inc(J);
    end;
    if J > Length(Line) then
        Exit;
    K := Line[J];
    if not (K in ['H', 'f', 'd']) then
        Exit;
    Terminated := J;
    Result := #27 + '[' + IntToStr(Row + Delta) + Copy(Line, I, Terminated - I + 1) +
        Copy(Line, Terminated + 1, MaxInt);
end;

{ --------------------------------------------------------------------- }
{ Blank-template naming                                                 }
{ --------------------------------------------------------------------- }

{ The blank file name must contain '.blank'; everything after it (the tail,
  e.g. '.c132.ans') is appended to 'bulletN' to build the output name. }
function BlankTail(const BlankName: string): string;
var
    P: Integer;
begin
    P := Pos('.blank', LowerCase(BlankName));
    if P = 0 then
        raise Exception.Create('Blank template name must contain ".blank": ' + BlankName);
    Result := Copy(BlankName, P + 6, MaxInt);
    if (Result = '') or (Result[1] <> '.') then
        raise Exception.Create('Blank template name has no extension: ' + BlankName);
end;

function TailWidth(const Tail: string): Integer;
begin
    if Copy(Tail, 1, 6) = '.c132.' then
        Result := 132
    else if Copy(Tail, 1, 6) = '.c160.' then
        Result := 160
    else
        Result := BaseWidth;
end;

{ --------------------------------------------------------------------- }
{ Existing bulletins                                                    }
{ --------------------------------------------------------------------- }

function IsPlainFile(var SearchRec: TSearchRec): Boolean;
begin
    Result := (SearchRec.Attr and faDirectory) = 0;
end;

function NumberExists(const Directory: string; Number: Integer): Boolean;
var
    SearchRec: TSearchRec;
    Rc: Integer;
begin
    Result := False;
    Rc := FindFirst(IncludeTrailingPathDelimiter(Directory) + Prefix +
        IntToStr(Number) + '.*', faAnyFile, SearchRec);
    try
        while Rc = 0 do begin
            if IsPlainFile(SearchRec) then begin
                Result := True;
                Break;
            end;
            Rc := FindNext(SearchRec);
        end;
    finally
        FindClose(SearchRec);
    end;
end;

function ThemeNumberPresent(const Theme: TTheme; Number: Integer): Boolean;
var
    I: Integer;
begin
    Result := False;
    for I := 0 to High(Theme.Variants) do
        if NumberExists(Theme.Variants[I].Directory, Number) then begin
            Result := True;
            Break;
        end;
end;

function ThemeMaxNumber(const Theme: TTheme): Integer;
var
    N: Integer;
begin
    N := 1;
    while (N <= MaxBulletins) and ThemeNumberPresent(Theme, N) do
        Inc(N);
    Result := N - 1;
end;

function BulletinFileName(const Directory: string; Number: Integer; const Tail: string): string;
begin
    Result := IncludeTrailingPathDelimiter(Directory) + Prefix + IntToStr(Number) + Tail;
end;

{ First report-area line of an existing bulletin, display codes stripped. }
function BulletinTitle(const Theme: TTheme; Number: Integer): string;
var
    I, J: Integer;
    Path: string;
    Data: TBytes;
    Lines: TLines;
    Line: string;
begin
    Result := '';
    for I := 0 to High(Theme.Variants) do begin
        Path := BulletinFileName(Theme.Variants[I].Directory, Number, Theme.Variants[I].Tail);
        if FileExists(Path) then begin
            Data := ReadFileBytes(Path);
            Lines := SplitLines(Data);
            for J := Theme.Variants[I].Top to Theme.Variants[I].Bottom do
                if J <= Length(Lines.Values) then begin
                    Line := TrimBlanks(StripDisplayCodes(Lines.Values[J - 1]));
                    if Line <> '' then begin
                        Result := Line;
                        Break;
                    end;
                end;
            Break;
        end;
    end;
end;

{ --------------------------------------------------------------------- }
{ INI loading                                                           }
{ --------------------------------------------------------------------- }

{ Parse a Mystic-style "X,Y" (or "X,Y,A", the attribute is ignored) pair that
  names one report corner. X is the column, Y is the row. }
function ParseCoordPair(const Section, Key, Value: string; out X, Y: Integer): Boolean;
var
    P, Comma, Second: Integer;
    First, Rest: string;
begin
    Result := False;
    Comma := Pos(',', Value);
    if Comma < 2 then
        Exit;
    First := Copy(Value, 1, Comma - 1);
    Rest := Copy(Value, Comma + 1, MaxInt);
    Comma := Pos(',', Rest);
    if Comma > 0 then
        Second := StrToIntDef(TrimBlanks(Copy(Rest, 1, Comma - 1)), -1)
    else
        Second := StrToIntDef(TrimBlanks(Rest), -1);
    P := StrToIntDef(TrimBlanks(First), -1);
    if (P < 1) or (Second < 1) then
        Exit;
    X := P;
    Y := Second;
    Result := True;
end;

function LoadThemes(const IniPath: string): TThemeArr;
var
    Ini: TIniFile;
    Sections: TStringList;
    Theme: TTheme;
    Section, BlankPath, BlankName, Tail, CoordValue: string;
    I, K, E: Integer;
    Coord1X, Coord1Y, Coord2X, Coord2Y: Integer;
begin
    Result := nil;
    if not FileExists(IniPath) then
        raise Exception.Create('INI file not found: ' + IniPath +
            ' (place mbulletin.ini next to mbulletin)');
    Ini := TIniFile.Create(IniPath);
    Sections := TStringList.Create;
    try
        Ini.ReadSections(Sections);
        for I := 0 to Sections.Count - 1 do begin
            Section := Sections[I];
            Theme.Name := Section;
            SetLength(Theme.Variants, Length(VariantKeys));
            for K := 0 to Length(VariantKeys) - 1 do begin
                BlankPath := Ini.ReadString(Section, VariantKeys[K], '');
                { Older INIs define four variants. Wide ASCII is an optional
                  pair; once configured both variants must be complete. }
                if (K = 4) and (BlankPath = '') then begin
                    if Ini.ReadString(Section, VariantKeys[5], '') <> '' then
                        raise Exception.Create('Wide ASCII requires both 132 and 160 templates.');
                    SetLength(Theme.Variants, 4);
                    Break;
                end;
                if BlankPath = '' then
                    raise Exception.Create('Theme "' + Section + '" is missing the ' +
                        VariantKeys[K] + ' key.');
                if not IsAbsolutePath(BlankPath) then
                    BlankPath := ExtractFilePath(IniPath) + BlankPath;
                BlankPath := ExpandFileName(BlankPath);
                BlankName := ExtractFileName(BlankPath);
                Tail := BlankTail(BlankName);
                if Tail <> VariantTails[K] then
                    raise Exception.Create('Theme "' + Section + '": ' + VariantKeys[K] +
                        ' must point to a *' + VariantTails[K] + ' template, but got "' +
                        BlankName + '" (tail ' + Tail + ').');
                CoordValue := Ini.ReadString(Section, Coord1Keys[K], '');
                if not ParseCoordPair(Section, Coord1Keys[K], CoordValue,
                        Coord1X, Coord1Y) then
                    raise Exception.Create('Theme "' + Section +
                        '" needs a Mystic-style ' + Coord1Keys[K] + ' = X,Y report corner.');
                CoordValue := Ini.ReadString(Section, Coord2Keys[K], '');
                if not ParseCoordPair(Section, Coord2Keys[K], CoordValue,
                        Coord2X, Coord2Y) then
                    raise Exception.Create('Theme "' + Section +
                        '" needs a Mystic-style ' + Coord2Keys[K] + ' = X,Y report corner.');
                Theme.Variants[K].KeyName := VariantKeys[K];
                Theme.Variants[K].BlankPath := BlankPath;
                Theme.Variants[K].Directory := IncludeTrailingPathDelimiter(
                    ExtractFilePath(BlankPath));
                Theme.Variants[K].Tail := Tail;
                Theme.Variants[K].Width := TailWidth(Tail);
                { Coord1 is the top/left corner, Coord2 the bottom/right corner }
                Theme.Variants[K].Top := Coord1Y;
                Theme.Variants[K].Bottom := Coord2Y;
                Theme.Variants[K].LeftX := Coord1X;
                Theme.Variants[K].RightX := Coord2X;
                if (Theme.Variants[K].Top < 1) or (Theme.Variants[K].Bottom <
                        Theme.Variants[K].Top) then
                    raise Exception.Create('Theme "' + Section + '", ' +
                        Coord1Keys[K] + '/' + Coord2Keys[K] +
                        ': the report rows must be >= 1 and Coord1 Y <= Coord2 Y.');
                if (Theme.Variants[K].LeftX < 1) or (Theme.Variants[K].RightX <
                        Theme.Variants[K].LeftX) then
                    raise Exception.Create('Theme "' + Section + '", ' +
                        Coord1Keys[K] + '/' + Coord2Keys[K] +
                        ': the report columns must be >= 1 and Coord1 X <= Coord2 X.');
                if Theme.Variants[K].RightX > Theme.Variants[K].Width then
                    raise Exception.Create('Theme "' + Section + '": variant ' +
                        Theme.Variants[K].Tail + ' (width ' +
                        IntToStr(Theme.Variants[K].Width) + ') cannot host the ' +
                        Coord1Keys[K] + '..' + Coord2Keys[K] + ' column window ' +
                        IntToStr(Theme.Variants[K].LeftX) + '..' +
                        IntToStr(Theme.Variants[K].RightX) + '.');
                if not FileExists(BlankPath) then
                    raise Exception.Create('Blank template not found: ' + BlankPath);
            end;
            for K := 1 to High(Theme.Variants) do
                for E := 0 to K - 1 do
                    if (Theme.Variants[E].Directory = Theme.Variants[K].Directory) and
                       (Theme.Variants[E].Tail = Theme.Variants[K].Tail) then
                        raise Exception.Create('Theme "' + Section +
                            '" defines the same variant "' + Theme.Variants[K].Tail +
                            '" in two keys.');
            SetLength(Result, Length(Result) + 1);
            Result[High(Result)] := Theme;
        end;
        if Length(Result) = 0 then
            raise Exception.Create('No theme sections found in ' + IniPath + '.');
    finally
        Sections.Free;
        Ini.Free;
    end;
end;

{ --------------------------------------------------------------------- }
{ new / list / delete                                                   }
{ --------------------------------------------------------------------- }

procedure CheckThemesInSync(const Themes: TThemeArr);
var
    I, N, First, Count: Integer;
begin
    { bulletins must form the strict 1..count run in every theme }
    First := -1;
    for I := 0 to High(Themes) do begin
        Count := ThemeMaxNumber(Themes[I]);
        N := Count + 1;
        while N <= MaxBulletins do begin
            if ThemeNumberPresent(Themes[I], N) then
                raise Exception.Create('Theme "' + Themes[I].Name +
                    '" has extra bulletin files above ' + IntToStr(Count) +
                    ' (bulletin ' + IntToStr(N) + '); the themes are out of ' +
                    'sync. Bulletins must form the 1..' + IntToStr(Count) +
                    ' run; fix this manually first.');
            Inc(N);
        end;
        if First < 0 then
            First := Count;
        if Count <> First then
            raise Exception.Create('Themes are out of sync: "' + Themes[0].Name +
                '" has ' + IntToStr(First) + ' bulletins, "' + Themes[I].Name +
                '" has ' + IntToStr(Count) + '. Fix this manually first.');
    end;
end;

procedure ListBulletins;
var
    Themes: TThemeArr;
    Theme: TTheme;
    I, N, Max: Integer;
    Title: string;
    IniPath: string;
begin
    IniPath := ToolIniPath;
    Themes := LoadThemes(IniPath);
    for I := 0 to High(Themes) do begin
        Theme := Themes[I];
        Max := ThemeMaxNumber(Theme);
        Writeln(Theme.Name + ':');
        if Max = 0 then
            Writeln('  (no bulletins)')
        else
            for N := 1 to Max do begin
                Title := BulletinTitle(Theme, N);
                if Title = '' then
                    Title := '(no title)';
                Writeln('  ' + IntToStr(N) + ': ' + Title);
            end;
    end;
end;

procedure NewBulletin(const TextPath: string);
var
    Themes: TThemeArr;
    Theme: TTheme;
    I, K, N, NextNumber, Height, ChunkIndex: Integer;
    TextData, VariantText, BlankData, OutData: TBytes;
    BlankLines, TextLines, VariantLines: TLines;
    Wrapped, ReportLines: TStringArr;
    OutLines: TLines;
begin
    Themes := LoadThemes(ToolIniPath);
    CheckThemesInSync(Themes);
    NextNumber := ThemeMaxNumber(Themes[0]) + 1;
    if NextNumber > MaxBulletins then
        raise Exception.Create('Too many bulletins (limit ' + IntToStr(MaxBulletins) + ').');

    TextData := ReadFileBytes(TextPath);
    StripBOM(TextData);
    TextLines := SplitLines(TextData);
    if Length(TextLines.Values) = 0 then
        raise Exception.Create('The text file is empty: ' + TextPath);
    if TrimBlanks(TextLines.Values[0]) = '' then
        raise Exception.Create('The first line of the text file is empty and cannot be used as the title: ' + TextPath);

    Writeln('mbulletin: creating bulletin number ' + IntToStr(NextNumber) +
        ' for ' + IntToStr(Length(Themes)) + ' theme(s)');

    for I := 0 to High(Themes) do begin
        Theme := Themes[I];
        for K := 0 to High(Theme.Variants) do begin
            Height := Theme.Variants[K].Bottom - Theme.Variants[K].Top + 1;
            if Height < 1 then
                raise Exception.Create('Theme "' + Theme.Name + '": empty report area.');
            BlankData := ReadFileBytes(Theme.Variants[K].BlankPath);
            BlankLines := SplitLines(BlankData);
            if Length(BlankLines.Values) < Theme.Variants[K].Bottom then
                raise Exception.Create('Theme "' + Theme.Name + '", ' +
                    Theme.Variants[K].Tail + ': blank template is shorter than ' +
                    'Bottom (' + IntToStr(Theme.Variants[K].Bottom) + ' lines): ' +
                    Theme.Variants[K].BlankPath);
            VariantText := Copy(TextData, 0, Length(TextData));
            TranslateGerman(VariantText, Copy(Theme.Variants[K].Tail, Length(Theme.Variants[K].Tail) - 3, 4) = '.asc');
            VariantLines := SplitLines(VariantText);

            { fit every text line (title first) into the Coord1..Coord2 report
              window; if the text needs more rows than the window offers the
              bulletin grows and the remaining template lines shift down (they
              scroll along in Mystic, absolute cursor rows are renumbered) }
            ReportLines := nil;
            for ChunkIndex := 0 to High(VariantLines.Values) do begin
                Wrapped := WrapLine(VariantLines.Values[ChunkIndex],
                    Theme.Variants[K].RightX - Theme.Variants[K].LeftX + 1);
                for N := 0 to High(Wrapped) do
                    AppendLine(ReportLines,
                        StringOfChar(' ', Theme.Variants[K].LeftX - 1) + Wrapped[N]);
            end;
            while Length(ReportLines) < Height do
                AppendLine(ReportLines, StringOfChar(' ', Theme.Variants[K].LeftX - 1));

            { keep everything of the template outside the report area }
            Wrapped := nil;
            for N := 1 to Theme.Variants[K].Top - 1 do
                AppendLine(Wrapped, BlankLines.Values[N - 1]);
            for N := 0 to High(ReportLines) do
                AppendLine(Wrapped, ReportLines[N]);
            for N := Theme.Variants[K].Bottom + 1 to Length(BlankLines.Values) do begin
                if Length(ReportLines) > Height then
                    AppendLine(Wrapped, ShiftCursorPosition(BlankLines.Values[N - 1],
                        Length(ReportLines) - Height))
                else
                    AppendLine(Wrapped, BlankLines.Values[N - 1]);
            end;

            OutLines.Values := Wrapped;
            OutLines.TrailingNewline := BlankLines.TrailingNewline;
            OutData := JoinLines(OutLines);
            WriteFileNew(BulletinFileName(Theme.Variants[K].Directory, NextNumber,
                Theme.Variants[K].Tail), OutData);
            Writeln('mbulletin:   ' + Theme.Name + ' -> ' + Prefix + IntToStr(NextNumber) +
                Theme.Variants[K].Tail + ' (width ' +
                IntToStr(Theme.Variants[K].Width) + ')');
        end;
    end;
    Writeln('mbulletin: bulletin ' + IntToStr(NextNumber) + ' created in every theme.');
end;

procedure DeleteBulletins;
var
    Themes: TThemeArr;
    Theme: TTheme;
    I, K, J, N, Max, Rc: Integer;
    Input, Answer: string;
    SearchRec: TSearchRec;
    OldName, NewName: string;
begin
    Themes := LoadThemes(ToolIniPath);
    CheckThemesInSync(Themes);
    Max := ThemeMaxNumber(Themes[0]);
    if Max = 0 then begin
        Writeln('mbulletin: there are no bulletins to delete.');
        Exit;
    end;

    Writeln('mbulletin: existing bulletins:');
    for I := 0 to High(Themes) do begin
        Theme := Themes[I];
        for N := 1 to Max do
            Writeln('  ' + Theme.Name + ' ' + IntToStr(N) + ': ' + BulletinTitle(Theme, N));
    end;

    Writeln('mbulletin: number of the bulletin to delete:');
    ReadLn(Input);
    Input := TrimBlanks(Input);
    if (Input = '') or (not TryStrToInt(Input, N)) then
        raise Exception.Create('Not a bulletin number: "' + Input + '".');
    if (N < 1) or (N > Max) then
        raise Exception.Create('There is no bulletin ' + IntToStr(N) +
            ' (existing: 1..' + IntToStr(Max) + ').');

    Writeln('mbulletin: delete bulletin ' + IntToStr(N) +
        ' and renumber the following bulletins in every theme? (J/N)');
    ReadLn(Answer);
    Answer := LowerCase(TrimBlanks(Answer));
    if (Answer <> 'j') and (Answer <> 'ja') and (Answer <> 'y') and (Answer <> 'yes') then begin
        Writeln('mbulletin: cancelled.');
        Exit;
    end;

    for I := 0 to High(Themes) do begin
        Theme := Themes[I];
        { delete every variant of bulletin N }
        for K := 0 to High(Theme.Variants) do begin
            Rc := FindFirst(IncludeTrailingPathDelimiter(Theme.Variants[K].Directory) +
                Prefix + IntToStr(N) + '.*', faAnyFile, SearchRec);
            try
                while Rc = 0 do begin
                    if IsPlainFile(SearchRec) then
                        SysUtils.DeleteFile(IncludeTrailingPathDelimiter(
                            Theme.Variants[K].Directory) + SearchRec.Name);
                    Rc := FindNext(SearchRec);
                end;
            finally
                FindClose(SearchRec);
            end;
        end;
        { renumber everything above N; rename keeps the mtime }
        for J := N to Max - 1 do begin
            for K := 0 to High(Theme.Variants) do begin
                OldName := BulletinFileName(Theme.Variants[K].Directory, J + 1,
                    Theme.Variants[K].Tail);
                NewName := BulletinFileName(Theme.Variants[K].Directory, J,
                    Theme.Variants[K].Tail);
                if FileExists(OldName) and (not RenameFile(OldName, NewName)) then
                    raise Exception.Create('Cannot renumber ' + OldName +
                        ' to ' + NewName + '.');
            end;
        end;
        Writeln('mbulletin:   theme ' + Theme.Name +
            ' shortened; bulletins renumbered.');
    end;
    Writeln('mbulletin: bulletin ' + IntToStr(N) + ' deleted.');
end;

{ --------------------------------------------------------------------- }
{ self-test and usage                                                   }
{ --------------------------------------------------------------------- }

procedure SelfTest;
var
    Lines: TLines;
    Wrapped: TStringArr;
    Data: TBytes;
begin
    if SHA256Bytes(BytesOf('')) <> 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' then
        raise Exception.Create('SHA-256 empty-message self-test failed.');
    if SHA256Bytes(BytesOf('abc')) <> 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad' then
        raise Exception.Create('SHA-256 short-message self-test failed.');
    Writeln('PASS SHA-256 empty and abc vectors.');

    if BlankTail('bullet.blank.c132.ans') <> '.c132.ans' then
        raise Exception.Create('BlankTail self-test failed.');
    if BlankTail('my.blank.ans') <> '.ans' then
        raise Exception.Create('BlankTail base self-test failed.');
    if TailWidth('.c132.ans') <> 132 then
        raise Exception.Create('TailWidth self-test failed.');
    if TailWidth('.asc') <> BaseWidth then
        raise Exception.Create('TailWidth base self-test failed.');
    Writeln('PASS blank naming arithmetic.');

    Data := BytesOf('a' + #13 + #10 + 'b' + #10);
    Lines := SplitLines(Data);
    if (Length(Lines.Values) <> 2) or (Lines.Values[0] <> 'a') or
        (Lines.Values[1] <> 'b') or (not Lines.TrailingNewline) then
        raise Exception.Create('SplitLines self-test failed.');
    Data := BytesOf('a' + #13 + #10 + 'b');
    Lines := SplitLines(Data);
    if (Length(Lines.Values) <> 2) or Lines.TrailingNewline then
        raise Exception.Create('SplitLines trailing self-test failed.');
    Data := BytesOf('one');
    Lines := SplitLines(Data);
    if (Length(Lines.Values) <> 1) or (Lines.Values[0] <> 'one') then
        raise Exception.Create('SplitLines single self-test failed.');
    Writeln('PASS line splitting.');

    Wrapped := WrapLine('123456', 4);
    if (Length(Wrapped) <> 2) or (Wrapped[0] <> '1234') or (Wrapped[1] <> '56') then
        raise Exception.Create('WrapLine self-test failed.');
    Wrapped := WrapLine('', 4);
    if (Length(Wrapped) <> 1) or (Wrapped[0] <> '') then
        raise Exception.Create('WrapLine empty self-test failed.');
    Writeln('PASS line wrapping.');

    Data := BytesOf(StringOfChar(#132, 2));  { bare CP437 umlauts }
    TranslateGerman(Data, True);
    if BytesToString(Data) <> 'aeae' then
        raise Exception.Create('ASCII umlaut self-test failed.');
    Data := BytesOf(StringOfChar(#228, 1));  { bare Latin-1 umlaut }
    TranslateGerman(Data, False);
    if (Length(Data) <> 1) or (Data[0] <> $84) then
        raise Exception.Create('CP437 umlaut self-test failed.');
    Data := BytesOf(#$C3 + #$A4);            { UTF-8 umlaut pair }
    TranslateGerman(Data, False);
    if (Length(Data) <> 1) or (Data[0] <> $84) then
        raise Exception.Create('UTF-8 umlaut self-test failed.');
    Writeln('PASS German byte translation.');

    if StripDisplayCodes(#27 + '[1;1H|16|CL|01Hel' + 'lo') <> 'Hello' then
        raise Exception.Create('StripDisplayCodes self-test failed.');
    if StripDisplayCodes('A' + #7 + 'B') <> 'AB' then
        raise Exception.Create('StripDisplayCodes control self-test failed.');
    Writeln('PASS display-code stripping.');
end;

procedure Usage;
begin
    Writeln('mbulletin ' + Version + ' - Mystic BBS bulletin report generator');
    Writeln;
    Writeln('Usage:');
    Writeln('  mbulletin new TEXTFILE      create the next bulletin in every theme');
    Writeln('  mbulletin list              show bulletins and their titles');
    Writeln('  mbulletin delete            delete a bulletin and renumber the rest');
    Writeln('  mbulletin --self-test       run the built-in checks');
    Writeln;
    Writeln('mbulletin reads its theme sections from mbulletin.ini in the tool directory.');
    Writeln('Each theme section lists its blank templates and the Mystic-style');
    Writeln('Coord1/Coord2 report corners per template size; see the README for a');
end;

begin
    try
        if (ParamCount = 1) and (LowerCase(ParamStr(1)) = '--self-test') then
            SelfTest
        else if (ParamCount = 1) and (LowerCase(ParamStr(1)) = 'list') then
            ListBulletins
        else if (ParamCount = 1) and (LowerCase(ParamStr(1)) = 'delete') then
            DeleteBulletins
        else if (ParamCount = 2) and (LowerCase(ParamStr(1)) = 'new') then
            NewBulletin(ParamStr(2))
        else begin
            Usage;
            ExitCode := 1;
        end;
    except
        on E: Exception do begin
            Writeln(stderr, 'mbulletin: ERROR: ', E.Message);
            ExitCode := 1;
        end;
    end;
end.
