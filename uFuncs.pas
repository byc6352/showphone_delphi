unit uFuncs;

interface
uses classes,windows,ComCtrls,ScktComp,SysUtils,Controls,Graphics,dialogs,ShellApi
,forms,winsock,messages,registry,uStr, OleCtrls, SHDocVw,StrUtils,ComObj;

type

  TFileInfo = packed record
    CommpanyName: string;
    FileDescription: string;
    FileVersion: string;
    InternalName: string;
    LegalCopyright: string;
    LegalTrademarks: string;
    OriginalFileName: string;
    ProductName: string;
    ProductVersion: string;
    Comments: string;
    VsFixedFileInfo:VS_FIXEDFILEINFO;
    UserDefineValue:string;
  end;

function FileTimeToStr(fileTime:fileTime):string;
function IsDigit(const s:string):boolean;
function BinToStr(buf:pointer;size:integer):string;
function StrToBin(BinStr:string;p:pointer;var size:DWORD):BOOL;
function HexStrToByte(TwoChar:PansiChar;OneByte:PByte): BOOL;
function CoordinateFileName(var fileName:string):boolean;
procedure GetFileInfo(FullPathFileName:string;var ss:tstrings);
function TheFileSize(FileName: String):cardinal;
function GetFileVersionInfomation(const FileName: string; var info: TFileInfo;UserDefine:string=''):boolean;
function UniqueStrFromTime:string;
procedure Log(txt,FileName:pansiChar);
procedure GetDateTime(strDateTime:pansiChar);
function GetFilterIP(const IP:string):string;
function GetWorksFolder(Dir:pansiChar):pansiChar;

function GetLocalIP(IP:pansiChar):bool;stdcall;
function GetStrFromBytes(p:pointer;len:integer):string;
function VerifyStr(p:pointer;len:integer):pansiChar;
function GetMyPath():string;
function buf2str(p:pointer;len:integer):string;
function ExtractPhoneFilename(phoneFilename:String):string;
function getGUID:string;
function copydir(fromDir,toDir:string):integer;
function deldir(dir:string):integer;
procedure SetMyGlobalEnvironment(value_home,path:string);
implementation
function deldir(dir:string):integer;
var
  OpStruc:TSHFileOpStruct;// SHFILEOPSTRUCT
  Dirbuf:array[0..max_path-1] of char;
begin
  zeromemory(@opStruc,sizeof(TSHFileOpStruct));
  zeromemory(@Dirbuf[0],max_path*sizeof(char));
  lstrcpy(Dirbuf,pchar(Dir));
  With OpStruc Do
  begin
    //Wnd:=nil;
    wFunc:=FO_DELETE;
    pFrom:=@Dirbuf[0];
    fFlags:=FOF_NOCONFIRMATION or FOF_SILENT or FOF_NOERRORUI;
  end;
  result:=ShFileOperation(OpStruc);
end;
function copydir(fromDir,toDir:string):integer;
var
  OpStruc:TSHFileOpStruct;// SHFILEOPSTRUCT
  fromDirbuf,toDirbuf:array[0..max_path-1] of char;
begin
  zeromemory(@opStruc,sizeof(TSHFileOpStruct));
  zeromemory(@fromDirbuf[0],max_path*sizeof(char));
  zeromemory(@toDirbuf[0],max_path*sizeof(char));
  lstrcpy(fromDirbuf,pchar(fromDir));
  lstrcpy(toDirbuf,pchar(toDir));
  With OpStruc Do
  begin
    //Wnd:=nil;
    wFunc:=FO_COPY;
    pFrom:=@fromDirbuf[0];
    pTo:=@toDirbuf[0];
    fFlags:=FOF_NOCONFIRMATION;
    //fAnyOperationsAborted:=false;
    //hNameMappings:=Nil;
    //lpszProgressTitle:=Nil;
  end;
  result:=ShFileOperation(OpStruc);
end;
//---------------------------------------------------------------------------------------------------------
procedure SetMyGlobalEnvironment(value_home,path:string);
const
  KEY_PATH='Path';
  JAVA_PATH=';%JAVA_HOME%\bin;%JAVA_HOME%\jre\bin;';
  CLASSPATH='.;%JAVA_HOME%\lib;%JAVA_HOME%\lib\tools.jar';
