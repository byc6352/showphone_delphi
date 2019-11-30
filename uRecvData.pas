unit uRecvData;

interface
uses windows,uSocket,uOrder,winsock,ustr,uFuncs,uZip;
const
  wm_user=$0400;
  wm_TransData=wm_user+100+1;
  wm_TransOrder=wm_user+100+2;
  wm_TransFile=wm_user+100+3;
  MAX_BUF=1024*1024;
  MAX_PATH=260;
  MAX_FILE_NAME=64;
  MAX_TIME_STR=24;

  MAXBUF=8192;
type
  //Char=ansiChar;
  //PChar=PansiChar;
  TInfFlag=(Fconnect,FrecvOH,FrecvData);//信息标识；
  TAPIType=(Fwindows,Fsock);
  TAPIFlag=(FWSAStartup,Fsocket,Fsetsockopt,Fbind,Flisten,Faccept,Frecv,FcreateFile,FGetFileSize,Fsend,FRecv2,
            FWriteFile,FSetFilePointer,Frecv_S,FSetFilePointer_S,FReadFile_S,FReadFile_S1,Fsend_S,Fcreatethread,
            FGetFileAttributes,FDirectoryCompression,FDirectoryCompression_1,FDirectoryDecompression_1,FDirectoryDecompression,
            Fdeletefile,FRecv3,FCreateDIBSection,FNull,FthreadStart,FthreadEnd,Fverify,FPackageEnd,FfileConnect,FRecvFileOH);
  TThreadType=(FRecvDataThread,FtransFileThread);
  pSocket=^stSocket;
  stSocket=packed record
    socketHandle:tsocket;
    addr:tsockaddr;
    addrLen:integer;
  end;
  pThreadInfo=^stThreadInfo;
  stThreadInfo=packed record
    threadType:TThreadType;
    active:bool;
    hThread:cardinal;
    threadID:cardinal;
  end;
  pRunInfo=^stRunInfo; //运行信息；
  stRunInfo=packed record
    FInf:TInfFlag;
    APIType:TAPIType;
    Inf:array[0..255] of ansichar;
    errCode:integer;
    bResult:bool;
  end;
  pTransRate=^stTransRate;  //接收速率；
  stTransRate=packed record
    Transed:cardinal;
    TransedHigh:cardinal;
    Speed:int64;
  end;
  pSendMsgTo=^stSendMsgTo; //信息发送方向；
  stSendMsgTo=packed record
    hform:hwnd;
    msgType:cardinal;
  end;
  pRecvDataCS=^stRecvDataCS; //信息体;
  stRecvDataCS=packed record
    thread:stThreadInfo;
    runInf:stRunInfo;
    sendMsg:stSendMsgTo;
    socket:stSocket;
    oh:stOrderHeader;
    addr:stSvrAddr;
    num:integer;
    buf:array[0..MAX_BUF-1] of ansichar;
  end;
  stRequestFileInfo=packed record
    fileName:array[0..MAX_PATH-1] of ansichar;
    bUpLoad:bool;
  end;//
  pTransFilesInfo=^stTransFilesInfo;
  stTransFilesInfo=packed record
    clientFile:array[0..MAX_PATH-1] of ansichar;
    serverFile:array[0..MAX_PATH-1] of ansichar;
    iRootDir:DWORD;
    bUpLoad:bool;
    bFolder:bool;
    bCompleteDel:bool;
  end;

  pFileInfo=^stFileInfo;
  stFileInfo=packed record
    hFile:cardinal;
    isUpLoad:bool;
    FileName:array[0..MAX_PATH-1] of ansichar;
    FileSize:cardinal;
    FileSizeHigh:cardinal;
    ClientFileSize:cardinal;
    ClientFileSizeHigh:cardinal;
  end;
  pRunAPIInfo=^stRunAPIInfo;
  stRunAPIInfo=packed record
    aAPI:TAPIFlag;
    APIType:TAPIType;
    result:integer;
    errCode:integer;
    Info:array[0..1023] of ansichar;
  end;
 pTransFilesCS=^stTransFilesCS;
  stTransFilesCS=packed record
    thread:stThreadInfo;
    runAPI:stRunAPIInfo;
    sendMsg:stSendMsgTo;
    socket:stSocket;
    fileInfo:stFileInfo;
    transRate:stTransRate;
    oh:stOrderHeader;
    addr:stSvrAddr;
  end;
  pPhoneFileName=^TPhoneFileName;
  TPhoneFileName=record
    iRootDir:DWORD;
    filename:utf8String;
    //subDir:array[0..MAX_PATH-1] of ansiChar;
end;
//输入 ：IP，port，信息发送窗体,信息类别;
//输出：信息标识，信息体；数据类别（指令头），数据体，数据长度；
function RecvInf(pData:pRecvDataCS;FInf:tInfFlag):bool;stdcall;
function RecvDataThread(pParam:pointer):bool;stdcall;
procedure GetAPIErrCode(pRun:pRunInfo);stdcall;overload;
procedure GetAPIErrCode(pRun:pRunAPIInfo);stdcall;overload;
procedure disConnectDataServers();
procedure TransDirThread(pTransFilesInfo:pointer);stdcall;
function TransDirAPI(pTransFilesInfo:pointer;FAPI:tAPIFlag):bool;stdcall;
function RecvSoundThread(pParam:pointer):bool;stdcall;

var
  RecvDatas:array[0..4] of stRecvDataCS;
  TransFilesCS:stTransFilesCS;
implementation

uses
  umain;
