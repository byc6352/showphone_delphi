object DM: TDM
  OldCreateOrder = False
  Height = 150
  Width = 315
  object csOrder: TClientSocket
    Active = False
    ClientType = ctNonBlocking
    Port = 0
    OnConnect = csOrderConnect
    OnDisconnect = csOrderDisconnect
    OnRead = csOrderRead
    OnError = csOrderError
    Left = 8
    Top = 8
  end
  object csData1: TClientSocket
    Active = False
    ClientType = ctNonBlocking
    Port = 0
    OnConnect = csData1Connect
    OnRead = csData1Read
    OnError = csOrderError
    Left = 72
    Top = 8
  end
  object csScreen: TClientSocket
    Active = False
    ClientType = ctNonBlocking
    Port = 0
    OnConnect = csData1Connect
    OnRead = csScreenRead
    OnError = csOrderError
    Left = 128
    Top = 8
  end
  object csCamera: TClientSocket
    Active = False
    ClientType = ctNonBlocking
    Port = 0
    OnConnect = csData1Connect
    OnRead = csData1Read
    Left = 192
    Top = 8
  end
  object csSound: TClientSocket
    Active = False
    ClientType = ctNonBlocking
    Port = 0
    OnConnect = csData1Connect
    OnRead = csData1Read
    Left = 248
    Top = 8
  end
end
