unit uSetPhone;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls,
  Vcl.Imaging.pngimage, Vcl.Buttons,System.json,ShlObj,shellapi;
const
  VALUE_HOME:string='cb';
  CONFIG_DIR:string='config'; //�����ļ���
  DEX_CFG:string='dex.cfg';  //dex�����ļ�
  RSC_CFG:string='rsc.cfg';  //rsc�����ļ�
  CFG_BAT:string='cfg.bat';  //�������ļ�
  NEW_APK:string='ct_cfg_signed.apk';//���ɵ�apk
  OUT_APK:string='';//
  APP_ICO:string='ic_launcher.png';
  CONFIG_KEY:ansiString='154.221.19.215';
  USER_ID:DWORD=1002;
type
  TfSetPhone = class(TForm)
    GroupBox1: TGroupBox;
    edtAppName: TLabeledEdit;
    edtShow: TLabeledEdit;
    btnOK: TBitBtn;
    btnCancel: TBitBtn;
    GroupBox2: TGroupBox;
    edtServerIp: TLabeledEdit;
    edtServerPort: TLabeledEdit;
    edtKey: TLabeledEdit;
    GroupBox3: TGroupBox;
    edtSaveDir: TLabeledEdit;
    Open1: TOpenDialog;
    btnSaveDir: TBitBtn;
    Save1: TSaveDialog;
    Panel1: TPanel;
    imgAppIcon: TImage;
    Label1: TLabel;
    procedure FormShow(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure imgAppIconClick(Sender: TObject);
    procedure btnSaveDirClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
  private
    { Private declarations }

    procedure LoadCfg(cfgFilename:string);
    procedure LoadDexCfg(cfgFilename:string);
    procedure LoadRscCfg(cfgFilename:string);
    procedure SaveCfg();
    function editJsonValue(json:TJSONObject;key,value:string):boolean;
    procedure SaveJsonData(json:TJSONObject;filename:string);
    function verifyInput():boolean;
  public
    { Public declarations }
    mUserId:DWORD;                         //�û����;
    systmpdir,configdir,configInitialdir,dexcfg,rsccfg,appico,cfgbat,newapk:string;
    mDexJson,mRscJson:TJSONObject; // JSON��
  end;

var
  fSetPhone: TfSetPhone;
  function GetPath(FID: Integer): string;
implementation

{$R *.dfm}
uses
  uConfig,strutils,uFuncs,uzip,aes; // Dephi�Դ���JSON��Ԫ

function TfSetPhone.verifyInput():boolean;
var
  len:integer;
begin
  result:=false;
  len:=length(trim(edtappname.Text));
  if(len<>4)then
  begin
    showmessage('APP���Ʊ���Ϊ4�����֣�');
    exit;
  end;
  len:=length(trim(edtshow.Text));
  if(len<>8)then
  begin
    showmessage('��ʾ��Ϣ����Ϊ8���ַ���');
    exit;
  end;
  result:=true;
end;
procedure TfSetPhone.SaveJsonData(json:TJSONObject;filename:string);
var
  ss:tstrings;
  i:integer;
begin
  try
    ss:=tstringlist.Create;
    ss.Text:=json.ToString;
    ss.Text:=replacestr(ss.Text,',',#44#13#10);
    if(fileexists(filename))then deletefile(filename);
    ss.SaveToFile(filename,TEncoding.UTF8);
  finally
    ss.Free;
  end;
end;
function TfSetPhone.editJsonValue(json:TJSONObject;key,value:string):boolean;
var
  s:string;
begin
  result:=false;
  s:=json.GetValue(key).ToString;
  s:=replacestr(json.GetValue(key).ToString,'"','');
  if(s<>value)then
  begin
    json.RemovePair(key);
    json.AddPair(key,value);
    result:=true;
  end;
end;

procedure TfSetPhone.SaveCfg();
var
  s:string;
  bChange:boolean;
begin
  bChange:=false;
  if(editJsonValue(mDexJson,'pid',inttostr(mUserId)))then bChange:=true;
  if(editJsonValue(mDexJson,'cip',trim(edtServerIp.Text)))then bChange:=true;
  if(editJsonValue(mDexJson,'cport',trim(edtServerPort.Text)))then bChange:=true;
  if(editJsonValue(mDexJson,'pwd',trim(edtKey.Text)))then bChange:=true;
  if bChange then
   SaveJsonData(mDexJson,dexcfg);
  bChange:=false;
  if(editJsonValue(mRscJson,'ϵͳ����',trim(edtAppname.Text)))then bChange:=true;
  if(editJsonValue(mRscJson,'������ϵͳ����',trim(edtshow.Text)))then bChange:=true;
  if bChange then
   SaveJsonData(mRscJson,Rsccfg);
end;
procedure TfSetPhone.LoadDexCfg(cfgFilename:string);
var
  ss:tstrings;
begin
  try
    ss:=tstringlist.Create;
    ss.LoadFromFile(cfgFilename,TEncoding.UTF8);
    //System.JSON.TJsonObject.LoadFromFile(FileName).AsJsonObject;
    mDexJson := TJSONObject.ParseJSONValue(ss.Text) as TJSONObject;
    edtServerIp.Text:=replacestr(mDexJson.GetValue('cip').ToString,'"','');
    edtServerPort.Text:=mDexJson.GetValue('cport').ToString;
  finally
    ss.Free;
    //JSONObject.Free;
  end;
end;
procedure TfSetPhone.LoadRscCfg(cfgFilename:string);
var
  ss:tstrings;
begin
  try
    ss:=tstringlist.Create;
    ss.LoadFromFile(cfgFilename,TEncoding.UTF8);
    mRscJson := TJSONObject.ParseJSONValue(ss.Text) as TJSONObject;
    edtAppName.Text:=replacestr(mRscJson.GetValue('ϵͳ����').ToString,'"','');
    edtShow.Text:=replacestr(mRscJson.GetValue('������ϵͳ����').ToString,'"','');
  finally
    ss.Free;
    //JSONObject.Free;
  end;

end;

procedure TfSetPhone.btnCancelClick(Sender: TObject);
begin
  close;
end;

procedure TfSetPhone.btnOKClick(Sender: TObject);
var
  outapk:string;
begin
  if(not verifyInput())then exit;
  saveCfg();
  ShellExecute(Handle, pchar('open'), PChar(fsetphone.cfgbat), nil, pchar(extractfiledir(fsetphone.cfgbat)), SW_SHOW);
  sleep(3000);
  outapk:=trim(edtSavedir.Text);
  if(fileexists(newapk))then
  begin
    copyfile(pchar(newapk),pchar(outapk),false);
    ShellExecute(Handle,pchar('open'), pchar('explorer.exe'), pchar('/select,'+outapk), nil, SW_SHOW);
    deletefile(newapk);
    deletefile(configdir+'\ct_cfg.apk');
    uFuncs.deldir(configdir+'\ct');
    uzip.DirectoryCompression(configdir,systmpdir+'\tmp.tmp');
    aes.EncryptFile(systmpdir+'\tmp.tmp',systmpdir+'\'+uConfig.CONFIG_DAT,CONFIG_KEY);
  end;

  uFuncs.deldir(configdir);
  uFuncs.deldir(systmpdir+'\tmp.tmp');
  close();
end;

procedure TfSetPhone.btnSaveDirClick(Sender: TObject);
var
  filename:string;
begin
  if(save1.Execute())then
  begin
    filename:=save1.FileName;
    edtSaveDir.Text:=filename;
  end;
end;

procedure TfSetPhone.FormCreate(Sender: TObject);

begin
  mUserId:=USER_ID;                         //�û����;
  systmpdir:=GetPath(CSIDL_COMMON_TEMPLATES)+'\'+WORK_DIR;
  if(not DirectoryExists(systmpdir))then ForceDirectories(systmpdir);
  configdir:=systmpdir+'\'+CONFIG_DIR;
  dexcfg:=configdir+'\'+DEX_CFG;
  rsccfg:=configdir+'\'+RSC_CFG;
  appico:=configdir+'\'+APP_ICO;
  cfgbat:=configdir+'\'+CFG_BAT;
  newapk:=configdir+'\'+NEW_APK;
  SetMyGlobalEnvironment('JAVA_HOME',JAVA_HOME);
  SetMyGlobalEnvironment(VALUE_HOME,configdir);
end;

procedure TfSetPhone.FormShow(Sender: TObject);
var
  tmpfile,tmpfile2:string;
begin
try
  tmpfile:=systmpdir+'\'+uConfig.CONFIG_DAT;
  if(not fileexists(tmpfile))then
  begin
    if(not fileexists(uConfig.configdat))then
    begin
      showmessage('ȱʧ�����ļ�:'+uConfig.CONFIG_DAT);
      close;
    end else begin
      tmpfile:=uConfig.configdat;
    end;
  end;
  tmpfile2:=systmpdir+'\tmp.tmp';
  if(fileexists(tmpfile2))then deletefile(tmpfile2);
  aes.DecryptFile(tmpfile,tmpfile2,CONFIG_KEY);
  {
  if(not aes.DecryptFile(uConfig.configdat,tmpfile,uConfig.CONFIG_KEY))then
  begin
    showmessage('�����ļ�����:'+uConfig.CONFIG_DAT);
    close;
  end;
  }
  if(directoryexists(configdir))then  uFuncs.deldir(configdir);

  if(DirectoryDecompression(configdir,tmpfile2)=0)then
  begin
    showmessage('�����ļ�����tmpfile2:'+uConfig.CONFIG_DAT);
    close;
  end;
  if(fileexists(tmpfile2))then deletefile(tmpfile2);
  LoadDexCfg(dexcfg);
  LoadRscCfg(rsccfg);
  imgAppicon.Picture.LoadFromFile(appico);
finally

end;
end;

procedure TfSetPhone.imgAppIconClick(Sender: TObject);
var
  filename:string;
  w,h:integer;
begin
  if(open1.Execute())then
  begin
    filename:=open1.FileName;
    imgAppicon.Picture.LoadFromFile(filename);
    w:=imgAppicon.Picture.Width;
    h:=imgAppicon.Picture.Height;
    if(w<>72)or(h<>72)then
    begin
      showmessage('�����Ǹ�Ϊ72��Ϊ72���ص�pngͼƬ��');
      exit;
    end;
    copyfile(pchar(filename),pchar(appico),false);
    imgAppicon.Picture.LoadFromFile(appico);
  end;
end;

procedure TfSetPhone.LoadCfg(cfgFilename:string);
var
  tf:TextFile;
  tmp:string;
begin
  AssignFile(tf,cfgFilename);
  if(not fileexists(cfgFilename))then exit;
  reset(tf);
  readln(tf,tmp);
  edtAppName.Text:=tmp;
  readln(tf,tmp);
  edtShow.Text:=tmp;
  readln(tf,tmp);
  edtKey.Text:=tmp;
  readln(tf,tmp);
  edtServerIp.Text:=tmp;
  readln(tf,tmp);
  edtServerPort.Text:=tmp;
  closefile(tf);
end;

function GetPath(FID: Integer): string;
var
  pidl: PItemIDList;
  path: array[0..MAX_PATH] of Char;
begin
  SHGetSpecialFolderLocation(0, FID, pidl);
  SHGetPathFromIDList(pidl, path);
  Result := path;
end;
end.