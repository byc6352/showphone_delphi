unit untqqwry;

interface

uses
  SysUtils, Classes, Controls, Math, Dialogs;

type
  TQQWry = class(TObject)
    public
      constructor Create(cQQWryFileName: string);
      destructor Destroy; override;
      function GetQQWryFileName: string;
      function GetQQWryFileSize: Cardinal;
      function GetIPRecordNum: Cardinal;
      //function GetQQWryDate: TDate;
      function GetQQWryDate: String;
      function GetQQWryDataFrom: string;
      function GetIPLocation(IPLocationOffset: Cardinal): TStringlist;
      function GetIPMsg(IPRecordID: Cardinal): TStringlist;
      function GetIPRecordID(IP: string): Cardinal;
      function GetIPValue(IP: string): Cardinal;
    private
      QQWryFileName: string;
      QQWryFileStream: TFileStream;
      QQWryFileSize: Cardinal;
      IPRecordNum: Cardinal;
      FirstIPIndexOffset, LastIPIndexOffset: Cardinal;
  end;

implementation

//
constructor TQQWry.Create(cQQWryFileName: string);
begin
  inherited Create;
  QQWryFileName:=cQQWryFileName;
  QQWryFileStream:=TFileStream.Create(QQWryFileName, fmOpenRead or fmShareDenyWrite, 0);
  QQWryFileSize:=QQWryFileStream.Size;
  QQWryFileStream.Read(FirstIPIndexOffset, 4);
  QQWryFileStream.Read(LastIPIndexOffset, 4);
  IPRecordNum:=(LastIPIndexOffset - FirstIPIndexOffset) div 7 + 1;
end;

//
destructor TQQWry.Destroy;
begin
  QQWryFileStream.Free;
  inherited Destroy;
end;

//
function TQQWry.GetQQWryFileName: string;
begin
  Result:=QQWryFileName;
end;

//
function TQQWry.GetQQWryFileSize: Cardinal;
begin
  Result:=QQWryFileSize;
end;

//
function TQQWry.GetIPRecordNum: Cardinal;
begin
  Result:=IPRecordNum;
end;

//
function TQQWry.GetQQWryDate: String;
var
  DateString: string;
begin
  DateString:=GetIPMsg(GetIPRecordNum)[3];
  Result:=DateString;
end;
{
//
function TQQWry.GetQQWryDate: TDate;
var
  DateString: string;
begin
  DateString:=GetIPMsg(GetIPRecordNum)[3];
  DateString:=copy(DateString, 1, pos('IP数据', DateString) - 1);
  DateString:=StringReplace(DateString, '年', '-', [rfReplaceAll, rfIgnoreCase]);
  DateString:=StringReplace(DateString, '月', '-', [rfReplaceAll, rfIgnoreCase]);
  DateString:=StringReplace(DateString, '日', '-', [rfReplaceAll, rfIgnoreCase]);
  Result:=StrToDate(DateString);
end;
 }
//
function TQQWry.GetQQWryDataFrom: string;
begin
  Result:=GetIPMsg(GetIPRecordNum)[2];
end;

//
function TQQWry.GetIPLocation(IPLocationOffset: Cardinal): TStringlist;
const
  //实际信息字串存放位置的重定向模式
  REDIRECT_MODE_1 = 1;
  REDIRECT_MODE_2 = 2;
var
  RedirectMode: byte;
  CountryFirstOffset, CountrySecondOffset: Cardinal;
  CountryMsg, AreaMsg: string;
  //
  function ReadString(StringOffset: Cardinal): ansistring;
  var
    ReadByte: ansichar;
  begin
    Result:='';
    QQWryFileStream.Seek(StringOffset, soFromBeginning);
    QQWryFileStream.Read(ReadByte, 1);
    while ord(ReadByte)<>0 do begin
      Result := Result + ReadByte;
      QQWryFileStream.Read(ReadByte, 1);
    end;
  end;
  //
  function ReadArea(AreaOffset: Cardinal): ansistring;
  var
    ModeByte: byte;
    ReadAreaOffset: Cardinal;
  begin
    QQWryFileStream.Seek(AreaOffset, soFromBeginning);
    QQWryFileStream.Read(ModeByte, 1);
    if (ModeByte = REDIRECT_MODE_1) or (ModeByte = REDIRECT_MODE_2) then begin
      QQWryFileStream.Read(ReadAreaOffset, 3);
      if ReadAreaOffset=0 then Result:='未知地区'
      else Result:=ReadString(ReadAreaOffset);
    end else begin
      Result:=ReadString(AreaOffset);
    end;
  end;