function RecvSoundThread(pParam:pointer):bool;stdcall;
var
  pAddr:pSvrAddr;
  pData:pRecvDataCS;
begin
try
  pData:=pParam;
  pData^.runInf.bResult:=ConnectServer(pData^.socket.socketHandle,pData^.addr);
  if not RecvInf(pData,Fconnect) then exit;
  uOrder.formatOH(pData^.oh);
  SendBuf(pData^.socket.socketHandle,@(pData^.oh),sizeof(stOrderHeader));
  pData^.runInf.bResult:=RecvBuf(pData^.socket.socketHandle,@(pData^.oh),sizeof(stOrderHeader));
  if not RecvInf(pData,FRecvOH) then exit;
  while true do
  begin
    pData^.oh.Dat:=@pData^.buf[0];
    if(pData^.oh.len<=0) or (pData^.oh.len>MAX_BUF)then begin FreeSocket(pData^.socket.socketHandle);pData^.socket.socketHandle:=0;exit; end;
    zeromemory(pData^.oh.Dat,pData^.oh.len+1);
    pData^.runInf.bResult:=RecvBuf(pData^.socket.socketHandle,pData^.oh.Dat,pData^.oh.len);
    if not RecvInf(pData,FRecvData) then exit;
  end;
except
end;
end;
procedure disConnectDataServers();
var
  i:integer;
begin
  for i:=0 to length(RecvDatas)-1 do
  begin
    if(RecvDatas[i].thread.active)then begin
      if(RecvDatas[i].socket.socketHandle<>0)then begin
         closesocket(RecvDatas[i].socket.socketHandle);
         RecvDatas[i].socket.socketHandle:=0;
         RecvDatas[i].thread.active:=false;
         zeromemory(@RecvDatas[i].buf[0],MAX_BUF);
      end;//
    end;
  end;
  if(TransFilesCS.thread.active)then begin
      closesocket(TransFilesCS.socket.socketHandle);
      TransFilesCS.socket.socketHandle:=0;
      TransFilesCS.thread.active:=false;
  end;
end;
function RecvInf(pData:pRecvDataCS;FInf:tInfFlag):bool;stdcall;
var
  pRun:pRunInfo;
  pMsg:pSendMsgTo;
  cport:array[0..7] of ansiChar;
  cSize:array[0..7] of ansiChar;
begin
  result:=true;
  ustr.inttostr(pData^.addr.port,cport);
  pRun:=pRunInfo(pansiChar(pData)+sizeof(stThreadInfo));
  pMsg:=pSendMsgTo(pansiChar(pData)+sizeof(stThreadInfo)+sizeof(stRunInfo));
  pData^.runInf.FInf:=FInf;
  //pSock:=pSocket(pansiChar(pData)+sizeof(stThreadInfo)+sizeof(stRunAPIInfo)+sizeof(stSendMsgTo));
  case FInf of
  Fconnect:
    begin
      pData^.thread.active:=true;
      pData^.runInf.APIType:=Fsock;
      if(pData^.runInf.bResult)then begin
          strcopy(pRun^.Inf,'数据服务：连接服务器成功!端口号：');
          strcat(pRun^.Inf,cport);
          sendMessage(pMsg^.hform,pMsg^.msgType,0,integer(pData));
          //postMessage(RecvDatas[pData^.num].sendMsg.hform,RecvDatas[pData^.num].sendMsg.msgType,0,integer(pData));
          exit;
      end else begin
          strcopy(pRun^.Inf,'数据服务：连接服务器失败!');
      end;
    end;
    FRecvOH:
    begin
      pData^.runInf.APIType:=Fsock;
      if(pData^.runInf.bResult)then begin  //pData^.oh.DataSize>0
        if(verifyOh(pData^.oh))then
        begin
          strcopy(pRun^.Inf,'数据服务：接收数据头成功!端口号：');
          strcat(pRun^.Inf,cport);
          strcat(pRun^.Inf,'数据大小：');
          ustr.inttostr(pData^.oh.len,cSize);
          strcat(pRun^.Inf,cSize);
          sendMessage(pMsg^.hform,pMsg^.msgType,0,integer(pData));
          exit;
        end else begin
          strcopy(pRun^.Inf,'数据服务：数据头校验失败！');
        end;
      end else begin
          strcopy(pRun^.Inf,'数据服务：接收数据头退出!代码是：');
      end;
    end;
    FRecvData:
    begin
      pData^.runInf.APIType:=Fsock;
      if(pData^.runInf.bResult)then begin
          strcopy(pRun^.Inf,'数据服务：接收数据成功!端口号：');
          strcat(pRun^.Inf,cport);
          strcat(pRun^.Inf,'数据大小：');
          ustr.inttostr(pData^.oh.len,cSize);
          strcat(pRun^.Inf,cSize);
          SendMessage(pMsg^.hform,pMsg^.msgType,0,integer(pData));
          //if(pData^.oh.len>0)then begin
          //  dispose(pData^.oh.dat);
          //  pData^.oh.dat:=nil;
         // end;
          exit;
      end else begin
          strcopy(pRun^.Inf,'数据服务：接收数据失败!信息：端口号：');
          strcat(pRun^.Inf,cport);
          //if(pData^.oh.len>0)then begin
          //  dispose(pData^.oh.dat);
           // pData^.oh.dat:=nil;
         // end;
      end;
    end;
  end;
  GetAPIErrCode(pRun);
  if strlen(pData^.runInf.Inf)>0 then
    strcat(pData^.runInf.Inf,'数据线程结束！端口号：')
  else
    strcopy(pData^.runInf.Inf,'数据线程结束！端口号：');
  strcat(pRun^.Inf,cport);
  //sendMessage(pData^.sendMsg.hform,pData^.sendMsg.msgType,0,integer(pData));
  //postMessage(RecvDatas[pData^.num].sendMsg.hform,RecvDatas[pData^.num].sendMsg.msgType,0,integer(pData));
  SendMessage(pMsg^.hform,pMsg^.msgType,0,integer(pData));
  if(pData^.socket.socketHandle<>0)then
    FreeSocket(pData^.socket.socketHandle);
  pData^.socket.socketHandle:=0;
  pData^.thread.active:=false;
  result:=false;
