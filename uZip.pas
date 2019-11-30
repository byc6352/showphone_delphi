unit uZip;

interface
(*//
标题:压缩和解压目录
说明:利用ZLib单元;不处理空目录
设计:byc
日期:200409-06
支持:byc6352@sina.com
//*)

///////Begin Source
uses ZLib, FileCtrl,sysutils,classes;

const cBufferSize = $4096;
procedure compressstream(var instream:Tmemorystream);
procedure CompressSteam(inStream,outStream:TMemoryStream);overload;
function FileCompression(mFileName: TFileName; mStream: TStream): Integer;
function DirectoryCompression(mDirectory, mFileName: TFileName): Integer;
function DirectoryDecompression(mDirectory, mFileName: TFileName): Integer;
function FileDecompression(mFileName: TFileName; mStream: TStream): Integer;

implementation

procedure CompressSteam(inStream,outStream:TMemoryStream);overload;
var
  zStream:Tcompressionstream;
  size:integer;
begin
try
  if instream.Size=0 then exit;
  size:=instream.size;
  outStream.clear;
  outStream.WriteBuffer(size,sizeof(size));
  zstream:=Tcompressionstream.Create(clmax,outStream); // clDefault is a LOT faster than clMax
  inStream.SaveToStream(zstream);
  zstream.Free;
  outstream.Position:=0;
except
end;
end;
procedure compressstream(var instream:Tmemorystream);
var zstream:Tcompressionstream;
    outstream:Tmemorystream;
    size:integer;
begin
     if instream.Size=0 then exit;
     size:=instream.size;
     outstream:=Tmemorystream.create;
     zstream:=Tcompressionstream.Create(clmax,outstream);
     try
     instream.SaveToStream(zstream);
     zstream.free;
     outstream.Position:=0;
     instream.clear;
     instream.WriteBuffer(size,sizeof(size));
     instream.CopyFrom(outstream,0);
     instream.Position:=0;
     finally
     outstream.free;
     end;
end;
function FileCompression(mFileName: TFileName; mStream: TStream): Integer;
var
  vFileStream: TFileStream;
  vBuffer: array[0..cBufferSize]of char;
  vPosition: Integer;
  I: Integer;
begin
  Result := -1;
  if not FileExists(mFileName) then Exit;
  if not Assigned(mStream) then Exit;
  vPosition := mStream.Position;
  vFileStream := TFileStream.Create(mFileName, fmOpenRead or fmShareDenyNone);
  with TCompressionStream.Create(clMax, mStream) do try
    for I := 1 to vFileStream.Size div cBufferSize do begin
      vFileStream.Read(vBuffer, cBufferSize);
      Write(vBuffer, cBufferSize);
    end;
    I := vFileStream.Size mod cBufferSize;
    if I > 0 then begin
      vFileStream.Read(vBuffer, I);
      Write(vBuffer, I);
    end;
  finally
    Free;
    vFileStream.Free;
  end;
  Result := mStream.Size - vPosition; //增量
end; { FileCompression }

function FileDecompression(mFileName: TFileName; mStream: TStream): Integer;
var
  vFileStream: TFileStream;
  vBuffer: array[0..cBufferSize]of char;
  I: Integer;
begin
  Result := -1;
  if not Assigned(mStream) then Exit;
  ForceDirectories(ExtractFilePath(mFileName)); //创建目录
  
  vFileStream := TFileStream.Create(mFileName, fmCreate or fmShareDenyWrite);

  with TDecompressionStream.Create(mStream) do try
    repeat
      I := Read(vBuffer, cBufferSize);
      vFileStream.Write(vBuffer, I);
    until I = 0;
    Result := vFileStream.Size;
  finally
    Free;
    vFileStream.Free;
  end;
end; { FileDecompression }

function StrLeft(const mStr: string; mDelimiter: string): string;
begin
  Result := Copy(mStr, 1, Pos(mDelimiter, mStr) - 1);
end; { StrLeft }

function StrRight(const mStr: string; mDelimiter: string): string;
begin
  if Pos(mDelimiter, mStr) > 0 then
    Result := Copy(mStr, Pos(mDelimiter, mStr) + Length(mDelimiter), MaxInt)
  else Result := '';
end; { StrRight }

type
  TFileHead = packed record
    rIdent: string[3]; //标识
    rVersion: Byte; //版本
  end;

const
  cIdent: string[3] = 'zsf';
  cVersion = $01;
  cErrorIdent = -1;
  cErrorVersion = -2;

function DirectoryCompression(mDirectory, mFileName: TFileName): Integer;
var
  vFileInfo: TStrings;
  vFileInfoSize: Integer;
  vFileInfoBuffer: Pansichar;
  vFileHead: TFileHead;

  vMemoryStream: TMemoryStream;
  vFileStream: TFileStream;

  procedure pAppendFile(mSubFile: TFileName);
  begin
    vFileInfo.Append(Format('%s|%d',
      [StringReplace(mSubFile, mDirectory + '\', '', [rfReplaceAll, rfIgnoreCase]),
        FileCompression(mSubFile, vMemoryStream)]));
    Inc(Result);
  end; { pAppendFile }

  procedure pSearchFile(mPath: TFileName);
  var
    vSearchRec: TSearchRec;
    K: Integer;
  begin
    K := FindFirst(mPath + '\*.*', faAnyFile, vSearchRec);
    while K = 0 do begin
      if (vSearchRec.Attr and faDirectory > 0) and
        (Pos(vSearchRec.Name, '..') = 0) then
        pSearchFile(mPath + '\' + vSearchRec.Name)
      else if Pos(vSearchRec.Name, '..') = 0 then
        pAppendFile(mPath + '\' + vSearchRec.Name);
      K := FindNext(vSearchRec);
    end;
    FindClose(vSearchRec);
  end; { pSearchFile }
begin
  Result := 0;
  if not DirectoryExists(mDirectory) then Exit;
  vFileInfo := TStringList.Create;
  vMemoryStream := TMemoryStream.Create;
  mDirectory := ExcludeTrailingPathDelimiter(mDirectory);

  vFileStream := TFileStream.Create(mFileName, fmCreate or fmShareDenyWrite);
  try
    pSearchFile(mDirectory);
    vFileInfoBuffer := Pansichar(ansiString(vFileInfo.GetText));
    vFileInfoSize := StrLen(vFileInfoBuffer);

    { DONE -oZswang -c添加 : 写入头文件信息 }
    vFileHead.rIdent := cIdent;
    vFileHead.rVersion := cVersion;
    vFileStream.Write(vFileHead, SizeOf(vFileHead));

    vFileStream.Write(vFileInfoSize, SizeOf(vFileInfoSize));
    vFileStream.Write(vFileInfoBuffer^, vFileInfoSize);
    vMemoryStream.Position := 0;
    vFileStream.CopyFrom(vMemoryStream, vMemoryStream.Size);
  finally
    vFileInfo.Free;
    vMemoryStream.Free;
    vFileStream.Free;
  end;
end; { DirectoryCompression }

function DirectoryDecompression(mDirectory, mFileName: TFileName): Integer;
var
  vFileInfo: TStrings;
  vFileInfoSize: Integer;
  vFileHead: TFileHead;

  vMemoryStream: TMemoryStream;
  vFileStream: TFileStream;
  I: Integer;
begin
  Result := 0;
  if not FileExists(mFileName) then Exit;
  vFileInfo := TStringList.Create;
  vMemoryStream := TMemoryStream.Create;
  mDirectory := ExcludeTrailingPathDelimiter(mDirectory);
  vFileStream := TFileStream.Create(mFileName, fmOpenRead or fmShareDenyNone);
  try
    if vFileStream.Size < SizeOf(vFileHead) then Exit;
    { DONE -oZswang -c添加 : 读取头文件信息 }
    vFileStream.Read(vFileHead, SizeOf(vFileHead));
    if vFileHead.rIdent <> cIdent then Result := cErrorIdent;
    if vFileHead.rVersion <> cVersion then Result := cErrorVersion;
    if Result <> 0 then Exit;

    vFileStream.Read(vFileInfoSize, SizeOf(vFileInfoSize));
    vMemoryStream.CopyFrom(vFileStream, vFileInfoSize);
    vMemoryStream.Position := 0;
    vFileInfo.LoadFromStream(vMemoryStream);
    //form1.Memo1.Lines:=vFileInfo;
    for I := 0 to vFileInfo.Count - 1 do begin
      vMemoryStream.Clear;
      vMemoryStream.CopyFrom(vFileStream,
        StrToIntDef(StrRight(vFileInfo[I], '|'), 0));
      vMemoryStream.Position := 0;
      FileDecompression(mDirectory + '\' + StrLeft(vFileInfo[I], '|'),
        vMemoryStream);
    end;
    Result := vFileInfo.Count;
  finally
    vFileInfo.Free;
    vMemoryStream.Free;
    vFileStream.Free;
  end;
end; { DirectoryDeompression }
///////End Source
end.

 