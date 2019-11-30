unit uSound;

interface
 uses
  WINDOWS,DirectSound, MMSystem,classes,ActiveX;
const
  WAV_SAMPLE_RATE=44100;	//PCM sample rate
  WAV_CHANNEL_NUMBER=1;			//PCM channel number
  WAV_BITS_PER_SAMPLE=8;	//bits per sample
  MAX_AUDIO_BUF=1;
  //BUFFER_NOTIFY_SIZE=192000;
  BUFFER_NOTIFY_SIZE=441000;
  //BUFFER_NOTIFY_SIZE=132300;
type
  pSoundControl=^stSoundControl;
  stSoundControl=record
    isNewData:bool;//新数据来到吗
    dataSize:integer;//数据大小
    pdata:pointer;//数据指针；
    data:array of byte;   //临时数据缓冲
  end;
  TSound = class(TThread)  //socket数据处理类
  private
    mhForm:HWND;
    mDSound: IDirectSound8;
    mDSoundBuf: IDirectSoundBuffer; //缓冲区对象
    mDSoundBuf8:IDirectSoundBuffer8;
    hr:HRESULT;
    mBufDesc: TDSBufferDesc;   //建立缓冲区需要的结构
    mWavFormat: TWaveFormatEx; //从 Wave 中提取的结构
    mBufferSize:DWORD;
    sc:stSoundControl;
    mDPosNotifys:array[0..MAX_AUDIO_BUF-1] of DSBPOSITIONNOTIFY;//DSBPOSITIONNOTIFY m_pDSPosNotify[MAX_AUDIO_BUF];
    mEvents:array[0..MAX_AUDIO_BUF-1] of thandle;//HANDLE m_event[MAX_AUDIO_BUF];
    mStream:tMemoryStream;

    procedure Log(msg:string);
    procedure GetWaveFmtDefault();  //构造TWaveFormatEx 结构的函数
    procedure GetWaveFmtFromParam(rate,channels,bits:integer);  //构造TWaveFormatEx 结构的函数
    function GetWaveFmtFromFile(FilePath: string): Boolean;
    function GetWaveData(FilePath: string): Boolean; {从 Wave 文件中获取波形数据的函数}
    procedure GetBufDesc();//填充建立缓冲区需要的结构
    procedure GetBuf();//建立缓冲区

    procedure fillWhiteNoice(p:pointer;size:integer);
  protected
    procedure Execute; override;
  public
    constructor Create(hForm:HWND); overload;
    destructor Destroy;
    class function getInstance(hForm:HWND):TSound;
    procedure writeBuf(p:pointer;size:integer);overload;//写缓冲区
    procedure writeBuf(p:pointer;size:integer;bCreate:boolean);overload;//写缓冲区 bCreate:是否建立临时缓冲区;
    procedure PlayDefault();
    procedure playWavFile(filename:string); //填充白噪声
    procedure playPCMfile(filename:string;rate,channels,bits:integer);//;播放本地文件
  end;


var

  sound:TSound;
implementation

constructor TSound.Create(hForm:HWND);
begin
  inherited Create(true); //程序开始时挂起线程；
  mhForm:=hForm;
  //if(hr<>S_OK)then begin Log('CoInitializeEx false.');exit;end;
  hr:=DirectSoundCreate8(nil, mDSound, nil); {建立设备对象, 并设置写作优先级}
  if(hr<>S_OK)then begin Log('DirectSoundCreate8 false.');exit;end;
  hr:=mDSound.SetCooperativeLevel(hForm, DSSCL_NORMAL); {若手动建立主缓冲, 设备的优先级至少要指定为 DSSCL_PRIORITY}
  if(hr<>S_OK)then  begin Log('SetCooperativeLevel false.');exit;end;
  mStream := TMemoryStream.Create;
  zeromemory(@sc,sizeof(stSoundControl));
end;
destructor TSound.Destroy;
begin
  //if(mDSoundBuf8<>nil)then mDSoundBuf8.Stop;
  mDSoundBuf8:=nil;
  mDSoundBuf := nil;
  mDSound := nil;
  mStream.Free;
  sc.data:=nil;
end;

class function TSound.getInstance(hForm:HWND):TSound;
begin
  if not assigned(sound) then
     sound:=TSound.Create(hForm);
  result:=sound;
end;

procedure TSound.Log(msg:string);
begin

end;

//构造默认TWaveFormatEx 结构的函数
procedure TSound.GetWaveFmtDefault();
begin
  GetWaveFmtFromParam(WAV_SAMPLE_RATE,WAV_CHANNEL_NUMBER,WAV_BITS_PER_SAMPLE);
end;
{从 Wave 文件中获取 TWaveFormatEx 结构的函数}
function TSound.GetWaveFmtFromFile(FilePath: string): Boolean;
var
  hFile: HMMIO;
  ckiRIFF,ckiFmt: TMMCKInfo;
