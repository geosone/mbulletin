program mbulletin;

{$mode objfpc}{$H+}

uses Classes, SysUtils, IniFiles, msha256;

const
    Version = '0.1.0';
    Section = 'Bulletin';
    MaxBulletinSize = 1048576;
    DefaultWidth = 80;

procedure Usage;
begin
    Writeln('mbulletin 0.1 - Mystic BBS bulletin generator');
    Writeln('  mbulletin new REQUEST TEXT [--apply]');
    Writeln('  mbulletin --self-test');
end;

procedure SelfTest;
begin
    if SHA256Bytes(BytesOf('')) <> 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' then
        raise Exception.Create('SHA-256 empty-message self-test failed.');
    if SHA256Bytes(BytesOf('abc')) <> 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad' then
        raise Exception.Create('SHA-256 short-message self-test failed.');
    if SHA256Bytes(BytesOf(StringOfChar('a', 1000000))) <>
        'cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0' then
        raise Exception.Create('SHA-256 multiblock self-test failed.');
    Writeln('PASS SHA-256 empty, abc and million-a vectors.');
end;

function ReadFileBytes(const Path: string): TBytes;
var
    Stream: TFileStream;
begin
    Result := nil;
    if not FileExists(Path) then
        raise Exception.Create('Bulletin file not found: ' + Path);
    Stream := TFileStream.Create(Path, fmOpenRead or fmShareDenyNone);
    try
        if Stream.Size > MaxBulletinSize then
            raise Exception.Create('Bulletin file exceeds the supported size: ' + Path);
        SetLength(Result, Stream.Size);
        if Length(Result) > 0 then
            Stream.ReadBuffer(Result[0], Length(Result));
    finally
        Stream.Free;
    end;
end;

procedure WriteFileNew(const Path: string; const Data: TBytes);
var
    Stream: TFileStream;
    Temporary: string;
begin
    Temporary := Path + '.tmp';
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
        raise Exception.Create('Cannot create the new bulletin file: ' + Path);
end;

function TemplateWidth(const Path: string): Integer;
var
    Dot, PrevDot, I, Value, Digit: Integer;
    WidthStr: string;
    Valid: Boolean;
begin
    Result := DefaultWidth;
    Dot := 0;
    PrevDot := 0;
    for I := 1 to Length(Path) do
    begin
        if Path[I] = '.' then
        begin
            if Dot = 0 then
                Dot := I
            else
            begin
                PrevDot := Dot;
                Dot := I;
            end;
        end;
    end;
    if (Dot > 0) and (PrevDot > 0) then
    begin
        WidthStr := Copy(Path, PrevDot + 1, Dot - PrevDot - 1);
        if (Length(WidthStr) > 1) and (WidthStr[1] = 'c') then
        begin
            Valid := True;
            Value := 0;
            for I := 2 to Length(WidthStr) do
            begin
                Digit := Ord(WidthStr[I]) - Ord('0');
                if (Digit < 0) or (Digit > 9) then
                    Valid := False;
                Value := Value * 10 + Digit;
            end;
            if Valid and (Value > 0) then
                Result := Value;
        end;
    end;
end;

procedure Integrate(const Template: TBytes; const Text: TBytes; const Width: Integer; var Data: TBytes);
var
    Out: TBytes;
    TitleEnd, I, J, Start, EndPos, ChunkLen, OutLength, K: Integer;
begin
    TitleEnd := -1;
    for I := 0 to Length(Template) - 1 do
    begin
        if (Template[I] = 13) or (Template[I] = 10) then
        begin
            TitleEnd := I;
            Break;
        end;
    end;
    if TitleEnd < 0 then
        TitleEnd := Length(Template);
    Out := nil;
    SetLength(Out, TitleEnd + 3);
    for I := 0 to TitleEnd do
        Out[I] := Template[I];
    Out[TitleEnd] := 13;
    Out[TitleEnd + 1] := 10;
    OutLength := TitleEnd + 2;
    I := 0;
    while I < Length(Text) do
    begin
        J := I;
        while (J < Length(Text)) and (Text[J] <> 13) and (Text[J] <> 10) do
            Inc(J);
        if J > I then
        begin
            Start := I;
            while Start < J do
            begin
                EndPos := Start + Width - 1;
                if EndPos > J then
                    EndPos := J;
                ChunkLen := EndPos - Start;
                SetLength(Out, OutLength + ChunkLen + 2);
                for K := 0 to ChunkLen - 1 do
                    Out[OutLength + K] := Text[Start + K];
                Out[OutLength + ChunkLen] := 13;
                Out[OutLength + ChunkLen + 1] := 10;
                OutLength := OutLength + ChunkLen + 2;
                Start := EndPos;
            end;
        end
        else
        begin
            SetLength(Out, OutLength + 2);
            Out[OutLength] := 13;
            Out[OutLength + 1] := 10;
            OutLength := OutLength + 2;
        end;
        while (J < Length(Text)) and ((Text[J] = 13) or (Text[J] = 10)) do
            Inc(J);
        I := J;
    end;
    Data := Out;
end;

procedure NewBulletin(const Request: string; const Text: string; Apply: Boolean);
var
    Ini: TIniFile;
    BlankFile, OutFile, Report: string;
    Blank, TextData, Data: TBytes;
    Width: Integer;
begin
    Ini := TIniFile.Create(Request);
    BlankFile := Ini.ReadString(SECTION, 'BlankFile', '');
    OutFile := Ini.ReadString(SECTION, 'OutFile', '');
    Report := Ini.ReadString(SECTION, 'Report', '');
    if BlankFile = '' then
        raise Exception.Create('Bulletin request is missing the ' + SECTION + ' BlankFile key.');
    if OutFile = '' then
        raise Exception.Create('Bulletin request is missing the ' + SECTION + ' OutFile key.');
    if Report = '' then
        raise Exception.Create('Bulletin request is missing the ' + SECTION + ' Report key.');
    TextData := ReadFileBytes(Text);
    if Length(TextData) = 0 then
        raise Exception.Create('Bulletin text is empty: ' + Text);
    Blank := ReadFileBytes(BlankFile);
    if Length(Blank) = 0 then
        raise Exception.Create('Bulletin template is empty: ' + BlankFile);
    Width := TemplateWidth(BlankFile);
    Integrate(Blank, TextData, Width, Data);
    if Length(Data) > MaxBulletinSize then
        raise Exception.Create('Integrated bulletin exceeds the supported size: ' + OutFile);
    if Apply then begin
        if FileExists(OutFile) then
            raise Exception.Create('Bulletin file already exists: ' + OutFile);
        WriteFileNew(OutFile, Data);
        Writeln('mbulletin: created bulletin ', OutFile, ' report=', Report, ' from ', BlankFile, ' text=', Text, ' width=', Width, ' bytes=', Length(Data));
    end
    else
        Writeln('mbulletin: plan template=', BlankFile, ' target=', OutFile, ' report=', Report, ' text=', Text, ' width=', Width, ' bytes=', Length(Data));
end;

var
    Command: string;
begin
    Command := LowerCase(ParamStr(1));
    if ParamCount = 1 then begin
        if Command = '--self-test' then
            SelfTest
        else begin
            Usage;
            ExitCode := 1;
        end;
    end
    else if (LowerCase(ParamStr(1)) = 'new') and ((ParamCount = 3) or ((ParamCount = 4) and (ParamStr(4) = '--apply'))) then begin
        NewBulletin(ParamStr(2), ParamStr(3), (ParamCount = 4) and (ParamStr(4) = '--apply'));
    end
    else begin
        Usage;
        ExitCode := 1;
    end;
end.
