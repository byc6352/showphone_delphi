unit uScreen;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, ExtCtrls,umain, ScktComp , DateUtils,uOrder,uFuncs, OleCtrls, SHDocVw,MSHTML,Jpeg,ShellApi,StrUtils
  ,uCameraCap,untQQWry,uDM, Menus, ComCtrls, ImgList; //uRecvData

type
pTposition=^Tposition;
  Tposition=record
    dX:DWORD;//大小；
    dY:DWORD;//大小；
end;
pTpath=^Tpath;
  Tpath=record
    x1:DWORD;//大小；
    y1:DWORD;//大小；
    x2:DWORD;//大小；
    y2:DWORD;//大小；
end;

  TfScreen = class(TForm)
    Panel6: TPanel;
    btnRecordScreen: TSpeedButton;
    btnInput: TSpeedButton;
    btnLight: TSpeedButton;
    Label6: TLabel;
    btnHome: TSpeedButton;
    btnReturn: TSpeedButton;
    chkSeriShot: TCheckBox;
    btnShotSeriesScreen: TButton;
    btnshot: TButton;
    edtVtKey: TEdit;
    ckSlide: TCheckBox;
    chkLongClick: TCheckBox;
    ScrollBox1: TScrollBox;
    imgScreen: TImage;
    procedure btnHomeClick(Sender: TObject);
    procedure btnReturnClick(Sender: TObject);
    procedure btnLightClick(Sender: TObject);
    procedure btnRecordScreenClick(Sender: TObject);

    procedure btnshotClick(Sender: TObject);
    procedure btnInputClick(Sender: TObject);
    procedure imgScreenMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure imgScreenMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure imgScreenMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure btnShotSeriesScreenClick(Sender: TObject);
  private
    { Private declarations }
    mSlidePath:tPath;
  public
    { Public declarations }
  end;

var
  fScreen: TfScreen;

implementation

{$R *.dfm}
uses
  uConfig,uRecvDataControl;

procedure TfScreen.btnHomeClick(Sender: TObject);
var
  phoneId:DWORD;
begin
  phoneId:=fmain.selectPhone();
  if(phoneId=0)then exit;
  dm.SendOrder(CMD_HOME,phoneId);
end;
//fmain.
procedure TfScreen.btnReturnClick(Sender: TObject);
var
  phoneId:DWORD;
begin
  phoneId:=fmain.selectPhone();
  if(phoneId=0)then exit;
  dm.SendOrder(CMD_RETURN,phoneId);

end;

procedure TfScreen.btnLightClick(Sender: TObject);
var
  phoneId:DWORD;
begin
  phoneId:=fmain.selectPhone();
  if(phoneId=0)then exit;
  dm.SendOrder(CMD_LIGHT,phoneId);

end;

procedure TfScreen.btnRecordScreenClick(Sender: TObject);
var
  phoneId:DWORD;
begin
  phoneId:=fmain.selectPhone();
  if(phoneId=0)then exit;
  if(btnRecordScreen.Caption='录屏')then begin
    dm.SendOrder(CMD_RECORD_SCREEN_START,phoneId);
    btnRecordScreen.Caption:='停录';
  end else begin
    dm.SendOrder(CMD_RECORD_SCREEN_END,phoneId);
    btnRecordScreen.Caption:='录屏';
  end;

end;

procedure TfScreen.btnshotClick(Sender: TObject);
var
  data:DWORD;
  phoneId:DWORD;
begin
  phoneId:=fmain.selectPhone();
  if(phoneId=0)then exit;
  //dm.csScreen.Open;

  data:=0;
  dm.SendOrder(CMD_SHOT,phoneId,data);
  if(uRecvDataControl.StartRecvDataThread(CMD_SHOT)=false)then exit;
end;

procedure TfScreen.btnInputClick(Sender: TObject);
var
   txt:ansistring;
  phoneId:DWORD;
begin
  phoneId:=fmain.selectPhone();
  if(phoneId=0)then exit;
  txt:=trim(edtVtKey.Text);
  dm.SendOrder(CMD_INPUT,phoneId,txt);
end;

procedure TfScreen.imgScreenMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  pos:tPosition;
  phoneId:DWORD;
begin
  phoneId:=fmain.selectPhone();
  if(phoneId=0)then exit;

   pos.dX:=x;
   pos.dY:=y;
   mSlidePath.x1:=x;
   mSlidePath.y1:=y;
   if(ckSlide.Checked=true)then exit;
   if(chkLongClick.Checked)then
      dm.SendOrder(CMD_INPUT,phoneId,sizeof(pos),@pos)
   else
      dm.SendOrder(CMD_POS,phoneId,sizeof(pos),@pos);

end;

procedure TfScreen.imgScreenMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin
  fMain.bar1.Panels[3].Text:='X:'+inttostr(x)+',Y:'+inttostr(y);
end;

procedure TfScreen.imgScreenMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  moveEndPos:tPosition;
  phoneId:DWORD;
begin
  phoneId:=fmain.selectPhone();
  if(phoneId=0)then exit;
  mSlidePath.x2:=x;
  mSlidePath.y2:=y;
  dm.SendOrder(CMD_SLIDE,phoneId,sizeof(mSlidePath),@mSlidePath);
end;

procedure TfScreen.btnShotSeriesScreenClick(Sender: TObject);
var
  data:DWORD;
  phoneId:DWORD;
begin
  phoneId:=fmain.selectPhone();
  if(phoneId=0)then exit;
  if(btnShotSeriesScreen.Caption='屏控')then begin
    data:=1;
    //dm.csScreen.Open;
    btnShotSeriesScreen.Caption:='停止';
    dm.SendOrder(CMD_SHOT,phoneId,data);
    if(uRecvDataControl.StartRecvDataThread(CMD_SHOT)=false)then exit;
  end else begin
    data:=2;
    btnShotSeriesScreen.Caption:='屏控';
    dm.SendOrder(CMD_SHOT,phoneId,data);
  end;

end;

end.