begin
  Result := False;
  hFile := mmioOpenA(PansiChar(ansiString(FilePath)), nil, MMIO_READ);
  if hFile = 0 then Exit;
  ZeroMemory(@ckiRIFF, SizeOf(TMMCKInfo));
  ZeroMemory(@ckiFmt, SizeOf(TMMCKInfo));
  ZeroMemory(@mWavFormat, SizeOf(TWaveFormatEx));
  ckiFmt.ckid := mmioStringToFOURCC('fmt', 0);
  mmioDescend(hFile, @ckiRIFF, nil, MMIO_FINDRIFF);
  if (ckiRIFF.ckid = FOURCC_RIFF) and
     (ckiRIFF.fccType = mmioStringToFOURCC('WAVE',0)) and
     (mmioDescend(hFile, @ckiFmt, @ckiRIFF, MMIO_FINDCHUNK) = MMSYSERR_NOERROR) then
     Result := (mmioRead(hFile, @mWavFormat, ckiFmt.cksize) = ckiFmt.cksize);
  mmioClose(hFile, 0);
end;

procedure TSound.GetWaveFmtFromParam(rate,channels,bits:integer);  //构造TWaveFormatEx 结构的函数
begin
  with mWavFormat do
  begin
    wFormatTag:=WAVE_FORMAT_PCM; // format type */
    nChannels:=channels; //number of channels (i.e. mono, stereo...)
    nSamplesPerSec:=rate; //sample rate */
    nAvgBytesPerSec:=rate*(bits div 8)*channels;
    nBlockAlign:=bits div 8*channels; //for buffer estimation
    wBitsPerSample:=bits;//block size of data */
    cbSize:=0;//* number of bits per sample of mono data */
  end;
end;

{从 Wave 文件中获取波形数据的函数}
function TSound.GetWaveData(FilePath: string): Boolean;
var
  hFile: HMMIO;
  ckiRIFF,ckiData: TMMCKInfo;
begin
  Result := False;
  hFile := mmioOpenA(PansiChar(ansiString(FilePath)), nil, MMIO_READ);
  if hFile = 0 then Exit;
  ZeroMemory(@ckiRIFF, SizeOf(TMMCKInfo));
  ZeroMemory(@ckiData, SizeOf(TMMCKInfo));
  ckiData.ckid := mmioStringToFOURCC('data', 0);
  mmioDescend(hFile, @ckiRIFF, nil, MMIO_FINDRIFF);
  if (ckiRIFF.ckid = FOURCC_RIFF) and
     (ckiRIFF.fccType = mmioStringToFOURCC('WAVE',0)) and
     (mmioDescend(hFile, @ckiData, @ckiRIFF, MMIO_FINDCHUNK) = MMSYSERR_NOERROR) then
    begin
      mstream.Size := ckiData.cksize;
      Result := (mmioRead(hFile, mstream.Memory, ckiData.cksize) = ckiData.cksize);
    end;
  mmioClose(hFile, 0);
end;

procedure TSound.GetBufDesc();//填充建立缓冲区需要的结构
begin
  ZeroMemory(@mBufDesc, SizeOf(TDSBufferDesc));
  mBufDesc.dwSize := SizeOf(TDSBufferDesc);
  //bufDesc.dwFlags := DSBCAPS_STATIC;     //指定使用静态缓冲区  DSBCAPS_CTRLVOLUME or DSBCAPS_CTRLPAN or DSBCAPS_CTRLFREQUENCY;
  //缓冲区具有位置通知能力,使 GetCurrentPosition 能获取更精确的播放位置,缓冲区具有音量控制能力,缓冲区具有相位控制能力,缓冲区具有频率控制能力
  mBufDesc.dwFlags := DSBCAPS_GLOBALFOCUS or DSBCAPS_CTRLPOSITIONNOTIFY or DSBCAPS_GETCURRENTPOSITION2 or DSBCAPS_CTRLVOLUME or DSBCAPS_CTRLPAN or DSBCAPS_CTRLFREQUENCY;     //
  mBufferSize:=BUFFER_NOTIFY_SIZE*MAX_AUDIO_BUF;
  mBufDesc.dwBufferBytes :=mBufferSize; //数据大小 MAX_AUDIO_BUF*BUFFER_NOTIFY_SIZE;
  mBufDesc.lpwfxFormat := @mWavFormat;     //数据格式
end;

procedure TSound.GetBuf();//填充建立缓冲区需要的结构
var
  DSoundNotify:IDirectSoundNotify8;
  i,playingSize:integer;
