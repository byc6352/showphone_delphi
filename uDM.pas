unit uDM;

interface

uses
  System.SysUtils, System.Classes, System.Win.ScktComp,uOrder,windows,messages;
const
  //wm_user=$0400;
  wm_data=wm_user+100+4;
  MAX_BUF_SIZE=8192;
type
  TFdataMsgFlag=(Forderconnect,FgetUserId,FListPhone,FAddPhone,FDelPhone,FRecvData);
  //数据接收标志:未接收,不可用,接收中,接收完成
  TFrecvFlag=(Fnone,Funavailable,Frecving,FrecvEnd);//数据接收标志


  PRecvDataBuffer=^stRecvDataBuffer;
  stRecvDataBuffer=record   //接收数据缓冲区
    oh:stOrderHeader;
    recvFlag:TFrecvFlag;     //接收标志
    Recved:integer;         //已接收的数据大小
    idle:integer;            //空闲时间
    buf:array[0..MAX_BUF_SIZE-1] of byte;
  end;
  TDM = class(TDataModule)
    csOrder: TClientSocket;
    csData1: TClientSocket;
    csScreen: TClientSocket;
    csCamera: TClientSocket;
    csSound: TClientSocket;
    procedure csOrderConnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure csOrderRead(Sender: TObject; Socket: TCustomWinSocket);
    procedure csData1Read(Sender: TObject; Socket: TCustomWinSocket);
    procedure csData1Connect(Sender: TObject; Socket: TCustomWinSocket);
    procedure csOrderError(Sender: TObject; Socket: TCustomWinSocket;
      ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure csScreenRead(Sender: TObject; Socket: TCustomWinSocket);
    procedure csOrderDisconnect(Sender: TObject; Socket: TCustomWinSocket);
  private
    { Private declarations }

    function RecvData(var Socket: TCustomWinSocket):TFrecvFlag;
    procedure processCmd(poh:POrderHeader);
    function SendReadyOrder(Socket: TCustomWinSocket):integer;

  public
    { Public declarations }
    mUserId:DWORD;                         //用户编号;
    function getUserId():integer;
    procedure ConnectRepeater();                 //连接到转发器
    function SendOrder(order,pid:DWORD):integer;overload;//发送命令（无数据）;
    function SendOrder(order,pid:DWORD;s:string):integer;overload;//发送命令（字符串）;
    function SendOrder(order,pid,data:DWORD):integer;overload;//发送命令（数据int）;
    function SendOrder(order,pid,port,data:DWORD):integer;overload;//发送命令（数据int,端口号）;
    function SendOrder(order,pid,dataSize:DWORD;pdata:pointer):integer;overload;//发送命令（数据块）;
    function SendOrder(order,pid,data1:DWORD;data2:ansiString):integer;overload;//发送命令（数据块）;
    procedure close();
    procedure restartClientSocket(ClientSocket: TClientSocket);
    function getSocketErr(ErrorEvent: TErrorEvent;ErrorCode:integer):string;
  end;

var
  DM: TDM;


implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}
uses
  uAuth,uReg,uConfig,uMain,uLog;


//接收异步数据
function TDM.RecvData(var Socket: TCustomWinSocket):TFrecvFlag;
var
  pBuf:PRecvDataBuffer;
  oh:stOrderHeader;
  ReceiveLength,requestLen,RecvedLen,DataLen:integer; //
  pdata:pointer;
begin
  ReceiveLength:=socket.ReceiveLength;
  pBuf:=nil;
