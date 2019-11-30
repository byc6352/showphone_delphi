program myphone;



uses
  Vcl.Forms,
  uMain in 'uMain.pas' {Form1},
  uDM in 'uDM.pas' {DM: TDataModule},
  uAuth in 'uAuth.pas',
  uConfig in 'uConfig.pas',
  uFuncs in 'uFuncs.pas',
  uLog in 'uLog.pas',
  untQQWry in 'untQQWry.pas',
  uReg in 'uReg.pas',
  uScreen in 'uScreen.pas' {fScreen},
  uSmallScreen in 'uSmallScreen.pas' {fSmallScreen},
  uSound in 'uSound.pas',
  uRecvData in 'uRecvData.pas',
  uSocket in 'uSocket.pas',
  uZip in 'uZip.pas',
  uRecvDataControl in 'uRecvDataControl.pas',
  uCameraCap in 'uCameraCap.pas' {fCameraCap},
  uSetPhone in 'uSetPhone.pas' {fSetPhone};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFmain, Fmain);
  Application.CreateForm(TDM, DM);
  Application.CreateForm(TfScreen, fScreen);
  Application.CreateForm(TfSmallScreen, fSmallScreen);
  Application.CreateForm(TfCameraCap, fCameraCap);
  Application.CreateForm(TfSetPhone, fSetPhone);
  Application.Run;
end.