begin
 {建立缓冲区}
  hr:=mDSound.CreateSoundBuffer(mBufDesc, mDSoundBuf, nil);
  if(hr<>S_OK)then begin Log('CreateSoundBuffer false.');exit;end;

  hr:=mDSoundBuf.QueryInterface(IID_IDirectSoundBuffer8,mDSoundBuf8);
  if(hr<>S_OK)then begin Log('IID_IDirectSoundBuffer8 false.');exit;end;

  mDSoundBuf8.QueryInterface(IID_IDirectSoundNotify,DSoundNotify);  //Get IDirectSoundNotify8
  if(hr<>S_OK)then begin Log('IID_IDirectSoundNotify false.');exit;end;
  if(sc.dataSize>mBufferSize)then playingSize:=mBufferSize else playingSize:=sc.dataSize;
  for i :=0 to MAX_AUDIO_BUF-1 do begin //
    mDPosNotifys[i].dwOffset :=(i+1)*playingSize-1;//m_pDSPosNotify[i].dwOffset =i*BUFFERNOTIFYSIZE;
    mevents[i]:=CreateEvent(nil,false,false,nil);//m_event[i]=::CreateEvent(NULL,false,false,NULL);
    mDPosNotifys[i].hEventNotify:=mevents[i];//m_pDSPosNotify[i].hEventNotify=m_event[i];
  end;
  DSoundNotify.SetNotificationPositions(MAX_AUDIO_BUF,@mDPosNotifys[0]);//m_pDSNotify->SetNotificationPositions(MAX_AUDIO_BUF,m_pDSPosNotify);
  DSoundNotify._Release();//m_pDSNotify->Release();
  //Start Playing
  mDSoundBuf8.SetCurrentPosition(0);
  mDSoundBuf8.SetVolume(0);
end;

procedure TSound.Execute;
var
  res:DWORD;
  p1,p2: Pointer;              //从缓冲区获取的写指针
  n1,n2: DWORD;                //要写入缓冲区的数据大小
  dataSize,playingSize,playedSize:DWORD;             //数据大小,要播放大小,已播放的大小
  p:pointer;
begin
  FreeOnTerminate:=True; {加上这句线程用完了会自动注释}

  while (not Terminated) do
  begin
    mDSoundBuf8.Play(0,0,DSBPLAY_LOOPING);//m_pDSBuffer8->Play(0,0,DSBPLAY_LOOPING);
    res:=WAIT_OBJECT_0;
    if(res >=WAIT_OBJECT_0)then begin    //if((res >=WAIT_OBJECT_0)&&(res <=WAIT_OBJECT_0+3))begin
      if(sc.isNewData=false)then
      begin //等待数据
        mDSoundBuf8.Stop;
        self.Suspend;

      end else begin
        dataSize:=sc.dataSize;
        playedSize:=0;
        while dataSize>0 do
        begin
          if(dataSize>mBufferSize)then playingSize:=mBufferSize else playingSize:=dataSize;
          hr:=mDSoundBuf8.Lock(0,playingSize,@p1,@n1,nil,nil,DSBLOCK_ENTIREBUFFER);
          if(hr<>S_OK)then begin Log('Lock false.');exit;end;
          p:=pointer(DWORD(sc.pdata)+playedSize);
          copymemory(p1,P,playingSize);
          sc.isNewData:=false;
          mDSoundBuf8.Unlock(p1,n1,nil,0);
          playedSize:=playedSize+playingSize;
          dataSize:=dataSize-playingSize;
          res := WaitForMultipleObjects (MAX_AUDIO_BUF, @mEvents[0], false, INFINITE);
        end;
      end;//
    end;

  end;
end;

//写缓冲区
procedure TSound.writeBuf(p:pointer;size:integer);
begin
  if(size<=0)then exit;
  sc.isNewData:=true;
  sc.pdata:=p;
  sc.dataSize:=size;
  if(self.Suspended=true)then self.Resume;
end;

//写缓冲区 bCreate:是否建立临时缓冲区;
procedure TSound.writeBuf(p:pointer;size:integer;bCreate:boolean);
begin
  if(size<=0)then exit;
  if(bCreate)then
  begin
    if(size<>length(sc.data))then
      setlength(sc.data,size);
    copymemory(@sc.data[0],p,size);
    writeBuf(@sc.data[0],size);
  end else begin
    writeBuf(p,size);
  end;
end;

procedure TSound.PlayDefault();
begin
  GetWaveFmtDefault();
  GetBufDesc();
  sc.dataSize:=mBufferSize;
  GetBuf();
end;

//播放本地文件
procedure TSound.playWavFile(filename:string);
begin
  if not GetWaveFmtFromFile(filename) then Exit;
  mstream.Clear;
  if not GetWaveData(filename) then begin Exit; end;
  mstream.Position:=0;
  sc.pData:=mstream.Memory;
  sc.dataSize:=mstream.Size;
  GetBufDesc();
  GetBuf();
  writeBuf(sc.pData,sc.dataSize);
end;

//播放本地文件
procedure TSound.playPCMfile(filename:string;rate,channels,bits:integer);
begin
  getwaveFmtFromParam(rate,channels,bits);
  mstream.Clear;
  mstream.LoadFromFile(filename);
  mstream.Position:=0;
  sc.pData:=mstream.Memory;
  sc.dataSize:=mstream.Size;
  GetBufDesc();
  GetBuf();
  writeBuf(sc.pData,sc.dataSize);

end;

//填充白噪声
procedure TSound.fillWhiteNoice(p:pointer;size:integer);
var
  pb:PBYTE;
  i:integer;
begin
  pb:=PBYTE(p);
  for i:=0 to size-1 do
  begin
    Randomize;
    pb^:=Random(254)-Random(254);
    inc(pb);
  end;
end;




initialization
  CoInitializeEx(nil,COINIT_MULTITHREADED);
finalization
  CoUninitialize;
end.