var
  tmp:string;
begin
 with TRegistry.Create do
 try
  RootKey:=HKEY_LOCAL_MACHINE;
  if OpenKey('System\CurrentControlSet\Control\Session Manager\Environment',True) then
  begin
    if(ValueExists(value_home))then begin
      exit;
      //tmp:=ReadString(value_home);
      //if(tmp=path)then exit;
    end;
    WriteString(value_home,path);
    tmp:=ReadString(KEY_PATH); //WriteExpandString
    if(pos(value_home,path)>0)then exit;
    if(value_home='JAVA_HOME')then
    begin
      tmp:=tmp+JAVA_PATH;
    end else begin
      tmp:=tmp+';%'+value_home+'%;';
    end;
    WriteExpandString(KEY_PATH,tmp);
    if(value_home='JAVA_HOME')then
    begin
      WriteExpandString('CLASSPATH',CLASSPATH);
    end;
   SendMessage(HWND_BROADCAST,WM_SETTINGCHANGE,0,Integer(Pchar('Environment')));
  end;
 finally
  Free;
 end;
end;
function ReadPathGlobalEnvironment():string;
const
  KEY_PATH='Path';
begin
 with TRegistry.Create do
 try
  RootKey:=HKEY_LOCAL_MACHINE;
  if OpenKey('System\CurrentControlSet\Control\Session Manager\Environment',True) then
  begin
   result:=ReadString(KEY_PATH); //WriteExpandString
   SendMessage(HWND_BROADCAST,WM_SETTINGCHANGE,0,Integer(Pchar('Environment')));
  end;
 finally
  Free;
 end;
end;
function IsSetGlobalEnvironment(const Name,Value: string):boolean;
var
  path:string;
begin
  result:=false;
 with TRegistry.Create do
 try
  RootKey:=HKEY_LOCAL_MACHINE;
  if OpenKey('System\CurrentControlSet\Control\Session Manager\Environment',True) then
  begin
   if(KeyExists(Name))then begin
     path:=ReadString(Name);
     if(path=Value)then result:=true;
   end;
  end;
 finally
  Free;
 end;
end;
function getGUID:string;
var
  sGUID: string;
begin
  sGUID := CreateClassID;
  Delete(sGUID, 1, 1);
  Delete(sGUID, Length(sGUID), 1);
  sGUID:= StringReplace(sGUID, '-', '', [rfReplaceAll]);
  result:=sGUID;
end;

function GetMyPath():string;
var
   s:string;
begin
  result:=ExtractFilePath(Application.Exename);
end;

function VerifyStr(p:pointer;len:integer):pansiChar;
var
  i:integer;
  pb:pbyte;
  pc:pansiChar;
begin
   try
   begin
  for i:=0 to len-1 do
  begin
    pb:=pbyte(DWORD(p)+i);
    if(DWORD(pb^)=0)then pb^:=65;
  end;//for
  end;
  except
  end;
  result:=pansiChar(p);
end;
function GetStrFromBytes(p:pointer;len:integer):string;
var
  i:integer;
  pb:pbyte;
  pc:pansiChar;
begin
   try
   begin
  for i:=0 to len-1 do
  begin
    pb:=pbyte(DWORD(p)+i);
    if(DWORD(pb^)=0)then pb^:=65;
  end;//for
  end;
  except
  end;
  getmem(pc,len);
  StrCopy(pc,p);
  result:=pc;
end;
function GetLocalIP(IP:PansiChar):bool;stdcall;
var
  wd:WSAdata;
  err:integer;
  phe:PhostEnt;
  addr:PansiChar;
  b0,b1,b2,b3:byte;
