unit uConfig;

interface
uses
  Vcl.Forms,System.SysUtils,windows;
const
  APP_NAME='猎豹远程协助手机系统(电脑版)';
  APP_VERSION='4.00';
  WORK_DIR:string='myphone';
  LOG_NAME:string='myphoneLog.txt';
  QQ_WRY:string='QQWry.dat';
  GD_MAP:string='gdmap.htm';
  CONFIG_DAT:string='config.dat'; //配置文件
  JAVA_HOME:string='C:\Program Files\Java\jdk1.8.0_231';

  //REPEATER_IP:ansistring='154.221.19.215';
  //REPEATER_IP:ansistring='127.0.0.1';
  REPEATER_IP:ansistring='103.97.3.61';
  port_order:DWORD=6001;
  port_data:DWORD=6002;
  port_screen:DWORD=6003;
  port_CAMERA:DWORD=6004;
  port_SOUND:DWORD=6005;
  port_FILE:DWORD=6006;
var
  workdir:string;//工作目录
  logfile,QQWryFile,mapFile:string;// 数据库子目录,数据库
  configdat:string;
  isInit:boolean=false;
  procedure init();
implementation
procedure init();
var
    me:String;
begin
  isInit:=true;
  me:=application.ExeName;
  workdir:=extractfiledir(me)+'\'+WORK_DIR;
  if(not DirectoryExists(workdir))then ForceDirectories(workdir);
  configdat:=workdir+'\'+CONFIG_DAT;
  logfile:=workdir+'\'+LOG_NAME;
  QQWryFile:=workdir+'\'+QQ_WRY;
  mapFile:=workdir+'\'+GD_MAP;
end;
begin
  init();
end.