try
  if(ReceiveLength=0)then exit;
  if(ReceiveLength=1)then begin fmain.LogMain('ReceiveLength:1');exit;end;
  if(socket.Data=nil)then
  begin
    socket.ReceiveBuf(oh,sizeof(oh));
    if(not uOrder.VerifyOH(oh))then exit;
    getmem(pBuf,sizeof(stRecvDataBuffer));
    zeromemory(pBuf,sizeof(stRecvDataBuffer));
    pBuf^.oh:=oh;
    socket.Data:=pBuf;
    if (oh.len=0) then
    begin
      pBuf^.recvFlag:=FrecvEnd;
      exit;
    end
    else begin
      pBuf^.recvFlag:=Frecving;
      ReceiveLength:=ReceiveLength-sizeof(oh);
      //getmem(pBuf^.oh.dat,oh.len);
      pBuf^.oh.dat:=@pBuf^.buf[0];
      if(ReceiveLength=0)then exit;
    end;
  end else begin
    pBuf:=socket.Data;
  end;

  if(pBuf^.recvFlag<>Frecving)then
  begin
    socket.ReceiveBuf(oh,sizeof(oh));
    pBuf^.Recved:=0;
    if(not uOrder.VerifyOH(oh))then
    begin
      pBuf^.recvFlag:=Funavailable;
      exit;
    end;
    pBuf^.oh:=oh;

    if(oh.len=0)then
    begin
      pBuf^.recvFlag:=FrecvEnd;
      exit;
    end else begin
      DataLen:=oh.len;
      if DataLen<=ReceiveLength-sizeof(oh) then requestLen:=DataLen else requestLen:=ReceiveLength-sizeof(oh); //要接收的数据；

      zeromemory(@pBuf^.buf[0],MAX_BUF_SIZE);
      RecvedLen:=socket.ReceiveBuf(pBuf^.buf[0],requestLen);
      fMain.LogMain('RecvData0:'+ansiString(pansichar(@pBuf^.buf[0]))+';Recved:'+inttostr(RecvedLen));
      if RecvedLen=-1 then RecvedLen:=0;
      pBuf^.Recved:=RecvedLen;
      if(pBuf^.Recved>=oh.len)then
        pBuf^.recvFlag:=FrecvEnd
      else
        pBuf^.recvFlag:=Frecving;
      exit;
    end;
  end else begin
    RecvedLen:=pBuf^.Recved;
    DataLen:=pBuf^.oh.len;
    if(RecvedLen<DataLen)then
    begin
      if DataLen-RecvedLen<=ReceiveLength then requestLen:=DataLen-RecvedLen else requestLen:=ReceiveLength; //要接收的数据；
      //pdata:=pointer(DWORD(pBuf^.oh.dat)+RecvedLen);
      //pdata:=@pBuf^.buf[RecvedLen];
      //RecvedLen:=socket.ReceiveBuf(pdata^,requestLen);
      fMain.LogMain('RecvData1:RecvedLen:'+inttostr(RecvedLen));
      RecvedLen:=socket.ReceiveBuf(pBuf^.buf[RecvedLen],requestLen);
      fMain.LogMain('RecvData1:'+ansiString(pansiChar(@pBuf^.buf[0]))+';RecvedLen:'+inttostr(RecvedLen));
      if(RecvedLen=-1)then exit;
      pBuf^.Recved:=pBuf^.Recved+RecvedLen;

      if(pBuf^.Recved>=pBuf^.oh.len)then
      begin
        pBuf^.recvFlag:=FrecvEnd;
      end;
    end else begin
        pBuf^.recvFlag:=FrecvEnd;
    end;
  end;
finally
  if pBuf<>nil then
  begin
    pBuf^.idle:=0;
    if(pBuf^.oh.len>0)then
      pBuf^.oh.dat:=@pBuf^.buf[0];
    result:=pBuf^.recvFlag;
  end
  else
    result:=Funavailable;
end;
end;

procedure TDM.restartClientSocket(ClientSocket: TClientSocket);
begin
  if ClientSocket.Active then ClientSocket.Close;
  ClientSocket.Open;
end;
procedure TDM.close();
begin
  if csOrder.Active then
    csOrder.close;
  if csdata1.Active then
    csdata1.close;
  if csScreen.Active then
    csScreen.close;
  if csCamera.Active then
    csCamera.close;
  if csSound.Active then
    csSound.close;
