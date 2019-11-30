unit uRecvDataControl;

interface
uses
  windows,uOrder,uRecvData,uStr,uConfig;

type
pTposition=^Tposition;
  Tposition=record
    dX:DWORD;//��С��
    dY:DWORD;//��С��
end;
pTpath=^Tpath;
  Tpath=record
    x1:DWORD;//��С��
    y1:DWORD;//��С��
    x2:DWORD;//��С��
    y2:DWORD;//��С��
end;
  //�ͻ��˵�ַ��sockethandle��Ϣ
  pClientInfo=^stClientInfo;
  stClientInfo=packed record
    Socket: integer;
    IP:array[0..15] of ansichar;
  end;
pPhoneDir=^TPhoneDir;
  TPhoneDir=record
    iRootDir:DWORD;
    subDir:pansiChar;
    //subDir:array[0..MAX_PATH-1] of ansiChar;
end;
pTPhoneFileInfo=^TPhoneFileInfo;
  TPhoneFileInfo=record
    nFileSizeLow:integer;//��С��
    nFileSizeHigh:integer;//��С��
    ftLastWriteTime:array[0..MAX_TIME_STR-1] of ansiChar;//ʱ�䣻
    cFileName:array[0..MAX_FILE_NAME-1] of ansiChar;
end;

function StartRecvDataThread(order:integer):bool;stdcall;
function getPort(order:integer):integer;stdcall;
function getNum(order:integer):integer;stdcall;
procedure initDataServers(repeateIp:ansiString;port_data:integer;hForm:HWND);
implementation
function getPort(order:integer):integer;stdcall;
begin
   case order of
   CMD_SHOT:
     result:=RecvDatas[1].addr.port;
   CMD_CAMERA_CAP_START:
     result:=RecvDatas[2].addr.port;
   CMD_SOUND_CAP_START:
     result:=RecvDatas[3].addr.port;
   CMD_FILE_TRANS:
     result:=RecvDatas[4].addr.port;
   else
     result:=RecvDatas[0].addr.port;
   end;
end;
function getNum(order:integer):integer;stdcall;
begin
   result:=0;//���ݽ��ն˿ڣ�
   case order of
   CMD_SHOT:
     result:=1;
   CMD_CAMERA_CAP_START:
     result:=2;
   CMD_SOUND_CAP_START:
     result:=3;
   CMD_FILE_TRANS:
     result:=4;
   else
     result:=0;
   end;
end;
function StartRecvDataThread(order:integer):bool;stdcall;
var
  tID:DWORD;
  num:integer;
  pData:pRecvDataCS;
begin
  result:=true;
  num:=getNum(order);
  if(RecvDatas[num].thread.active)then begin
    //showmessage('ϵͳæ����������������ť');
    result:=false;
    exit;
  end;
  if(TransFilesCS.thread.active)then begin
    //showmessage('���ڴ����ļ����Ƿ�Ҫ�жϴ��䣿����Ҫ�жϣ���������������ť');
    result:=false;
    exit;
  end;
  if(order=CMD_FILE_TRANS)then begin
    TransFilesCS.thread.hThread:=createthread(nil,0,@TransDirThread,@TransFilesCS,0,tID);
    TransFilesCS.thread.threadID:=tID;
    exit;
  end;
  if(order=CMD_SOUND_CAP_START)then begin
    pdata:=@RecvDatas[num];
    TransFilesCS.thread.hThread:=createthread(nil,0,@RecvSoundThread,pdata,0,tID);
    TransFilesCS.thread.threadID:=tID;
    exit;
  end;
  pdata:=@RecvDatas[num];
  RecvDatas[num].thread.hThread:=createthread(nil,0,@RecvDataThread,pdata,0,tID);
  RecvDatas[num].thread.threadID:=tID;
end;

procedure initDataServers(repeateIp:ansiString;port_data:integer;hForm:HWND);
var
  i:integer;
begin
   zeromemory(@RecvDatas,sizeof(RecvDatas));
  for i:=0 to length(RecvDatas)-1 do
  begin
   //dataServers[i].port:=port_order+i;
   RecvDatas[i].thread.threadType:=FRecvDataThread;
   RecvDatas[i].thread.active:=false;
   RecvDatas[i].sendMsg.hform:=hForm;
   RecvDatas[i].sendMsg.msgType:=wm_TransData;
   RecvDatas[i].addr.flg:=0;
   ustr.strcopy(RecvDatas[i].addr.IP,pansichar(repeateIp));
   RecvDatas[i].addr.port:=port_data+i;
   RecvDatas[i].num:=i;
   zeromemory(@RecvDatas[i].buf[0],MAX_BUF);
  end;//for
  zeromemory(@TransFilesCS,sizeof(TransFilesCS));
  TransFilesCS.thread.threadType:=FtransFileThread;
  TransFilesCS.sendMsg.hform:=hForm;
  TransFilesCS.sendMsg.msgType:=wm_TransFile;
  TransFilesCS.addr.flg:=0;
  strcopy(TransFilesCS.addr.IP,pansichar(repeateIp));
  TransFilesCS.addr.port:=uConfig.port_FILE;
end;

end.