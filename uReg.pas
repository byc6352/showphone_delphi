unit uReg;

interface
uses
  windows,uStr;
type
  //Char=ansiChar;
  //PChar=PansiChar;
   TRegOp=(REnumKey,RCreateKey,RRenameKey,RDelKey,RCreateVal,RrenameVal,RDelVal,RGetVal,REnumFree);
  pRegOpInfo=^stRegOpInfo;
  stRegOpInfo=record
    op:TRegOp;
    rk:HKEY;
    key:array[0..max_path-1] of ansiChar;
    val:array[0..max_path-1] of ansiChar;
    typ:DWORD;
    dat:pointer;
    siz:dword;
  end;
//*******************************reg**********************************************
function RegDelVal(rk:HKEY;key,val:PansiChar):bool;
function RegGetInt(rk:HKEY;key,val:PansiChar):integer;
function RegSetInt(rk:HKEY;key,val:PansiChar;i:Integer):bool;
function RegGetStr(rk:HKEY;key,val,dat:PansiChar):pansiChar;
function RegGetString(rk:HKEY;key,val:PansiChar):string;
function RegValExist(rk:HKEY;key,val:PansiChar):BOOL;
function OpReg(var ro:stRegOpInfo):bool;
function GetRegKeys(rk:HKEY;key:pansiChar;pData:pointer;var size:cardinal):bool;
function DelRegKey(rk:HKEY;key:pansiChar):BOOL;
function ReNameRegVal(rk:HKEY;key,oldVal,newVal:PansiChar):BOOL;
function RenameRegKey(rk:HKEY;oldKey,newkey:PansiChar):BOOL;
function RegSetStr(rk:HKEY;key,val:PansiChar;data:PansiChar):bool;
implementation
//*********************************************Reg********************************
function RegSetStr(rk:HKEY;key,val:PansiChar;data:PansiChar):bool;
var
  ro:stregopinfo;
begin
  ro.op:=RCreateVal;
  ro.rk:=rk;
  strcopy(ro.key,key);
  strcopy(ro.val,val);
  ro.typ:=REG_SZ;
  ro.dat:=data;
  ro.siz:=strlen(data);
  result:=opreg(ro);
end;
function RegDelVal(rk:HKEY;key,val:PansiChar):bool;
var
  ro:stregopinfo;
begin
  ro.op:=RDelVal;
  ro.rk:=rk;
  strcopy(ro.key,key);
  strcopy(ro.val,val);
  result:=opreg(ro);
end;
function RegSetInt(rk:HKEY;key,val:PansiChar;i:Integer):bool;
var
  ro:stregopinfo;
begin
  ro.op:=RCreateVal;
  ro.rk:=rk;
  strcopy(ro.key,key);
  strcopy(ro.val,val);
  ro.typ:=REG_DWORD;
  ro.dat:=@i;
  ro.siz:=sizeof(i);
  result:=opreg(ro);
end;
function RegGetInt(rk:HKEY;key,val:PansiChar):integer;
var
  ro:stregopinfo;
begin
  ro.op:=RGetVal;
  ro.rk:=rk;
  strcopy(ro.key,key);
  strcopy(ro.val,val);
  ro.typ:=REG_DWORD;
  ro.dat:=@result;
  ro.siz:=sizeof(integer);
  if not opreg(ro) then result:=-1;
end;
function RegGetStr(rk:HKEY;key,val,dat:PansiChar):PansiChar;
var
  ro:stregopinfo;
  buf:array[0..1023] of ansiChar;
begin
  buf:='';result:=dat;
  ro.op:=RGetVal;
  ro.rk:=rk;
  strcopy(ro.key,key);
  strcopy(ro.val,val);
  ro.typ:=REG_SZ;
  ro.dat:=@buf;
  ro.siz:=sizeof(buf);
  if opreg(ro) then
    strcopy(dat,buf)
  else
   result:=nil;
end;
function RegGetString(rk:HKEY;key,val:PansiChar):string;
var
  ro:stregopinfo;
  data:array[0..1023] of ansiChar;
begin
  result:='';
  zeromemory(@data[0],1024);
  ro.op:=RGetVal;
  ro.rk:=rk;
  strcopy(ro.key,key);
  strcopy(ro.val,val);
  ro.typ:=REG_SZ;
  ro.dat:=@data[0];
  ro.siz:=sizeof(data);
  if opreg(ro) then
    result:=data;
end;
function RegValExist(rk:HKEY;key,val:PansiChar):BOOL;
var
  op:stRegOpInfo;
  Data:array[0..1023] of ansiChar;