end;
function TDM.SendOrder(order,pid:DWORD):integer;//发送命令（无数据）;
var
  oh:stOrderHeader;
begin
  formatOH(oh);
  oh.id:=mUserId;
  oh.pid:=pid;
  oh.cmd:=order;
  result:=csOrder.socket.SendBuf(oh,sizeof(oh));
end;

function TDM.SendOrder(order,pid:DWORD;s:string):integer;//发送命令（字符串）;
var
  oh:stOrderHeader;
  tmp:ansiString;
begin
  tmp:=ansiString(s);
  formatOH(oh);
  oh.id:=mUserId;
  oh.pid:=pid;
  oh.cmd:=order;
  oh.len:=length(tmp);
  result:=csOrder.socket.SendBuf(oh,sizeof(oh));
  result:=csOrder.socket.SendText(tmp);
end;

function TDM.SendOrder(order,pid,port,data:DWORD):integer;//发送命令（数据int,端口号）;
var
  oh:stOrderHeader;
begin
  formatOH(oh);
  oh.id:=mUserId;
  oh.pid:=pid;
  oh.cmd:=order;
  DWORD(oh.dat):=port;
  oh.len:=sizeof(data);
  result:=csOrder.socket.SendBuf(oh,sizeof(oh));
  result:=csOrder.socket.SendBuf(data,sizeof(data));

end;
function TDM.SendOrder(order,pid,data:DWORD):integer;//发送命令（数据int）;
var
  oh:stOrderHeader;
begin
  formatOH(oh);
  oh.id:=mUserId;
  oh.pid:=pid;
  oh.cmd:=order;
  oh.len:=sizeof(data);
  result:=csOrder.socket.SendBuf(oh,sizeof(oh));
  result:=csOrder.socket.SendBuf(data,sizeof(data));
end;
function TDM.SendOrder(order,pid,data1:DWORD;data2:ansiString):integer;//发送命令（数据块）;
var
  oh:stOrderHeader;
begin
  formatOH(oh);
  oh.id:=mUserId;
  oh.pid:=pid;
  oh.cmd:=order;
  oh.len:=sizeof(data1)+length(data2);
  result:=csOrder.socket.SendBuf(oh,sizeof(oh));

  result:=csOrder.socket.SendBuf((@data1)^,sizeof(data1));
  if(length(data2)>0)then
    result:=csOrder.socket.SendText(data2);
end;

function TDM.SendOrder(order,pid,dataSize:DWORD;pdata:pointer):integer;//发送命令（数据块）;
var
  oh:stOrderHeader;
begin
  formatOH(oh);
  oh.id:=mUserId;
  oh.pid:=pid;
  oh.cmd:=order;
  oh.len:=dataSize;
  result:=csOrder.socket.SendBuf(oh,sizeof(oh));
  result:=csOrder.socket.SendBuf(pdata^,dataSize);
end;
//发送准备好接收数据认证命令；
function TDM.SendReadyOrder(Socket: TCustomWinSocket):integer;
var
  oh:stOrderHeader;
begin
  formatOH(oh);
  result:=Socket.SendBuf(oh,sizeof(oh));
end;

procedure TDM.csData1Connect(Sender: TObject; Socket: TCustomWinSocket);
begin
  SendReadyOrder(Socket);
end;

procedure TDM.csData1Read(Sender: TObject; Socket: TCustomWinSocket);
var
  recvFlag:TFrecvFlag;
  pBuf:PRecvDataBuffer;
  poh:POrderHeader;
begin
  recvFlag:=RecvData(socket);
  if(recvFlag<>FrecvEnd)then exit;
  pBuf:=socket.Data;
  poh:=@pBuf^.oh;
  //getmem(poh,sizeof(stOrderHeader));
  //copymemory(poh,@Buf.oh,sizeof(stOrderHeader));
  SendMessage(Fmain.Handle,wm_data,DWORD(FRecvData),integer(poh));
end;