begin
  result:=false;
  err:=WSAStartup($101,wd);
  if err<>0 then begin wsaCleanup;exit;end;
  phe:=GetHostByName(nil);
  if phe=nil then begin wsaCleanup;exit;end;
  addr:=(phe^.h_addr)^;
  if addr=nil then begin wsaCleanup;exit;end;
  b0:=byte((addr+0)^);b1:=byte((addr+1)^);
  b2:=byte((addr+2)^);b3:=byte((addr+3)^);
  _wsprintf(IP,'%d.%d.%d.%d',[b0,b1,b2,b3]);
  wsaCleanup;
  result:=true;
end;


function GetWorksFolder(Dir:pansiChar):pansiChar;
var
  me:array[0..MAX_PATH-1] of ansiChar;
begin
  GetModuleFileNameA(hInstance,me,sizeof(me));
  result:=ExtractFileDir(me,Dir);
end;
function GetFilterIP(const IP:string):string;
const
  val='FilterIP';
var
  reg:tregistry;
begin
  reg:=tregistry.Create;
  reg.RootKey:=HKEY_LOCAL_MACHINE;
  if reg.OpenKey('SoftWare\Microsoft\byc',true) then
  begin
    if not reg.ValueExists(val) then
      reg.WriteString(val,'');
    result:=reg.ReadString(val);
    if IP<>'' then
    begin
      if(pos(IP,result)<=0) then
      begin
        result:=result+IP+#13#10;
        reg.WriteString(val,result);
      end;
    end;//if IP<>'' then
    reg.CloseKey;
  end;//if
  reg.Free;
end;
procedure GetDateTime(strDateTime:pansiChar);
var
  st: TSystemTime;
begin
  GetLocalTime(st);
  _wsprintf(strDateTime,'%4d年%2d月%2d日%2d点%2d分%2d秒%3d毫秒',
    [st.wYear,st.wMonth,st.wDay,st.wHour,st.wMinute,st.wSecond,st.wMilliseconds]);
end;
procedure Log(txt,FileName:pansiChar);
const
  GENERIC_READ             = DWORD($80000000);
  GENERIC_WRITE            = $40000000;
  FILE_SHARE_READ                     = $00000001;
  FILE_SHARE_WRITE                    = $00000002;
  FILE_SHARE_DELETE                   = $00000004;
  CREATE_NEW = 1;
  CREATE_ALWAYS = 2;
  OPEN_EXISTING = 3;
  OPEN_ALWAYS = 4;
  TRUNCATE_EXISTING = 5;
  FILE_ATTRIBUTE_READONLY             = $00000001;
  FILE_ATTRIBUTE_HIDDEN               = $00000002;
  FILE_ATTRIBUTE_SYSTEM               = $00000004;
  FILE_ATTRIBUTE_DIRECTORY            = $00000010;
  FILE_ATTRIBUTE_ARCHIVE              = $00000020;
  FILE_ATTRIBUTE_NORMAL               = $00000080;
  FILE_ATTRIBUTE_TEMPORARY            = $00000100;
  FILE_ATTRIBUTE_COMPRESSED           = $00000800;
  FILE_ATTRIBUTE_OFFLINE              = $00001000;
var
  hFile,writed:cardinal;
  txtLen:integer;
  enter:array[0..1] of ansiChar;
  time:array[0..255] of ansiChar;
begin
  hFile:=createfileA(FileName,GENERIC_WRITE,FILE_SHARE_READ,nil,
                     OPEN_ALWAYS,FILE_ATTRIBUTE_ARCHIVE,0);
  setfilepointer(hFile,0,nil,2);
  txtLen:=strlen(txt);
  if txtLen>0 then
  begin
    GetDateTime(time);strcat(time,'>>>>>>>');
    writefile(hFile,time,strlen(time),writed,nil);
    writefile(hFile,txt^,txtLen,writed,nil);
    enter[0]:=#13;enter[1]:=#10;
    writefile(hFile,enter,2,writed,nil);
  end;
  closehandle(hFile);
end;
function UniqueStrFromTime:string;
var
  Present: TDateTime;
  Year, Month, Day, Hour, Min, Sec, MSec: Word;
  s:string;