begin
  op.op:=RGetVal;
  op.rk:=rk;
  strcopy(op.key,key);
  strcopy(op.val,val);
  op.typ:=REG_SZ;
  op.dat:=@Data[0];
  op.siz:=sizeof(Data);
  result:=opReg(op);
end;
function GetRegyh(rk:HKEY;key:PansiChar):string;
//06-08-15
var
  err,i:integer;
  hk:hkey;
  cSubKeys,cbMaxSubKeyLen,cVals,cbMaxValNameLen,cbMaxValLen:DWORD;
  cbSubKeyLen,cbValNameLen,cbValLen:DWORD;
  pb:pointer;
  valueName:array[0..max_path-1] of ansiChar;
  subkeysLen,dwType:DWORD;
begin
  result:='';hk:=0;pb:=nil;cbMaxValNameLen:=0;cbMaxValLen:=0;
try
  err:=RegOpenKeyExA(rk,key,0,KEY_ALL_ACCESS,hk);
  if err<>ERROR_SUCCESS then exit;
  err:=RegQueryInfoKey(hk,nil,nil,nil,@cSubKeys,@cbMaxSubKeyLen,nil,@cVals,@cbMaxValNameLen,@cbMaxValLen,nil,nil);
  if err<>ERROR_SUCCESS then exit;
  if cbMaxValNameLen>0 then inc(cbMaxValNameLen);

  if cVals>0 then
  begin
    pb:=virtualAlloc(nil,cbMaxValLen,MEM_COMMIT,PAGE_READWRITE);
    if pb=nil then exit;
    for i:=0 to cVals-1 do
    begin
      zeromemory(@ValueName,sizeof(valueName));
      zeromemory(pb,cbMaxValLen);
      cbValNameLen:=cbMaxValNameLen;
      cbValLen:=cbMaxValLen;
      RegEnumValueA(hk,i,ValueName,cbValNameLen,nil,@dwType,pb,@cbValLen);
      if err<>ERROR_SUCCESS then exit;
      if dwType=REG_SZ then
      begin
        //if lstrcmpi(Valuename,'PCName')=0 then continue;
        //if lstrcmpi(Valuename,'user')=0 then continue;
        result:=result+PansiChar(pb)+';';
      end;
    end;//for
  end;//if cVals>0 then
finally
  if hk<>0 then RegCloseKey(hk);
  if (pb<>nil)and(cbMaxValLen>0) then
  begin
    virtualFree(pb,cbMaxValLen,MEM_DECOMMIT);
    virtualFree(pb,0,MEM_RELEASE);
  end;
end;
end;
function GetRegKeys(rk:HKEY;key:PansiChar;pData:pointer;var size:cardinal):bool;
label 1;
var
  err,i:integer;
  hk:hkey;
  cSubKeys,cbMaxSubKeyLen,cVals,cbMaxValNameLen,cbMaxValLen:DWORD;
  cbSubKeyLen,cbValNameLen,cbValLen:DWORD;
  p:pointer;
  pd:PDWORD;
  pc:PansiChar;
  pb:pointer;
  valueName:array[0..max_path-1] of ansiChar;
  subkeysLen,dwType:DWORD;
  //数据值结构：1、值名称长度；2、数据类型；3、数据长度；4、值名称；5、数据
  //数据流结构：1、子键数目；2、最大子键长度；3值数目；4、最大值名长度；5、最大数据长度；
  //6、子键列表大小；7、子键列表；8、值长度；9、值类型；10、数据长度；11、值名称；12、数据；