procedure TDM.csOrderConnect(Sender: TObject; Socket: TCustomWinSocket);
begin
  uorder.id:=getUserId();
  mUserId:=uorder.id;
  postmessage(Fmain.Handle,wm_data,DWORD(Forderconnect),0);
  if(uorder.id>0)then
    postmessage(Fmain.Handle,wm_data,DWORD(FgetUserId),uorder.id);
  fmain.btnConnect.Enabled:=false;
end;

procedure TDM.csOrderDisconnect(Sender: TObject; Socket: TCustomWinSocket);
begin
  fmain.memoOut.Lines.Add(Log('已断开服务器.'));
  fmain.btnConnect.Enabled:=true;
end;

procedure TDM.csOrderError(Sender: TObject; Socket: TCustomWinSocket;
  ErrorEvent: TErrorEvent; var ErrorCode: Integer);
begin
  fmain.memoOut.Lines.Add(Log(getSocketErr(ErrorEvent,ErrorCode)));
  ErrorCode:=0;
end;

procedure TDM.processCmd(poh:POrderHeader);

begin
  case poh^.cmd of
  uOrder.CMD_READY:
    begin
      exit;
    end;
  uOrder.CMD_REQUEST_USER_ID:
    begin
      uorder.id:=poh^.id;
      mUserId:=uorder.id;
      uAuth.SetRegInteger(uAuth.APP_KEY,uAuth.USER_ID_VALUE,uorder.id);
      postmessage(Fmain.Handle,wm_data,DWORD(FgetUserId),uorder.id);
    end;
  uOrder.CMD_LIST_CLIENT:
    begin
      SendMessage(Fmain.Handle,wm_data,DWORD(FListPhone),integer(poh));
    end;
  uOrder.CMD_DEL_CLIENT:
    begin
      SendMessage(Fmain.Handle,wm_data,DWORD(FDelPhone),integer(poh));
    end;
 uOrder.CMD_ADD_CLIENT:
    begin
      SendMessage(Fmain.Handle,wm_data,DWORD(FAddPhone),integer(poh));
      //fmain.addPhone(poh^);
    end;
  end;
end;
procedure TDM.csOrderRead(Sender: TObject; Socket: TCustomWinSocket);
var
  FrecvFlag:TFrecvFlag;
  pBuf:PRecvDataBuffer;
  poh:POrderHeader;
begin
  FrecvFlag:=RecvData(socket);
  if(FrecvFlag<>FrecvEnd)then exit;
  pBuf:=socket.Data;
  poh:=@pBuf^.oh;
  processCmd(poh);
end;


procedure TDM.csScreenRead(Sender: TObject; Socket: TCustomWinSocket);
var
  recvFlag:TFrecvFlag;
  pBuf:PRecvDataBuffer;
  poh:POrderHeader;
begin
  recvFlag:=RecvData(socket);
  if(recvFlag<>FrecvEnd)then exit;
  pBuf:=socket.Data;
  poh:=@pBuf^.oh;
  //getmem(poh,sizeof(stOrderHeader));
  //copymemory(poh,@Buf.oh,sizeof(stOrderHeader));
  SendMessage(Fmain.Handle,wm_data,DWORD(FRecvData),integer(poh));

end;

function TDM.getUserId():integer;
var
  DeviceUid:String;
begin
  result:=uAuth.getReginteger(uAuth.APP_KEY,uAuth.USER_ID_VALUE);
  //result:=1002;
  if(result<=0)then
  begin
    DeviceUid:=uAuth.getRegString(uAuth.APP_KEY,uAuth.DEVICE_ID_VALUE);
    SendOrder(CMD_REQUEST_USER_ID,0,DeviceUid);
  end else begin

  end;
end;
procedure TDM.ConnectRepeater();                 //连接到转发器
begin
  csOrder.Close;
  csOrder.Address:=uConfig.REPEATER_IP;
  csOrder.port:=uConfig.port_order;
  csOrder.Active:=true;
  csData1.Address:=uConfig.REPEATER_IP;
  csData1.port:=uConfig.port_data;
  csScreen.Address:=uConfig.REPEATER_IP;
  csScreen.port:=uConfig.port_Screen;
  csCamera.Address:=uConfig.REPEATER_IP;
  csCamera.port:=uConfig.port_data;