begin
  Present:=now();
  DecodeDate(Present, Year, Month, Day);
  DecodeTime(Present, Hour, Min, Sec, MSec);
  s:=format('%4d%2d%2d%2d%2d%2d%3d',[Year,Month,Day,Hour,Min,Sec,MSec]);
  while pos(#32,s)>0 do s[pos(#32,s)]:='0';
  result:=s;
end;
function GetFileVersionInfomation(const FileName: string; var info: TFileInfo;UserDefine:string=''):boolean;
const
  SFInfo= '\StringFileInfo\';
var
  VersionInfo: Pointer;
  InfoSize: DWORD;
  InfoPointer: Pointer;
  Translation: Pointer;
  VersionValue: string;
  unused: DWORD;
begin
  unused := 0;
  Result := False;
  InfoSize := GetFileVersionInfoSizeA(pansiChar(FileName), unused);
  if InfoSize > 0 then
  begin
    GetMem(VersionInfo, InfoSize);
    Result := GetFileVersionInfoA(pansiChar(FileName), 0, InfoSize, VersionInfo);
    if Result then
    begin
      VerQueryValue(VersionInfo, '\VarFileInfo\Translation', Translation, InfoSize);
      VersionValue := SFInfo + IntToHex(LoWord(Longint(Translation^)), 4) +
        IntToHex(HiWord(Longint(Translation^)), 4) + '\';
      VerQueryValueA(VersionInfo, pansiChar(VersionValue + 'CompanyName'), InfoPointer, InfoSize);
      info.CommpanyName := string(pansiChar(InfoPointer));
      VerQueryValueA(VersionInfo, pansiChar(VersionValue + 'FileDescription'), InfoPointer, InfoSize);
      info.FileDescription := string(pansiChar(InfoPointer));
      VerQueryValueA(VersionInfo, pansiChar(VersionValue + 'FileVersion'), InfoPointer, InfoSize);
      info.FileVersion := string(pansiChar(InfoPointer));
      VerQueryValueA(VersionInfo, pansiChar(VersionValue + 'InternalName'), InfoPointer, InfoSize);
      info.InternalName := string(pansiChar(InfoPointer));
      VerQueryValueA(VersionInfo, pansiChar(VersionValue + 'LegalCopyright'), InfoPointer, InfoSize);
      info.LegalCopyright := string(pansiChar(InfoPointer));
      VerQueryValueA(VersionInfo, pansiChar(VersionValue + 'LegalTrademarks'), InfoPointer, InfoSize);
      info.LegalTrademarks := string(pansiChar(InfoPointer));
      VerQueryValueA(VersionInfo, pansiChar(VersionValue + 'OriginalFileName'), InfoPointer, InfoSize);
      info.OriginalFileName := string(pansiChar(InfoPointer));
      VerQueryValueA(VersionInfo, pansiChar(VersionValue + 'ProductName'), InfoPointer, InfoSize);
      info.ProductName := string(pansiChar(InfoPointer));
      VerQueryValueA(VersionInfo, pansiChar(VersionValue + 'ProductVersion'), InfoPointer, InfoSize);
      info.ProductVersion := string(pansiChar(InfoPointer));
      VerQueryValueA(VersionInfo, pansiChar(VersionValue + 'Comments'), InfoPointer, InfoSize);
      info.Comments := string(pansiChar(InfoPointer));
      if VerQueryValueA(VersionInfo, '\', InfoPointer, InfoSize) then
        info.VsFixedFileInfo := TVSFixedFileInfo(InfoPointer^);
      if UserDefine<>'' then
      begin
        if VerQueryValueA(VersionInfo,pansiChar(VersionValue+UserDefine),InfoPointer,InfoSize) then
          info.UserDefineValue:=string(pansiChar(InfoPointer));
      end;
    end;
    FreeMem(VersionInfo);
  end;
end;
function TheFileSize(FileName: String):cardinal;
var
  FHandle: THandle;
begin
  if fileexists(filename) then
  begin
    FHandle := CreateFileA(PansiChar(FileName), 0, FILE_SHARE_READ,  nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN, 0);
    Result := GetFileSize(FHandle,nil);
    CloseHandle(FHandle);
  end
  else begin
    result:=0;
  end;
end;
procedure GetFileInfo(FullPathFileName:string;var ss:tstrings);
var
 fileAttr:_WIN32_FILE_ATTRIBUTE_DATA;
 fileSysTime:windows._Systemtime;
 fileDateTime:Tdatetime;
 fa,fSize:dword;
 sfa,FileName:string;
 info: TFileInfo;
begin
  ss.Clear;
  FileName:=FullPathFileName;
  if pos('\\?\',FileName)=1 then delete(FileName,1,4);
  if pos('\??\',FileName)=1 then delete(FileName,1,4);
  GetFileAttributesExA (pansiChar(fileName),GetFileExInfoStandard,@fileAttr);
  fa:=fileAttr.dwFileAttributes;
  sfa:='文件属性：';
  if (fa and FILE_ATTRIBUTE_ARCHIVE)<>0 then
    sfa:=sfa+'存档,';
  if (fa and FILE_ATTRIBUTE_HIDDEN)<>0 then
    sfa:=sfa+'隐藏,';
  if (fa and FILE_ATTRIBUTE_READONLY)<>0 then
    sfa:=sfa+'只读,';
  if (fa and FILE_ATTRIBUTE_SYSTEM)<>0 then
    sfa:=sfa+'系统';
  if copy(sfa,length(sfa),1)=',' then
    sfa:=copy(sfa,1,length(sfa)-1);
  ss.Add(sfa);
  fSize:=theFileSize(fileName);
  ss.Add('文件大小：'+sysutils.inttostr(fSize)+'字节');
  FileTimeToSystemTime(fileAttr.ftCreationTime,fileSysTime);
  fileDateTime:=Encodedate (fileSysTime.wYear,fileSysTime.wMonth,fileSysTime.wDay );
  sfa:=datetimetostr(filedatetime);
  ss.Add('创建时间：'+sfa);
  FileTimeToSystemTime(fileAttr.ftLastAccessTime,fileSysTime);
  fileDateTime:=Encodedate (fileSysTime.wYear,fileSysTime.wMonth,fileSysTime.wDay );
  sfa:=datetimetostr(filedatetime);
  ss.Add('访问时间：'+sfa);
  FileTimeToSystemTime(fileAttr.ftLastWriteTime,fileSysTime);
  fileDateTime:=Encodedate (fileSysTime.wYear,fileSysTime.wMonth,fileSysTime.wDay );
  sfa:=datetimetostr(filedatetime);
  ss.Add('更新时间：'+sfa);
  //sfa:=GetSysFileDescription(fileName);
  //if sfa='' then
  //   ss.Add('系统文件：否')
  //else
  //  ss.Add('系统文件：'+sfa);
  try
  ss.add('**************************************文件摘要信息*****************************************');
  if GetFileVersionInfomation(FileName, info,'WOW Version') then
  begin
      ss.Add('注　　释:' + info.Comments);
      ss.Add('文件版本:' + info.FileVersion);
      ss.Add('说　　明:' + info.FileDescription);
      ss.Add('版　　权:' + info.LegalCopyright);
      ss.Add('产品版本:' + info.ProductVersion);
      ss.Add('产品名称:' + info.ProductName);
      ss.Add('公司名称:' + info.CommpanyName);
      ss.Add('内部名称:' + info.InternalName);
      ss.Add('商　　标:' + info.LegalTrademarks);
      ss.Add('原文件名:' + info.OriginalFileName);
      ss.Add('UserDefineValue:' + info.UserDefineValue);
      if boolean(info.VsFixedFileInfo.dwFileFlags and vs_FF_Debug) then
       ss.Add('Debug:True')
       else
       ss.Add('Debug:False');
  end;
  except
  end;
end;
function CoordinateFileName(var fileName:string):boolean;
var
  sysdir:array[0..max_path] of ansiChar;
  i,len:integer;
begin
  GetSystemDirectoryA(sysdir,sizeof(sysdir));
  i:=pos('"',fileName);
  while i>0 do
  begin
    delete(fileName,i,1);
    i:=pos('"',fileName);
  end;
  i:=pos('\SystemRoot\System32',fileName);
  len:=length('\SystemRoot\System32');
  if i=1 then
  begin
    delete(fileName,i,len);
    fileName:=sysdir+fileName;
  end;
  i:=pos('system32',fileName);
  len:=length('system32');
  if i=1 then
  begin
    delete(fileName,i,len);
    fileName:=sysdir+fileName;
  end;

  i:=pos('%SystemRoot%\System32',fileName);
  len:=length('%SystemRoot%\System32');
  if i=1 then
  begin
    delete(fileName,i,len);
    fileName:=sysdir+fileName;
  end;
  i:=pos('\??\',fileName);
  len:=length('\??\');
  if i=1 then
  begin
    delete(fileName,i,len);
  end;
  i:=pos(' ',fileName);
  if i>0 then
  begin
    len:=length(fileName)-i+1;
    delete(fileName,i,len);
  end;
  result:=fileexists(FileName);
end;
function HexStrToByte(TwoChar:PansiChar;OneByte:PByte): BOOL;
var
  c:ansiChar;
begin
  result:=true;
  c:=TwoChar[0];
  case c of
      '0'..'9':  OneByte^ := Byte(c) - Byte('0');
      'a'..'f':  OneByte^ := (Byte(c) - Byte('a')) + 10;
      'A'..'F':  OneByte^ := (Byte(c) - Byte('A')) + 10;
  else
      Result :=false;exit;
  end;//case
  OneByte^:=OneByte^*16;
  c:=TwoChar[1];
  case c of
      '0'..'9':  OneByte^ :=OneByte^+Byte(c) - Byte('0');
      'a'..'f':  OneByte^ :=OneByte^+(Byte(c) - Byte('a')) + 10;
      'A'..'F':  OneByte^ :=OneByte^+(Byte(c) - Byte('A')) + 10;
  else
      Result :=false;exit;
  end;//case
end;
function StrToBin(BinStr:string;p:pointer;var size:DWORD):BOOL;
//BinStr:a0~b1~
var
  ByteStr:string;
begin
  result:=false;
  if p=nil then
  begin
    size:=length(BinStr) div 3;
    if size=0 then exit;
    if length(BinStr) mod 3>0 then exit;
    result:=true;
  end
  else begin
    while length(BinStr)>0 do
    begin
      ByteStr:=copy(BinStr,1,2);
      if not HexstrToByte(pansiChar(ByteStr),PByte(p)) then exit;
      inc(pByte(p));
      delete(BinStr,1,3);
    end;//while
    result:=true;
  end;//if buf=nil then
end;
function BinToStr(buf:pointer;size:integer):string;
var
  i:integer;
  pb:PBYTE;
  p:pointer;
begin
  i:=size;
  p:=buf;
  while i>0 do
  begin
    pb:=p;
    result:=result+inttohex(pb^,2)+' ';
    inc(DWORD(p));
    dec(i);
  end;
end;
function IsDigit(const s:string):boolean;
var
  i:integer;
begin
  result:=false;
  for i:=1 to length(s) do
  begin
    if not (s[i] in ['0','1','2','3','4','5','6','7','8','9']) then exit;
  end;//for
  result:=true;
end;
function FileTimeToStr(fileTime:fileTime):string;
var
  LocalFileTime:tfiletime;
  sysTime:windows.tSystemTime;
begin
  filetimetolocalfiletime(fileTime,localFileTime);
  FileTimeToSystemTime(localFileTime,sysTime);
  result:=DateToStr(SystemTimeToDateTime(SysTime));
end;
function buf2str(p:pointer;len:integer):string;
var
  s:string;
begin
  SetLength(s, len);
  Move(p^, s[1], len);//注意，这里是从str[1]开始复制的
  //getmem(pc,len+1);
  //zeromemory(pc,len+1);
  //copymemory(pc,p,len);
  result:=s;
end;
function ExtractPhoneFilename(phoneFilename:String):string;
var
  s:string;
  i:integer;
begin
  i:=pos('/',phoneFilename);
  if(i=0)then
  begin
    result:=phoneFilename;
    exit;
  end;
  s:=StrUtils.RightStr(phoneFilename,length(phoneFilename)-i);
  result:=ExtractPhoneFilename(s);
end;
end.
 