begin
  result:=false;
  P:=pData;
  err:=RegOpenKeyExA(rk,key,0,KEY_ALL_ACCESS,hk);
  if err<>ERROR_SUCCESS then exit;
  err:=RegQueryInfoKey(hk,nil,nil,nil,@cSubKeys,@cbMaxSubKeyLen,nil,@cVals,@cbMaxValNameLen,@cbMaxValLen,nil,nil);
  if cbMaxSubKeyLen>0 then inc(cbMaxSubKeyLen);
  if cbMaxValNameLen>0 then inc(cbMaxValNameLen);
  if err<>ERROR_SUCCESS then goto 1;
  if p=nil then
  begin
    size:=cSubKeys*cbMaxSubKeyLen+cVals*cbMaxValNameLen+cVals*cbMaxValLen;
    goto 1;
  end;//p=nil
  //子键数目:
  pd:=PDWORD(p);pd^:=cSubKeys;p:=pointer(DWORD(p)+sizeof(DWORD));
  //最大子键长度:
  pd:=PDWORD(p);pd^:=cbMaxSubKeyLen;p:=pointer(DWORD(p)+sizeof(DWORD));
  //值数目:
  pd:=PDWORD(p);pd^:=cVals;p:=pointer(DWORD(p)+sizeof(DWORD));
  //最大值名长度:
  pd:=PDWORD(p);pd^:=cbMaxValNameLen;p:=pointer(DWORD(p)+sizeof(DWORD));
  //最大数据长度:
  pd:=PDWORD(p);pd^:=cbMaxValLen;p:=pointer(DWORD(p)+sizeof(DWORD));
  //子键列表大小：
  subKeysLen:=0;
  pd:=PDWORD(p);pd^:=subKeysLen;p:=pointer(DWORD(p)+sizeof(DWORD));
  //子键列表：
  if cSubkeys>0 then
  begin
    for i:=0 to cSubKeys-1 do
    begin
      pc:=PansiChar(p);
      cbSubKeyLen:=cbMaxSubKeyLen;
      RegEnumKeyExA(hk,i,pc,cbSubKeyLen,nil,nil,nil,nil);
      strcat(pc,#13#10);
      p:=pointer(DWORD(p)+cbSubKeyLen+2);
    end;
    strcat(pc,#0);
    p:=pointer(DWORD(p)+sizeof(#0));
    //子键列表大小：
    subkeysLen:=DWORD(p)-DWORD(pd)-sizeof(DWORD);
    pd^:=subkeysLen;
  end; //if cSubkeys

  if cVals>0 then
  begin
    pb:=virtualAlloc(nil,cbMaxValLen,MEM_COMMIT,PAGE_READWRITE);
    for i:=0 to cVals-1 do
    begin
      zeromemory(@ValueName,sizeof(valueName));
      cbValNameLen:=cbMaxValNameLen;
      cbValLen:=cbMaxValLen;
      RegEnumValueA(hk,i,ValueName,cbValNameLen,nil,@dwType,pb,@cbValLen);
      //值长度：
      pd:=PDWORD(p);pd^:=cbValNameLen;p:=pointer(DWORD(p)+sizeof(DWORD));
      //值类型：
      pd:=PDWORD(p);pd^:=dwType;p:=pointer(DWORD(p)+sizeof(DWORD));
      //数据长度：
      pd:=PDWORD(p);pd^:=cbValLen;p:=pointer(DWORD(p)+sizeof(DWORD));
      //值名称：
      copymemory(p,@ValueName,cbValNameLen+1);p:=pointer(cbValNameLen+1+DWORD(p));
      //数据：
      copymemory(p,pb,cbValLen);p:=pointer(cbValLen+DWORD(p));
    end;//for
    virtualFree(pb,cbMaxValLen,MEM_DECOMMIT);
    virtualFree(pb,0,MEM_RELEASE);
  end;//if cVals>0 then
  //返回块的实际大小：
  size:=DWORD(P)-DWORD(pData);
  result:=true;
1:
  RegCloseKey(hk);
end;
function RenameRegKey(rk:HKEY;oldKey,newkey:PansiChar):BOOL;
var
//setBackupAndRestorePriviliges
  hk:HKEY;
  FileName:array[0..max_path-1] of ansiChar;
  str:array[0..31] of ansiChar;
  err:integer;
begin
  result:=false;
  err:=RegOpenKeyExA(rk,oldKey,0,KEY_ALL_ACCESS,hk);
  if err<>ERROR_SUCCESS then exit;
  GetSystemDirectoryA(FileName,sizeof(FileName));
  strFromTime(str);strcat(FileName,'\');strcat(FileName,str);
  err:=RegSaveKeyA(hk,FileName,nil);
  if err<>ERROR_SUCCESS then begin RegCloseKey(hk);windows.DeleteFileA(FileName);exit;end;
  RegCloseKey(hk);
  err:=RegOpenKeyExA(rk,newkey,0,KEY_ALL_ACCESS,hk);
  if err<>error_file_not_found then begin RegCloseKey(hk);windows.DeleteFileA(FileName);exit;end;
  err:=RegCreateKeyExA(rk,newkey,0,nil,REG_OPTION_NON_VOLATILE,KEY_ALL_ACCESS,
    nil,hk,nil);
  if err<>ERROR_SUCCESS then begin windows.DeleteFileA(FileName);exit;end;
  result:=RegRestoreKeyA(hk,FileName,0)=ERROR_SUCCESS;
  if result then result:=DelRegKey(rk,oldKey);
  windows.DeleteFileA(FileName);
end;
function ReNameRegVal(rk:HKEY;key,oldVal,newVal:PansiChar):BOOL;
var
  RegType,cbData:Cardinal;
  Data:pointer;
  err:integer;
  hk:HKEY;
begin
  result:=false;
  err:=RegOpenKeyExA(rk,key,0,KEY_ALL_ACCESS,hk);
  if err<>ERROR_SUCCESS then exit;
  err:=RegQueryValueExA(hk,oldVal,nil,@RegType,nil,@cbData);
  if err<>ERROR_SUCCESS then begin RegCloseKey(hk);exit;end;
  getmem(Data,cbData);
  err:=RegQueryValueExA(hk,oldVal,nil,@RegType,Data,@cbData);
  if err<>ERROR_SUCCESS then begin RegCloseKey(hk);freemem(Data);exit;end;
  err:=RegDeleteValueA(hk,oldVal);
  if err<>ERROR_SUCCESS then begin RegCloseKey(hk);freemem(Data);exit;end;
  err:=RegSetValueExA(hk,newVal,0,RegType,Data,cbData);
  result:=err=ERROR_SUCCESS;
  RegCloseKey(hk);freemem(Data);
end;
function DelRegKey(rk:HKEY;key:PansiChar):BOOL;
var
  err:integer;
  Index,cbName:cardinal;
  hk:HKEY;
  name:array[0..255] of ansiChar;
begin
  result:=false;
  err:=RegOpenKeyExA(rk,key,0,KEY_ALL_ACCESS,hk);
  if err<>ERROR_SUCCESS then exit;
  Index:=0;cbName:=sizeof(name);
  err:=RegEnumKeyExA(hk,Index,name,cbName,nil,nil,nil,nil);
  while err=ERROR_SUCCESS do
  begin
    DelRegKey(hk,name);//Inc(Index);
    cbName:=sizeof(name);
    err:=RegEnumKeyExA(hk,Index,name,cbName,nil,nil,nil,nil);
  end;//while
  RegCloseKey(hk);
  err:=RegDeleteKeyA(rk,key);
  result:=err=ERROR_SUCCESS;
end;
function OpReg(var ro:stRegOpInfo):bool;
var
  hk:HKEY;
  err:integer;
  p:PansiChar;
begin
  result:=false;
  with ro do
  begin
    case op of
    REnumKey:
      begin
        GetRegKeys(rk,key,nil,siz);
        dat:=virtualAlloc(nil,siz,MEM_COMMIT,PAGE_READWRITE);
        GetRegKeys(rk,key,dat,siz);
      end;//REnumKey
    REnumFree:
      begin
        virtualfree(ro.dat,ro.siz,MEM_DECOMMIT);
        virtualfree(ro.dat,0,MEM_RELEASE);
        ro.siz:=0;
      end;//REnumFree
    RCreateKey:
      begin
        result:=RegCreateKeyExA(rk,key,0,nil,REG_OPTION_NON_VOLATILE,
          KEY_ALL_ACCESS,nil,hk,nil)=ERROR_SUCCESS;
        RegCloseKey(hk);
      end;//RCreateKey
    RRenameKey:
      begin
        result:=RenameRegKey(ro.rk,ro.key,ro.val);
      end;// RRenameKey
    Rdelkey:
      begin
        result:=DelRegKey(ro.rk,ro.key);
      end;// Rdelkey
    RGetVal:
      begin
        err:=RegOpenKeyExA(rk,key,0,KEY_ALL_ACCESS,hk);
        if err<>ERROR_SUCCESS then exit;
        result:=RegQueryValueExA(hk,val,nil,@typ,PByte(dat),@siz)=ERROR_SUCCESS;
        RegCloseKey(hk);
      end;//RGetVal
    RCreateVal:
      begin
        err:=RegCreateKeyA(rk,key,hk);
        if err<>ERROR_SUCCESS then exit;
        result:=RegSetValueExA(hk,val,0,typ,dat,siz)=ERROR_SUCCESS;
        RegCloseKey(hk);
      end;//RCreateVal
    RrenameVal:
      begin
        p:=ro.val;p:=p+strlen(p)+1;
        result:=RenameRegVal(ro.rk,ro.key,ro.val,p);
      end;//RrenameVal
    RDelVal:
      begin
        err:=RegOpenKeyExA(rk,key,0,KEY_ALL_ACCESS,hk);
        if err<>ERROR_SUCCESS then exit;
        err:=RegDeleteValueA(hk,Val);result:=err=ERROR_SUCCESS;
        RegCloseKey(hk);
      end;//RDelVal
    end;//case
  end;//with
end;
end.
