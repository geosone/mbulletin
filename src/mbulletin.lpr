program mbulletin;

{$mode objfpc}{$H+}

uses Classes, SysUtils, msha256;

const
    Version = '0.1.0';
    MaxBulletinSize = 1048576;

procedure Usage;
begin
    Writeln('mbulletin 0.1 - Mystic BBS bulletin generator');
    Writeln('  mbulletin new BLANKFILE OUTFILE [--apply]');
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
        raise Exception.Create('Bulletin blank not found: ' + Path);
    Stream := TFileStream.Create(Path, fmOpenRead or fmShareDenyNone);
    try
        if Stream.Size > MaxBulletinSize then
            raise Exception.Create('Bulletin blank exceeds the supported size: ' + Path);
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

procedure NewBulletin(const BlankFile: string; const OutFile: string; Apply: Boolean);
var
    Blank: TBytes;
begin
    if BlankFile = '' then
        raise Exception.Create('Usage: mbulletin new BLANKFILE OUTFILE [--apply].');
    Blank := ReadFileBytes(BlankFile);
    if Length(Blank) = 0 then
        raise Exception.Create('Bulletin blank is empty: ' + BlankFile);
    if Apply then begin
        if FileExists(OutFile) then
            raise Exception.Create('Bulletin file already exists: ' + OutFile);
        WriteFileNew(OutFile, Blank);
        Writeln('mbulletin: created bulletin ', OutFile, ' from ', BlankFile, ' bytes=', Length(Blank));
    end
    else
        Writeln('mbulletin: plan blank=', BlankFile, ' target=', OutFile, ' bytes=', Length(Blank));
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

