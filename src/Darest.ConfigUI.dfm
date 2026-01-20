object frmConfig: TfrmConfig
  Left = 0
  Top = 0
  Margins.Left = 8
  Margins.Top = 8
  Margins.Right = 8
  Margins.Bottom = 8
  Caption = 'Scheme Permissions'
  ClientHeight = 740
  ClientWidth = 905
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -18
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnResize = FormResize
  OnShow = FormShow
  PixelsPerInch = 144
  TextHeight = 25
  object sgPermissions: TStringGrid
    Left = 0
    Top = 181
    Width = 905
    Height = 559
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Align = alClient
    Color = clWhite
    ColCount = 6
    DefaultColWidth = 96
    DefaultRowHeight = 36
    FixedColor = clActiveCaption
    FixedCols = 0
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goColSizing, goFixedRowDefAlign]
    TabOrder = 0
    OnDrawCell = sgPermissionsDrawCell
    OnMouseUp = sgPermissionsMouseUp
    ColWidths = (
      384
      96
      96
      95
      96
      96)
  end
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 905
    Height = 181
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Align = alTop
    TabOrder = 1
    DesignSize = (
      905
      181)
    object Label1: TLabel
      Left = 11
      Top = 22
      Width = 105
      Height = 32
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Database'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -24
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object Label2: TLabel
      Left = 431
      Top = 129
      Width = 32
      Height = 25
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Port'
    end
    object Label3: TLabel
      Left = 14
      Top = 129
      Width = 102
      Height = 25
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Swagger URI'
    end
    object btnConnect: TButton
      Left = 155
      Top = 64
      Width = 120
      Height = 38
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Connect'
      TabOrder = 0
      OnClick = btnConnectClick
    end
    object btnSave: TButton
      Left = 765
      Top = 16
      Width = 122
      Height = 38
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Anchors = [akTop, akRight]
      Caption = 'Save'
      TabOrder = 1
      OnClick = btnSaveClick
    end
    object btnSettings: TButton
      Left = 11
      Top = 64
      Width = 120
      Height = 38
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Settings'
      TabOrder = 2
      OnClick = btnSettingsClick
    end
    object cbLoginPrompt: TCheckBox
      Left = 306
      Top = 67
      Width = 183
      Height = 24
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Prompt Login'
      TabOrder = 3
    end
    object btnCancel: TButton
      Left = 765
      Top = 88
      Width = 122
      Height = 37
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Anchors = [akTop, akRight]
      Caption = 'Cancel'
      TabOrder = 4
      OnClick = btnCancelClick
    end
    object cbAutoConnect: TCheckBox
      Left = 465
      Top = 67
      Width = 146
      Height = 26
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Auto Connect'
      TabOrder = 5
    end
    object edUri: TEdit
      Left = 155
      Top = 126
      Width = 266
      Height = 33
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      TabOrder = 6
      Text = 'http://localhost'
    end
  end
  object edtServicePort: TEdit
    Left = 503
    Top = 126
    Width = 86
    Height = 33
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    MaxLength = 5
    TabOrder = 2
    Text = '8080'
  end
end