end;

function tdm.getSocketErr(ErrorEvent: TErrorEvent;ErrorCode:integer):string;
var
  sErrorCode,inf,sErrorEvent:string;
begin
  sErrorCode:='错误代码：'+inttostr(ErrorCode);
  if ErrorEvent=eeConnect then
  begin
    sErrorEvent:='连接失败！';
  end;
  if ErrorEvent=eeGeneral then
  begin
    sErrorEvent:='无法识别的错误！';
  end;
  if ErrorEvent=eeSend then
  begin
    sErrorEvent:='发送数据失败！';
  end;
    if ErrorEvent=eeReceive then
  begin
    sErrorEvent:='接受数据失败！';
  end;
    if ErrorEvent=eeDisconnect then
  begin
    //DisCon(socket);

    sErrorEvent:='关闭连接失败！';
  end;
    if ErrorEvent=eeAccept then
  begin
    sErrorEvent:='接受连接失败！';
  end;
  inf:=sErrorEvent+sErrorCode;
  result:=inf;
end;

{

//接收异步数据
function TDM.RecvData(var Socket: TCustomWinSocket):stRecvDataBuffer;
var
  pBuf:PRecvDataBuffer;
  oh:stOrderHeader;
  ReceiveLength,requestLen,RecvedLen,DataLen:integer; //
  pdata:pointer;
begin
  ReceiveLength:=socket.ReceiveLength;
  if(ReceiveLength=0)then exit;
  if(socket.Data=nil)then
  begin
    socket.ReceiveBuf(oh,sizeof(oh));
    if(not uOrder.VerifyOH(oh))then exit;
    if(oh.len=0)then
    begin
      result.dwRecved:=0;
      result.oh:=oh;
      exit;
    end else begin
      DataLen:=oh.len;
      if DataLen<=ReceiveLength-sizeof(oh) then requestLen:=DataLen else requestLen:=ReceiveLength-sizeof(oh); //要接收的数据；
      result.oh:=oh;
      getmem(result.oh.dat,oh.len);
      result.dwRecved:=socket.ReceiveBuf(result.oh.dat^,requestLen);
      if(result.dwRecved>=oh.len)then exit;

      getmem(pBuf,sizeof(stRecvDataBuffer));
      pBuf^.oh:=result.oh;
      pBuf^.dwRecved:=result.dwRecved;
      socket.Data:=pBuf;
    end;
  end else begin
    pBuf:=socket.Data;
    RecvedLen:=pBuf^.dwRecved;
    DataLen:=pBuf^.oh.len;
    if(RecvedLen<DataLen)then
    begin
      if DataLen-RecvedLen<=ReceiveLength then requestLen:=DataLen-RecvedLen else requestLen:=ReceiveLength; //要接收的数据；
      pdata:=pointer(DWORD(pBuf^.oh.dat)+RecvedLen);
      RecvedLen:=socket.ReceiveBuf(pdata^,requestLen);
      pBuf^.dwRecved:=pBuf^.dwRecved+RecvedLen;
      result.oh:=pBuf^.oh;
      result.dwRecved:=pBuf^.dwRecved;
      if(result.dwRecved>=result.oh.len)then
      begin
        freemem(socket.Data);
        socket.Data:=nil;
      end;
    end else begin
      freemem(socket.Data);
      socket.Data:=nil;
    end;
  end;
end;

  PRecvDataBuffer=^stRecvDataBuffer;
  stRecvDataBuffer=record   //接收数据缓冲区
    oh:stOrderHeader;
    recvFlag:TFrecvFlag;     //接收标志
    Recved:integer;         //已接收的数据大小
    dataSize:DWORD;           //缓冲区大小
    data:array of byte;           //数据缓冲区
  end;



//接收异步数据
function TDM.RecvData(var Socket: TCustomWinSocket):TFrecvFlag;
var
  pBuf:PRecvDataBuffer;
  oh:stOrderHeader;
  ReceiveLength,requestLen,RecvedLen,DataLen:integer; //
  pdata:pointer;
begin
  ReceiveLength:=socket.ReceiveLength;
  pBuf:=nil;
try
  if(ReceiveLength=0)then exit;
  if(socket.Data=nil)then
  begin
    socket.ReceiveBuf(oh,sizeof(oh));
    if(not uOrder.VerifyOH(oh))then exit;
    getmem(pBuf,sizeof(stRecvDataBuffer));
    zeromemory(pBuf,sizeof(stRecvDataBuffer));
    pBuf^.oh:=oh;
    socket.Data:=pBuf;
    if (oh.len=0) then
    begin
      pBuf^.recvFlag:=FrecvEnd;
      exit;
    end
    else begin
      pBuf^.recvFlag:=Frecving;
      ReceiveLength:=ReceiveLength-sizeof(oh);
      pBuf^.dataSize:=oh.len;
      setLength(pBuf^.data,pBuf^.dataSize);
      if(ReceiveLength=0)then exit;
    end;
  end else begin
    pBuf:=socket.Data;
  end;


  if(pBuf^.recvFlag<>Frecving)then
  begin
    socket.ReceiveBuf(oh,sizeof(oh));
    if(not uOrder.VerifyOH(oh))then
    begin
      pBuf^.recvFlag:=Funavailable;
      exit;
    end;
    pBuf^.oh:=oh;
    pBuf^.Recved:=0;
    if(oh.len=0)then
    begin
      pBuf^.recvFlag:=FrecvEnd;
      exit;
    end else begin
      DataLen:=oh.len;
      if DataLen<=ReceiveLength-sizeof(oh) then requestLen:=DataLen else requestLen:=ReceiveLength-sizeof(oh); //要接收的数据；
      //getmem(pBuf^.oh.dat,oh.len);
      if(pBuf^.dataSize<>DataLen)then
      begin
        pBuf^.dataSize:=DataLen;
        setLength(pBuf^.data,pBuf^.dataSize);
      end;
      pBuf^.Recved:=socket.ReceiveBuf(pBuf^.data[0],requestLen);
      if(oh.cmd=uOrder.CMD_ADD_CLIENT)then
      begin
        fmain.LogMain(ansiString(pBuf^.data));
      end;
      if(pBuf^.Recved>=oh.len)then
        pBuf^.recvFlag:=FrecvEnd
      else
        pBuf^.recvFlag:=Frecving;
      exit;
    end;
  end else begin
    RecvedLen:=pBuf^.Recved;
    DataLen:=pBuf^.oh.len;
    if(RecvedLen<DataLen)then
    begin
      if DataLen-RecvedLen<=ReceiveLength then requestLen:=DataLen-RecvedLen else requestLen:=ReceiveLength; //要接收的数据；
      //pdata:=pointer(DWORD(@pBuf^.data[0])+RecvedLen);
      //RecvedLen:=socket.ReceiveBuf(pdata^,requestLen);
      RecvedLen:=socket.ReceiveBuf(pBuf^.data[RecvedLen],requestLen);
      if(RecvedLen=-1)then exit;
      pBuf^.Recved:=pBuf^.Recved+RecvedLen;

      if(pBuf^.Recved>=pBuf^.oh.len)then
      begin
        pBuf^.recvFlag:=FrecvEnd;
      end;
    end else begin
        pBuf^.recvFlag:=FrecvEnd;
    end;
  end;
finally
  if pBuf<>nil then
  begin
    result:=pBuf^.recvFlag;
    if(pBuf^.oh.len>0)then pBuf^.oh.dat:=@pBuf^.data[0];
  end
  else
    result:=Funavailable;
end;
end;
}
end.