end;
function RecvDataThread(pParam:pointer):bool;stdcall;
var
  pAddr:pSvrAddr;
  pData:pRecvDataCS;
  recved:integer;
  intBuf:array[0..7] of ansiChar;
begin
try
  pData:=pParam;
  pData^.runInf.bResult:=ConnectServer(pData^.socket.socketHandle,pData^.addr);
  if not RecvInf(pData,Fconnect) then exit;
  uOrder.formatOH(pData^.oh);
  SendBuf(pData^.socket.socketHandle,@(pData^.oh),sizeof(stOrderHeader));
  while true do
  begin
    pData^.runInf.bResult:=RecvBuf(pData^.socket.socketHandle,@(pData^.oh),sizeof(stOrderHeader));
    if not RecvInf(pData,FRecvOH) then exit;
    pData^.oh.Dat:=@pData^.buf[0];
    if(pData^.oh.len<=0) or (pData^.oh.len>MAX_BUF)then
    begin
      FreeSocket(pData^.socket.socketHandle);
      pData^.socket.socketHandle:=0;
      pData^.thread.active:=false;
      uStr.Inttostr(pData^.oh.len,intbuf);
      fmain.LogMain('RecvDataThread:recv:exit:'+intbuf);
      exit;
    end;
    //GetMem(pData^.oh.Dat,pData^.oh.len);
    zeromemory(pData^.oh.Dat,pData^.oh.len+1);
    pData^.runInf.bResult:=RecvBuf(pData^.socket.socketHandle,pData^.oh.Dat,pData^.oh.len);
    if not RecvInf(pData,FRecvData) then exit;
  end;
finally
  uStr.Inttostr(pData^.addr.port,intbuf);
  fmain.LogMain('RecvDataThread over:port:'+intbuf);
end;
end;
//******************************************************************************************
procedure TransDirThread(pTransFilesInfo:pointer);stdcall;
var
  pdata:pTransFilesCS;
  buf:array[0..MAXBUF-1] of ansiChar;
  RequestFileInfo:stRequestFileInfo;
  wLen,NumberOfRead:cardinal;
  ZipFileName:array[0..MAX_PATH] of ansiChar;
  Dir:array[0..MAX_PATH] of ansiChar;
  //fileSize,wLen,clientFileSize,NumberOfRead,fileSizehigh,clientFileSizeHigh:cardinal;
  //RecvLen:integer;
  bResult:boolean;
