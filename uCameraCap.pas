unit uCameraCap;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, ExtCtrls, ScktComp, ComCtrls,Jpeg,uSound;

type
  TfCameraCap = class(TForm)
    Panel1: TPanel;
    btnStart: TSpeedButton;
    btnSinglePic: TSpeedButton;
    edtQuality: TEdit;
    Label1: TLabel;
    StatusBar1: TStatusBar;
    btnSound: TSpeedButton;
    Panel2: TPanel;
    imgCamera: TImage;
    procedure btnStartClick(Sender: TObject);
    procedure btnSinglePicClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormDestroy(Sender: TObject);
    procedure btnSoundClick(Sender: TObject);
  private
    { Private declarations }
     stream:tMemoryStream;
     jpg: TJPEGImage; // 要use Jpeg单元

    function getParams(Sender: TObject):DWORD;
  public
    { Public declarations }
    mReturnCamera,mReturnSound:boolean;//是否有数据返回
    procedure updateImage(pData:pointer;len:integer);
  end;

var
  fCameraCap: TfCameraCap;

implementation

uses uDM,uMain,uOrder,uRecvDataControl;

{$R *.dfm}

function TfCameraCap.getParams(Sender: TObject):DWORD;
var
  singlePic:DWORD;
  quality:DWORD;
begin
  singlePic:=0;
  if((Sender   as   TSpeedButton).Caption='单帧')then
    singlePic:=1;
  quality:=strtoint(edtQuality.text);
  if(quality<10)then quality:=20;
  if(quality>100)then quality:=100;
  result:=quality*10+singlePic;
end;
procedure TfCameraCap.btnStartClick(Sender: TObject);
var
  param:DWORD;
  phoneId:DWORD;
begin
  phoneId:=fmain.selectPhone();
  if(phoneId=0)then exit;

  if(btnStart.Caption='开始')then begin
     param:=getParams(sender);
     dm.SendOrder(CMD_CAMERA_CAP_START,phoneId,param);
     btnStart.Caption:='停止';
     btnSinglePic.Enabled:=false;
     mReturnCamera:=false;
     if(uRecvDataControl.StartRecvDataThread(CMD_CAMERA_CAP_START)=false)then exit;
  end else begin
    if(mReturnCamera=true)then
      dm.SendOrder(CMD_CAMERA_CAP_END,phoneId);
     btnStart.Caption:='开始';
     btnSinglePic.Enabled:=true;
   end;
end;

procedure TfCameraCap.btnSinglePicClick(Sender: TObject);
var
  socket:TCustomWinSocket;
   param:DWORD;
  phoneId:DWORD;
begin
  phoneId:=fmain.selectPhone();
  if(phoneId=0)then exit;
  //dm.csCamera.open;
  param:=getParams(sender);
  dm.SendOrder(CMD_CAMERA_CAP_START,phoneId,param);

end;
procedure TfCameraCap.updateImage(pData:pointer;len:integer);
begin
try
  stream.Clear;
  stream.Write(pData^,len);
  stream.Position:=0;
  jpg.LoadFromStream(stream);
  imgCamera.Picture.Graphic:=jpg;
  //imgCamera.Picture.Bitmap.Assign(jpg); // 因为 img 控件是基于bmp的
  imgCamera.Update;
  mReturnCamera:=true;
finally
  stream.Clear;

end;

end;
procedure TfCameraCap.FormShow(Sender: TObject);
begin
//self.FormStyle:=fsStayOnTop;
  stream:=tMemoryStream.Create;
  jpg := TJPEGImage.Create;
end;

procedure TfCameraCap.FormClose(Sender: TObject; var Action: TCloseAction);
begin
   if(btnStart.Caption='停止')then
     btnStart.OnClick(nil);
end;

procedure TfCameraCap.FormDestroy(Sender: TObject);
begin
  jpg.Free;
  stream.Free;
end;

procedure TfCameraCap.btnSoundClick(Sender: TObject);
var

  phoneId:DWORD;
begin
  phoneId:=fmain.selectPhone();
  if(phoneId=0)then exit;

  if(btnSound.Caption='拾音')then begin
     dm.SendOrder(CMD_SOUND_CAP_START,phoneId);
     btnSound.Caption:='停止';
     if(uRecvDataControl.StartRecvDataThread(CMD_SOUND_CAP_START)=false)then exit;
     mReturnSound:=false;
  end else begin
    if(mReturnSound)then
      dm.SendOrder(CMD_SOUND_CAP_END,phoneId);
     btnSound.Caption:='拾音';
  end;
end;

end.
