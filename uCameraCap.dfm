object fCameraCap: TfCameraCap
  Left = 192
  Top = 123
  Caption = #25668#20687#22836#30417#25511
  ClientHeight = 705
  ClientWidth = 578
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnClose = FormClose
  OnDestroy = FormDestroy
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 578
    Height = 28
    Align = alTop
    TabOrder = 0
    object btnStart: TSpeedButton
      Left = 4
      Top = 2
      Width = 32
      Height = 22
      Caption = #24320#22987
      OnClick = btnStartClick
    end
    object btnSinglePic: TSpeedButton
      Left = 38
      Top = 2
      Width = 32
      Height = 22
      Caption = #21333#24103
      OnClick = btnSinglePicClick
    end
    object Label1: TLabel
      Left = 76
      Top = 7
      Width = 60
      Height = 13
      Caption = #22270#20687#36136#37327#65306
    end
    object btnSound: TSpeedButton
      Left = 280
      Top = 2
      Width = 37
      Height = 22
      Caption = #25342#38899
      OnClick = btnSoundClick
    end
    object edtQuality: TEdit
      Left = 143
      Top = 4
      Width = 90
      Height = 21
      ImeName = #26234#33021#38472#26725#36755#20837#24179#21488'  5.5'
      TabOrder = 0
      Text = '80'
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 686
    Width = 578
    Height = 19
    Panels = <
      item
        Text = #35828#26126#65306#22270#20687#36136#37327#26368#22823#20540#20026'100'#65288#39640#28165#65289#26368#23567#20540#20026'10'#65288#27169#31946#65289
        Width = 50
      end>
  end
  object Panel2: TPanel
    Left = 0
    Top = 28
    Width = 578
    Height = 658
    Align = alClient
    TabOrder = 2
    object imgCamera: TImage
      Left = 4
      Top = 6
      Width = 555
      Height = 646
      AutoSize = True
      Center = True
      IncrementalDisplay = True
    end
  end
end