begin
  pdata:=pTransFilesInfo;
  TransDirAPI(pData,FthreadStart);

  bResult:=ConnectServer(pData^.socket.socketHandle,pData^.addr);
  if(bResult=true)then pData^.runAPI.result:=1 else pData^.runAPI.result:=0;
  if not TransDirAPI(pData,FfileConnect) then exit;

  uOrder.formatOH(pData^.oh);
  SendBuf(pData^.socket.socketHandle,@(pData^.oh),sizeof(stOrderHeader));

  pData^.runAPI.result:=Recv(pData^.socket.socketHandle,pData^.oh,sizeof(stOrderHeader),0);
  if not TransDirAPI(pData,FRecvFileOH) then exit;

  pData^.runAPI.result:=Recv(pData^.socket.socketHandle,RequestFileInfo,sizeof(RequestFileInfo),0);
  if not TransDirAPI(pData,Frecv) then exit;
  //worksfoldter:
  ustr.strcopy(ZipFileName,ustr.ExtractFileName(RequestFileInfo.fileName));
  if(lstrcmpiA(ZipFileName,RequestFileInfo.fileName)=0) then
  begin
    strcopy(RequestFileInfo.fileName,GetWorksFolder(Dir));
    strcat(RequestFileInfo.fileName,'\');strcat(RequestFileInfo.fileName,ZipFileName);
  end;

  strcopy(pData^.fileInfo.fileName,RequestFileInfo.fileName);
  pData^.fileInfo.isUpLoad:=RequestFileInfo.bupLoad;

  if not RequestFileInfo.bUpLoad then
  begin
    pData^.runAPI.result:=GetFileAttributesa(RequestFileInfo.fileName);
    if not TransDirAPI(pData,FGetFileAttributes) then exit;

    if (FILE_ATTRIBUTE_DIRECTORY and pData^.runAPI.result) <> 0 then
    begin
      strcopy(ZipFileName,RequestFileInfo.fileName);
      strcat(ZipFileName,'.dir');

      TransDirAPI(pData,FDirectoryCompression_1);
      pData^.runAPI.result:=DirectoryCompression(RequestFileInfo.fileName,ZipFileName);
      if not TransDirAPI(pData,FDirectoryCompression) then exit;
      
      strcopy(RequestFileInfo.fileName,ZipFileName);
    end;//if (FILE_ATTRIBUTE_DIRECTORY and pData^.runAPI.result) <> 0 then
    pData^.runAPI.result:=CreateFileA(RequestFileInfo.fileName,GENERIC_READ,FILE_SHARE_READ,
      nil,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL or FILE_ATTRIBUTE_ARCHIVE,0);

    if not TransDirAPI(pData,FCreateFile) then exit;

    pData^.fileInfo.hFile:=pData^.runAPI.result;
  end//if not RequestFileInfo.isUpLoad then
  else begin
    pData^.runAPI.result:=CreateFileA(RequestFileInfo.fileName,GENERIC_READ or GENERIC_WRITE,FILE_SHARE_READ,
      nil,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL or FILE_ATTRIBUTE_ARCHIVE,0);

    if not TransDirAPI(pData,FCreateFile) then exit;

    pData^.fileInfo.hFile:=pData^.runAPI.result;
  end; // 上传
  pData^.runAPI.result:=GetFileSize(pData^.fileInfo.hFile,@pData^.fileInfo.fileSizehigh);
  if not TransDirAPI(pData,FGetFileSize) then exit;

  pData^.fileInfo.FileSize:=pData^.runAPI.result;

  if RequestFileInfo.bUpLoad then
    begin
      pData^.transRate.Transed:=pData^.fileInfo.FileSize;
      pData^.transRate.TransedHigh:=pData^.fileInfo.FileSizeHigh;

      pData^.runAPI.result:=SetFilePointer(pData^.fileInfo.hFile,0,nil,FILE_END);
      if not TransDirAPI(pData,FSetFilePointer) then exit;

      pData^.runAPI.result:=recv(pData^.socket.socketHandle,pData^.fileInfo.ClientFileSize,4,0);
      if not TransDirAPI(pData,Frecv) then exit;
      pData^.runAPI.result:=recv(pData^.socket.socketHandle,pData^.fileInfo.ClientFileSizeHigh,4,0);
      if not TransDirAPI(pData,Frecv) then exit;

      pData^.runAPI.result:=send(pData^.socket.socketHandle,pData^.fileInfo.fileSize,4,0);
      if not TransDirAPI(pData,Fsend) then exit;
      pData^.runAPI.result:=send(pData^.socket.socketHandle,pData^.fileInfo.fileSizeHigh,4,0);
      if not TransDirAPI(pData,Fsend) then exit;
      pData^.transRate.Speed:=0;
      while true do
      begin
        FillChar(buf,SizeOf(buf),0);
        pData^.runAPI.result:=Recv(pData^.socket.socketHandle,buf,sizeof(buf),0);
        if not TransDirAPI(pData,FRecv2) then break;

        if cardinal($FFFFFFFF)-pData^.transRate.Transed>cardinal(pData^.runAPI.result) then
          pData^.transRate.TransedHigh:=pData^.transRate.TransedHigh+1;
        pData^.transRate.Transed:=pData^.transRate.Transed+pData^.runAPI.result;
        pData^.transRate.Speed:=pData^.transRate.Speed+pData^.runAPI.result;

        pData^.runAPI.result:=integer(WriteFile(pData^.fileInfo.hFile,Buf,pData^.runAPI.result,wLen,nil));
        if not TransDirAPI(pData,FWriteFile) then break;
      end;//while
    end
    else begin
      pData^.runAPI.result:=recv(pData^.socket.socketHandle,pData^.fileInfo.ClientFileSize,4,0);
      if not TransDirAPI(pData,Frecv_S) then exit;
      pData^.runAPI.result:=recv(pData^.socket.socketHandle,pData^.fileInfo.ClientFileSizeHigh,4,0);
      if not TransDirAPI(pData,Frecv_S) then exit;

      pData^.runAPI.result:=SetFilePointer(pData^.fileInfo.hFile,pData^.fileInfo.ClientFileSize,@pData^.fileInfo.ClientFileSizeHigh,FILE_BEGIN);
      if not TransDirAPI(pData,FSetFilePointer_S) then exit;
      pData^.transRate.Speed:=0;
      while true do
      begin
        pData^.runAPI.result:=integer(ReadFile(pData^.fileInfo.hFile,buf,sizeof(buf),NumberOfRead,nil));
        if not TransDirAPI(pData,FReadFile_S) then  break;
        pData^.runAPI.result:=NumberOfRead;
        if not TransDirAPI(pData,FReadFile_S1) then  break;

        pData^.runAPI.result:=send(pData^.socket.socketHandle,buf,NumberOfRead,0);
        if not TransDirAPI(pData,Fsend_S) then  exit;

        if $FFFFFFFF-pData^.transRate.Transed>pData^.runAPI.result then
          pData^.transRate.TransedHigh:=pData^.transRate.TransedHigh+1;
        pData^.transRate.Transed:=pData^.transRate.Transed+pData^.runAPI.result;
        pData^.transRate.Speed:=pData^.transRate.Speed+pData^.runAPI.result;
      end;//send(socket1,buf,NumberOfRead,0);
    end; //not if TransFileInfo.upLoad then

  if RequestFileInfo.bUpLoad then
  begin
    if strpos(RequestFileInfo.fileName,'.dir')<>nil then
    begin
      strlcopy(Dir,RequestFileInfo.fileName,strlen(RequestFileInfo.fileName)-4);
      createdirectoryA(Dir,nil);

      TransDirAPI(pData,FDirectoryDecompression_1);
      pData^.runAPI.result:=DirectoryDecompression(Dir,RequestFileInfo.fileName);
      if not TransDirAPI(pData,FDirectoryDecompression) then exit;
      
      pData^.runAPI.result:=integer(deletefileA(RequestFileInfo.fileName));
      if not TransDirAPI(pData,Fdeletefile) then exit;
    end;//if strpos(RequestFileInfo.fileName,'dir')<>nil then
  end//if RequestFileInfo.upLoad then
  else begin
    if strpos(RequestFileInfo.fileName,'.dir')<>nil then
    begin
      pData^.runAPI.result:=integer(deletefileA(RequestFileInfo.fileName));
      if not TransDirAPI(pData,Fdeletefile) then exit;
    end;//if strpos(RequestFileInfo.fileName,'dir')<>nil then
  end;//if RequestFileInfo.isUpLoad then
end;
function TransDirAPI(pTransFilesInfo:pointer;FAPI:tAPIFlag):bool;stdcall;
var
  pdata:pTransFilesCS;
  pRun:pRunAPIInfo;
  pThreadDataInfo:pThreadInfo;
  pSock:pSocket;
  pMsg:pSendMsgTo;
  pFile:pFileInfo;
  intBuf:array[0..7] of ansiChar;
  tmp1,tmp2,tmp3:ansiString;
begin
  result:=true;
  pdata:=pTransFilesInfo;
  pThreadDataInfo:=pTransFilesInfo;
  pRun:=pRunAPIInfo(pansiChar(pData)+sizeof(stThreadInfo));
  pMsg:=pSendMsgTo(pansiChar(pData)+sizeof(stThreadInfo)+sizeof(stRunAPIInfo));
  pSock:=pSocket(pansiChar(pData)+sizeof(stThreadInfo)+sizeof(stRunAPIInfo)+sizeof(stSendMsgTo));
  pFile:=pFileInfo(pansiChar(pData)+sizeof(stThreadInfo)+sizeof(stRunAPIInfo)+sizeof(stSendMsgTo)+sizeof(stSocket));
  pRun^.aAPI:=FAPI;
  case pRun^.aAPI of
  FthreadStart:
    begin
      pRun^.APIType:=Fwindows;
      strcopy(pRun^.Info,'文件传输线程开始!');
      SendMessage(pMsg^.hform,pMsg^.msgType,0,integer(pData));
      exit;
    end;
  FfileConnect:
    begin
      pRun^.APIType:=Fwindows;
      if pRun^.result=0 then begin
        strcopy(pRun^.Info,'文件传输:连接服务器失败!');
        SendMessage(pMsg^.hform,pMsg^.msgType,0,integer(pData));
        pThreadDataInfo^.active:=false;
        result:=false;
        exit;
      end else begin
        strcopy(pRun^.Info,'文件传输:连接服务器成功!');
        pThreadDataInfo^.active:=true;
        SendMessage(pMsg^.hform,pMsg^.msgType,0,integer(pData));
        exit;
      end;
    end;
  FrecvFileOH:
    begin
      pRun^.APIType:=Fsock;
      if pRun^.result<>SOCKET_ERROR then exit;
      strcopy(pRun^.Info,'接收文件数据失头败!错误代码是：');
    end;//Frecv
  Frecv:
    begin
      pRun^.APIType:=Fsock;
      if pRun^.result<>SOCKET_ERROR then exit;
      strcopy(pRun^.Info,'接收数据失败!错误代码是：');
    end;//Frecv
  FDirectoryCompression_1:
    begin
      pRun^.APIType:=Fwindows;
      strcopy(pRun^.Info,'开始压缩文件..!');
      strcat(pRun^.Info,pFile^.fileName);
      SendMessage(pMsg^.hform,pMsg^.msgType,0,integer(pData));
      exit;
    end;
  FDirectoryCompression:
    begin
      pRun^.APIType:=Fwindows;
      if pRun^.result>0 then
      begin
        strcopy(pRun^.Info,'压缩文件完成!');
        strcat(pRun^.Info,pFile^.fileName);
        SendMessage(pMsg^.hform,pMsg^.msgType,0,integer(pData));
        exit;
      end
      else begin
        strcopy(pRun^.Info,'压缩文件失败!');
        strcat(pRun^.Info,pFile^.fileName);
      end;
    end;//FDirectoryCompression
    FcreateFile:
      begin
        pRun^.APIType:=Fwindows;
        if (pRun^.result<>-1) then exit;
        strcopy(pRun^.Info,'创建文件失败!错误代码是：');
      end;//FcreateFile:
  FGetFileSize:
    begin
      pRun^.APIType:=Fwindows;
      if pRun^.result<>-1 then exit;
      if (pRun^.result=-1) and (GetLastError()=NO_ERROR) then exit;
      strcopy(pRun^.Info,'获取文件大小失败!');
    end;//FGetFileSize
  FSetFilePointer:
    begin
      pRun^.APIType:=Fwindows;
      if pRun^.result<>-1 then exit;
      strcopy(pRun^.Info,'设置文件位置失败!!');
    end;//FSetFilePointer
  Fsend:
    begin
      pRun^.APIType:=Fsock;
      if pRun^.result<>SOCKET_ERROR then exit;
      strcopy(pRun^.Info,'发送数据失败!');
    end;//Fsend
  Frecv2:
    begin
      pRun^.APIType:=Fsock;
      if (pRun^.result<>INVALID_SOCKET) and (pRun^.result<>0) then exit;
      if pRun^.result=SOCKET_ERROR then
      begin
        strcopy(pRun^.Info,'接收文件数据失败!');
        GetAPIErrCode(pRun);
      end;
      if pRun^.result=0 then
        strcopy(pRun^.Info,'文件接收完成!');
        strcat(pRun^.Info,pFile^.FileName);
    end; //Frecv2
  FWriteFile:
    begin
      pRun^.APIType:=Fwindows;
      if (pRun^.result=1)and(pdata^.fileInfo.ClientFileSize>pdata^.transRate.Transed) then
      begin
        tmp1:=ustr.Inttostr(pdata^.transRate.Transed,intBuf);
        tmp2:=ustr.Inttostr(pdata^.fileInfo.ClientFileSize,intBuf);
        tmp3:='已接收数据：'+tmp1+'/'+tmp2;
        strcopy(pRun^.Info,pansichar(tmp3));
        SendMessage(pMsg^.hform,pMsg^.msgType,0,integer(pData));
        exit;
      end;
      if (pRun^.result=0)then
        strcopy(pRun^.Info,'写文件失败!')
      else begin
        strcopy(pRun^.Info,'文件接收完成!');
        strcat(pRun^.Info,pFile^.FileName);
      end;
    end;//Fwritefile
  Frecv_S:
    begin
      pRun^.APIType:=Fsock;
      if pRun^.result=4 then exit;
      strcopy(pRun^.Info,'接收文件大小失败!(发送文件)');
    end;//Frecv_S
  FSetFilePointer_S:
    begin
      pRun^.APIType:=Fwindows;
      if pRun^.result<>-1 then exit;
      strcopy(pRun^.Info,'设置文件位置失败!(发送文件)');
    end;//FSetFilePointer_S
  FReadFile_S:
    begin
      pRun^.APIType:=Fwindows;
      if pRun^.result=1 then exit;
      strcopy(pRun^.Info,'读文件失败!(发送文件)');
    end;//Freadfile_s
  FReadFile_S1:
    begin
      pRun^.APIType:=Fwindows;
      if pRun^.result>0 then exit;
      strcopy(pRun^.Info,'发送文件完成!(发送文件)');
      strcat(pRun^.Info,pFile^.fileName);
    end;//Freadfile_s1
  Fsend_S:
    begin
      pRun^.APIType:=Fwindows;
      if pRun^.result<>SOCKET_ERROR then exit;
      strcopy(pRun^.Info,'发送数据失败!(发送文件)');
    end;
  FGetFileAttributes:
    begin
      pRun^.APIType:=Fwindows;
      if pRun^.result<>-1 then exit;
      strcopy(pRun^.Info,'获取文件属性失败!');
    end;
  FDirectoryDecompression_1:
    begin
      pRun^.APIType:=Fwindows;
      strcopy(pRun^.Info,'开始解压缩文件..!');
      strcat(pRun^.Info,pFile^.fileName);
      SendMessage(pMsg^.hform,pMsg^.msgType,0,integer(pData));
      exit;
    end;
  FDirectoryDecompression:
    begin
      pRun^.APIType:=Fwindows;
      if pRun^.result>0 then
      begin
        strcopy(pRun^.Info,'解压缩文件完成!');
        strcat(pRun^.Info,pFile^.fileName);
        SendMessage(pMsg^.hform,pMsg^.msgType,0,integer(pData));
        exit;
      end;
      strcopy(pRun^.Info,'解压缩文件失败!');
      strcat(pRun^.Info,pFile^.fileName);
    end;//
    Fdeletefile:
    begin
      pRun^.APIType:=Fwindows;
      if pRun^.result=1 then exit;
      strcopy(pRun^.Info,'删除文件失败!');
      strcat(pRun^.Info,pFile^.fileName);
    end;
  end;//case
  GetAPIErrCode(pRun);
  closesocket(pSock^.socketHandle);
  CloseHandle(pFile^.hFile);
  pThreadDataInfo^.active:=false;
  SendMessage(pMsg^.hform,pMsg^.msgType,0,integer(pData));
  //dispose(pData);
  result:=false;
end;

//******************************************************************************************
procedure GetAPIErrCode(pRun:pRunAPIInfo);stdcall;
var
    ErrMsg:Array[0..255] of ansiChar;
begin
  case pRun^.APIType of
  Fwindows:
    begin
      pRun^.errCode:=GetLastError;
      FormatMessageA(FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS, //FORMAT_MESSAGE_ARGUMENT_ARRAY
      nil,pRun^.errCode,0,ErrMsg,sizeof(ErrMsg),nil); //MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT)
    end;
  Fsock:
    begin
      pRun^.errCode:=WSAGetLastError;
      strcopy(ErrMsg,'中断连接!');
      case pRun^.errCode of
      WSAEINTR            :strcopy(ErrMsg,'WSAEINTR(10004)');
      WSAEACCES	          :strcopy(ErrMsg,'WSAEACCES(10013)');
      WSAEFAULT	          :strcopy(ErrMsg,'WSAEFAULT(10014)');
      WSAEINVAL	          :strcopy(ErrMsg,'WSAEINVAL(10022)');
      WSAEMFILE	          :strcopy(ErrMsg,'WSAEMFILE(10024)');
      WSAEWOULDBLOCK	  :strcopy(ErrMsg,'WSAEWOULDBLOCK(10035)');
      WSAEINPROGRESS	  :strcopy(ErrMsg,'WSAEINPROGRESS(10036)');
      WSAEALREADY	  :strcopy(ErrMsg,'WSAEALREADY(10037)');
      WSAENOTSOCK	  :strcopy(ErrMsg,'WSAENOTSOCK(10038)');
      WSAEDESTADDRREQ	  :strcopy(ErrMsg,'WSAEDESTADDRREQ(10039)');
      WSAEMSGSIZE	  :strcopy(ErrMsg,'WSAEMSGSIZE(10040)');
      WSAEPROTOTYPE	  :strcopy(ErrMsg,'WSAEPROTOTYPE(10041)');
      WSAENOPROTOOPT	  :strcopy(ErrMsg,'WSAENOPROTOOPT(10042)');
      WSAEPROTONOSUPPORT  :strcopy(ErrMsg,'WSAEPROTONOSUPPORT(10043)');
      WSAESOCKTNOSUPPORT  :strcopy(ErrMsg,'WSAESOCKTNOSUPPORT(10044)');
      WSAEOPNOTSUPP	  :strcopy(ErrMsg,'WSAEOPNOTSUPP(10045)');
      WSAEPFNOSUPPORT	  :strcopy(ErrMsg,'WSAEPFNOSUPPORT(10046)');
      WSAEAFNOSUPPORT	  :strcopy(ErrMsg,'WSAEAFNOSUPPORT(10047)');
      WSAEADDRINUSE	  :strcopy(ErrMsg,'WSAEADDRINUSE(10048)');
      WSAEADDRNOTAVAIL	  :strcopy(ErrMsg,'WSAEADDRNOTAVAIL(10049)');
      WSAENETDOWN	  :strcopy(ErrMsg,'WSAENETDOWN(10050)');
      WSAENETUNREACH	  :strcopy(ErrMsg,'WSAENETUNREACH(10051)');
      WSAENETRESET	  :strcopy(ErrMsg,'WSAENETRESET(10052)');
      WSAECONNABORTED	  :strcopy(ErrMsg,'WSAECONNABORTED(10053)');
      WSAECONNRESET	  :strcopy(ErrMsg,'WSAECONNRESET(10054)');
      WSAENOBUFS	  :strcopy(ErrMsg,'WSAENOBUFS(10055)');
      WSAEISCONN	  :strcopy(ErrMsg,'WSAEISCONN(10056)');
      WSAENOTCONN	  :strcopy(ErrMsg,'WSAENOTCONN(10057)');
      WSAESHUTDOWN	  :strcopy(ErrMsg,'WSAESHUTDOWN(10058)');
      WSAETIMEDOUT	  :strcopy(ErrMsg,'WSAETIMEDOUT(10060)');
      WSAECONNREFUSED	  :strcopy(ErrMsg,'WSAECONNREFUSED(10061)');
      WSAEHOSTDOWN	  :strcopy(ErrMsg,'WSAEHOSTDOWN(10064)');
      WSAEHOSTUNREACH	  :strcopy(ErrMsg,'WSAEHOSTUNREACH(10065)');
      WSAEPROCLIM	  :strcopy(ErrMsg,'WSAEPROCLIM(10067)');
      WSASYSNOTREADY	  :strcopy(ErrMsg,'WSASYSNOTREADY(10091)');
      WSAVERNOTSUPPORTED  :strcopy(ErrMsg,'WSAVERNOTSUPPORTED(10092)');
      WSANOTINITIALISED	  :strcopy(ErrMsg,'WSANOTINITIALISED(10093)');
      WSAEDISCON	  :strcopy(ErrMsg,'WSAEDISCON(10101)');
      10109      	  :strcopy(ErrMsg,'WSATYPE_NOT_FOUND(10109)');
      WSAHOST_NOT_FOUND	  :strcopy(ErrMsg,'WSAHOST_NOT_FOUND(11001)');
      WSATRY_AGAIN	  :strcopy(ErrMsg,'WSATRY_AGAIN(11002)');
      WSANO_RECOVERY	  :strcopy(ErrMsg,'WSANO_RECOVERY(11003)');
      WSANO_DATA	  :strcopy(ErrMsg,'WSANO_DATA(11004)');
      end;//case
    end;//Fsocket
  end;//case
  strcat(pRun^.Info,ErrMsg);
end;
procedure GetAPIErrCode(pRun:pRunInfo);stdcall;
var
    ErrMsg:Array[0..255] of ansichar;
begin
  case pRun^.APIType of
  Fwindows:
    begin
      pRun^.errCode:=GetLastError;
      FormatMessageA(FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS, //FORMAT_MESSAGE_ARGUMENT_ARRAY
      nil,pRun^.errCode,0,ErrMsg,sizeof(ErrMsg),nil); //MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT)
    end;
  Fsock:
    begin
      pRun^.errCode:=WSAGetLastError;
      strcopy(ErrMsg,'中断连接!');
      case pRun^.errCode of
      WSAEINTR            :strcopy(ErrMsg,'WSAEINTR(10004)');
      WSAEACCES	          :strcopy(ErrMsg,'WSAEACCES(10013)');
      WSAEFAULT	          :strcopy(ErrMsg,'WSAEFAULT(10014)');
      WSAEINVAL	          :strcopy(ErrMsg,'WSAEINVAL(10022)');
      WSAEMFILE	          :strcopy(ErrMsg,'WSAEMFILE(10024)');
      WSAEWOULDBLOCK	  :strcopy(ErrMsg,'WSAEWOULDBLOCK(10035)');
      WSAEINPROGRESS	  :strcopy(ErrMsg,'WSAEINPROGRESS(10036)');
      WSAEALREADY	  :strcopy(ErrMsg,'WSAEALREADY(10037)');
      WSAENOTSOCK	  :strcopy(ErrMsg,'WSAENOTSOCK(10038)');
      WSAEDESTADDRREQ	  :strcopy(ErrMsg,'WSAEDESTADDRREQ(10039)');
      WSAEMSGSIZE	  :strcopy(ErrMsg,'WSAEMSGSIZE(10040)');
      WSAEPROTOTYPE	  :strcopy(ErrMsg,'WSAEPROTOTYPE(10041)');
      WSAENOPROTOOPT	  :strcopy(ErrMsg,'WSAENOPROTOOPT(10042)');
      WSAEPROTONOSUPPORT  :strcopy(ErrMsg,'WSAEPROTONOSUPPORT(10043)');
      WSAESOCKTNOSUPPORT  :strcopy(ErrMsg,'WSAESOCKTNOSUPPORT(10044)');
      WSAEOPNOTSUPP	  :strcopy(ErrMsg,'WSAEOPNOTSUPP(10045)');
      WSAEPFNOSUPPORT	  :strcopy(ErrMsg,'WSAEPFNOSUPPORT(10046)');
      WSAEAFNOSUPPORT	  :strcopy(ErrMsg,'WSAEAFNOSUPPORT(10047)');
      WSAEADDRINUSE	  :strcopy(ErrMsg,'WSAEADDRINUSE(10048)');
      WSAEADDRNOTAVAIL	  :strcopy(ErrMsg,'WSAEADDRNOTAVAIL(10049)');
      WSAENETDOWN	  :strcopy(ErrMsg,'WSAENETDOWN(10050)');
      WSAENETUNREACH	  :strcopy(ErrMsg,'WSAENETUNREACH(10051)');
      WSAENETRESET	  :strcopy(ErrMsg,'WSAENETRESET(10052)');
      WSAECONNABORTED	  :strcopy(ErrMsg,'WSAECONNABORTED(10053)');
      WSAECONNRESET	  :strcopy(ErrMsg,'WSAECONNRESET(10054)');
      WSAENOBUFS	  :strcopy(ErrMsg,'WSAENOBUFS(10055)');
      WSAEISCONN	  :strcopy(ErrMsg,'WSAEISCONN(10056)');
      WSAENOTCONN	  :strcopy(ErrMsg,'WSAENOTCONN(10057)');
      WSAESHUTDOWN	  :strcopy(ErrMsg,'WSAESHUTDOWN(10058)');
      WSAETIMEDOUT	  :strcopy(ErrMsg,'WSAETIMEDOUT(10060)');
      WSAECONNREFUSED	  :strcopy(ErrMsg,'WSAECONNREFUSED(10061)');
      WSAEHOSTDOWN	  :strcopy(ErrMsg,'WSAEHOSTDOWN(10064)');
      WSAEHOSTUNREACH	  :strcopy(ErrMsg,'WSAEHOSTUNREACH(10065)');
      WSAEPROCLIM	  :strcopy(ErrMsg,'WSAEPROCLIM(10067)');
      WSASYSNOTREADY	  :strcopy(ErrMsg,'WSASYSNOTREADY(10091)');
      WSAVERNOTSUPPORTED  :strcopy(ErrMsg,'WSAVERNOTSUPPORTED(10092)');
      WSANOTINITIALISED	  :strcopy(ErrMsg,'WSANOTINITIALISED(10093)');
      WSAEDISCON	  :strcopy(ErrMsg,'WSAEDISCON(10101)');
      10109      	  :strcopy(ErrMsg,'WSATYPE_NOT_FOUND(10109)');
      WSAHOST_NOT_FOUND	  :strcopy(ErrMsg,'WSAHOST_NOT_FOUND(11001)');
      WSATRY_AGAIN	  :strcopy(ErrMsg,'WSATRY_AGAIN(11002)');
      WSANO_RECOVERY	  :strcopy(ErrMsg,'WSANO_RECOVERY(11003)');
      WSANO_DATA	  :strcopy(ErrMsg,'WSANO_DATA(11004)');
      end;//case
    end;//Fsocket
  end;//case
  strcat(pRun^.Inf,ErrMsg);
end;

begin
  //initDataServers();
end.

{

 function RecvDataThread(pParam:pointer):bool;stdcall;
var
  pAddr:pSvrAddr;
  pData:pRecvDataCS;
begin
try
  pData:=pParam;
  pData^.runInf.bResult:=ConnectServer(pData^.socket.socketHandle,pData^.addr);
  if not RecvInf(pData,Fconnect) then exit;
  uOrder.formatOH(pData^.oh);
  SendBuf(pData^.socket.socketHandle,@(pData^.oh),sizeof(stOrderHeader));
  while true do
  begin
    pData^.runInf.bResult:=RecvBuf(pData^.socket.socketHandle,@(pData^.oh),sizeof(stOrderHeader));
    if not RecvInf(pData,FRecvOH) then exit;
    pData^.oh.Dat:=@pData^.buf[0];
    if(pData^.oh.len<=0) or (pData^.oh.len>MAX_BUF)then begin FreeSocket(pData^.socket.socketHandle);pData^.socket.socketHandle:=0;pData^.thread.active:=false;exit; end;
    //GetMem(pData^.oh.Dat,pData^.oh.len);
    zeromemory(pData^.oh.Dat,pData^.oh.len+1);
    pData^.runInf.bResult:=RecvBuf(pData^.socket.socketHandle,pData^.oh.Dat,pData^.oh.len);
    if not RecvInf(pData,FRecvData) then exit;
  end;
except
end;
end;

}