begin
  //跳过4个字节，该4字节内容为该条IP信息里IP地址段中的终止IP值
  QQWryFileStream.Seek(IPLocationOffset + 4, soFromBeginning);
  //读取国家信息的重定向模式值
  QQWryFileStream.Read(RedirectMode, 1);

  //重定向模式1的处理
  if RedirectMode = REDIRECT_MODE_1 then begin
    //模式值为1，则后3个字节的内容为国家信息的重定向偏移值
    QQWryFileStream.Read(CountryFirstOffset, 3);
    //进行重定向
    QQWryFileStream.Seek(CountryFirstOffset, soFromBeginning);
    //第二次读取国家信息的重定向模式
    QQWryFileStream.Read(RedirectMode, 1);
    //第二次重定向模式为模式2的处理
    if RedirectMode = REDIRECT_MODE_2 then begin
      //后3字节的内容即为第二次重定向偏移值
      QQWryFileStream.Read(CountrySecondOffset, 3);
      //读取第二次重定向偏移值下的字符串值，即为国家信息
      CountryMsg:=ReadString(CountrySecondOffset);
      //若第一次重定向模式为1，进行重定向后读取的第二次重定向模式为2，
      //则地区信息存放在第一次国家信息偏移值的后面
      QQWryFileStream.Seek(CountryFirstOffset + 4, soFromBeginning);
    //第二次重定向模式不是模式2的处理
    end else begin
      CountryMsg:=ReadString(CountryFirstOffset);
    end;
    //在重定向模式1下读地区信息值
    AreaMsg:=ReadArea(QQWryFileStream.Position);
  //重定向模式2的处理
  end else if RedirectMode = REDIRECT_MODE_2 then begin
    QQWryFileStream.Read(CountrySecondOffset, 3);
    CountryMsg:=ReadString(CountrySecondOffset);
    AreaMsg:=ReadArea(IPLocationOffset + 8);
  //不是重定向模式的处理，存放的即是IP地址信息
  end else begin
    CountryMsg:=ReadString(QQWryFileStream.Position - 1);
    AreaMsg:=ReadArea(QQWryFileStream.Position);
  end;
  Result:=TStringlist.Create;
  Result.Add(CountryMsg);
  Result.Add(AreaMsg);
end;

//
function TQQWry.GetIPMsg(IPRecordID: Cardinal): TStringlist;
var
  aryStartIP: array[1..4] of byte;
  strStartIP: string;

  EndIPOffset: Cardinal;
  aryEndIP: array[1..4] of byte;
  strEndIP: string;

  i: integer;
begin
  //根据记录ID号移到该记录号的索引处
  QQWryFileStream.Seek(FirstIPIndexOffset + (IPRecordID - 1) * 7, soFromBeginning);
  //索引的前4个字节为起始IP地址
  QQWryFileStream.Read(aryStartIP, 4);
  //后3个字节是内容区域的偏移值
  QQWryFileStream.Read(EndIPOffset, 3);

  //移至内容区域
  QQWryFileStream.Seek(EndIPOffset, soFromBeginning);
  //内容区域的前4个字节为终止IP地址
  QQWryFileStream.Read(aryEndIP, 4);

  //将起止IP地址转换为点分的形式
  strStartIP:='';
  for i:=4 downto 1 do begin
    if i<>1 then strStartIP:=strStartIP + IntToStr(aryStartIP[i]) + '.'
    else strStartIP:=strStartIP + IntToStr(aryStartIP[i]);
  end;

  strEndIP:='';
  for i:=4 downto 1 do begin
    if i<>1 then strEndIP:=strEndIP + IntToStr(aryEndIP[i]) + '.'
    else strEndIP:=strEndIP + IntToStr(aryEndIP[i]);
  end;

  Result:=TStringlist.Create;
  Result.Add(strStartIP);
  Result.Add(strEndIP);
  //获取该条记录下的IP地址信息
  //以下三者是统一的：&#9312;内容区域的偏移值  &#9313;终止IP地址的存放位置  &#9314;国家信息紧接在终止IP地址存放位置后
  Result.AddStrings(GetIPLocation(EndIPOffset));
end;

//
function TQQWry.GetIPValue(IP: string): Cardinal;
var
  tsIP: TStringlist;
  i: integer;
  function SplitStringToStringlist(aString: string; aSplitChar: string): TStringlist;
  begin
    Result:=TStringList.Create;
    while pos(aSplitChar, aString)>0 do begin
      Result.Add(copy(aString, 1, pos(aSplitChar, aString)-1));
      aString:=copy(aString, pos(aSplitChar, aString)+1, length(aString)-pos(aSplitChar, aString));
    end;
    Result.Add(aString);
  end;
begin
  tsIP:=SplitStringToStringlist(IP, '.');
  Result:=0;
  for i:=3 downto 0 do begin
    Result:=Result + StrToInt(tsIP[i]) * trunc(power(256, 3-i));
  end;
end;

//
function TQQWry.GetIPRecordID(IP: string): Cardinal;
  function SearchIPRecordID(IPRecordFrom, IPRecordTo, IPValue: Cardinal): Cardinal;
  var
    CompareIPValue1, CompareIPValue2: Cardinal;
  begin
    Result:=0;
    QQWryFileStream.Seek(FirstIPIndexOffset + ((IPRecordTo - IPRecordFrom) div 2 + IPRecordFrom - 1) * 7, soFromBeginning);
    QQWryFileStream.Read(CompareIPValue1, 4);
    QQWryFileStream.Seek(FirstIPIndexOffset + ((IPRecordTo - IPRecordFrom) div 2 + IPRecordFrom) * 7, soFromBeginning);
    QQWryFileStream.Read(CompareIPValue2, 4);
    //找到了
    if (IPValue>=CompareIPValue1) and (IPValue<CompareIPValue2) then begin
      Result:=(IPRecordTo - IPRecordFrom) div 2 + IPRecordFrom;
    end else
      //后半段找
      if IPValue>CompareIPValue1 then begin
        Result:=SearchIPRecordID((IPRecordTo - IPRecordFrom) div 2 + IPRecordFrom + 1, IPRecordTo, IPValue);
      end else
        //前半段找
        if IPValue<CompareIPValue1 then begin
          Result:=SearchIPRecordID(IPRecordFrom, (IPRecordTo - IPRecordFrom) div 2 + IPRecordFrom - 1, IPValue);
        end;
  end;
begin
  Result:=SearchIPRecordID(1, GetIPRecordNum, GetIPValue(IP));
end;

end.

