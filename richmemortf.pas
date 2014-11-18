unit RichMemoRTF;

interface

{$mode objfpc}{$h+}

uses
  Classes, SysUtils, LCLProc, LCLIntf, LConvEncoding,
  RichMemo, RTFParsPre211, Graphics;

function MVCParserLoadStream(ARich: TCustomRichMemo; Source: TStream): Boolean;
procedure RegisterRTFLoader;

type
  TEncConvProc = function (const s: string): string;

procedure LangConvAdd(lang: Integer; convproc: TEncConvProc);
function LangConvGet(lang: Integer; var convproc: TEncConvProc): Boolean;

implementation

var
  LangConvTable : array of record lang: integer; proc: TEncConvProc end;
  LangCount     : Integer = 0;

procedure LangConvAdd(lang: Integer; convproc: TEncConvProc);
var
  i  : integer;
begin
  for i:=0 to LangCount-1 do
    if LangConvTable[i].lang=lang then begin
      LangConvTable[i].proc:=convproc;
      Exit;
    end;
  if LangCount=length(LangConvTable) then begin
    if LangCount=0 then SetLength(LangConvTable, 64)
    else SetLength(LangConvTable, LangCount*2);
  end;
  LangConvTable[LangCount].lang:=lang;
  LangConvTable[LangCount].proc:=convproc;
  inc(LangCount);
end;

type
  { TRTFMemoParser }

  TRTFMemoParser = class(TRTFParser)
  private
    txtbuf   : String; // keep it UTF8 encoded!

    fcolor    : TColor;      // Foreground color
    txtlen    : Integer;
    pm : TParaMetric;
    pa : TParaAlignment;
    fnum: Integer;
    fsz : double;
    fst : TFontStyles;

    lang   : Integer;
    langproc : TEncConvProc;
  protected
    procedure classUnk;
    procedure classText;
    procedure classControl;
    procedure classGroup;
    procedure classEof;
    procedure doChangePara(aminor, aparam: Integer);

    procedure doSpecialChar;
    procedure doChangeCharAttr(aminor, aparam: Integer);

    function DefaultTextColor: TColor;
    procedure PushText;
  public
    Memo  : TCustomRichMemo;
    constructor Create(AMemo: TCustomRichMemo; AStream: TStream);
    procedure StartReading;
  end;

function LangConvGet(lang: Integer; var convproc: TEncConvProc): Boolean;
var
  i  : integer;
begin
  for i:=0 to LangCount-1 do
    if LangConvTable[i].lang=lang then begin
      convproc:=LangConvTable[i].proc;
      Result:=true;
      Exit;
    end;
  Result:=false;
end;

procedure LangConvInit;
begin
  LangConvAdd(1052, @CP1250ToUTF8); // Albanian
  LangConvAdd(1050, @CP1250ToUTF8); // Croatian
  LangConvAdd(1029, @CP1250ToUTF8); // Czech
  LangConvAdd(1038, @CP1250ToUTF8); // Hungarian
  LangConvAdd(1045, @CP1250ToUTF8); // Polish
  LangConvAdd(1048, @CP1250ToUTF8); // Romanian
  LangConvAdd(2074, @CP1250ToUTF8); // Serbian - Latin
  LangConvAdd(1051, @CP1250ToUTF8); // Slovak
  LangConvAdd(1060, @CP1250ToUTF8); // Slovenian

  LangConvAdd(2092, @CP1251ToUTF8); // Azeri - Cyrillic
  LangConvAdd(1059, @CP1251ToUTF8); // Belarusian
  LangConvAdd(1026, @CP1251ToUTF8); // Bulgarian
  LangConvAdd(1071, @CP1251ToUTF8); // FYRO Macedonia
  LangConvAdd(1087, @CP1251ToUTF8); // Kazakh
  LangConvAdd(1088, @CP1251ToUTF8); // Kyrgyz - Cyrillic
  LangConvAdd(1104, @CP1251ToUTF8); // Mongolian
  LangConvAdd(1049, @CP1251ToUTF8); // Russian
  LangConvAdd(3098, @CP1251ToUTF8); // Serbian - Cyrillic
  LangConvAdd(1092, @CP1251ToUTF8); // Tatar
  LangConvAdd(1058, @CP1251ToUTF8); // Ukrainian
  LangConvAdd(2115, @CP1251ToUTF8); // Uzbek - Cyrillic

  LangConvAdd(1078, @CP1252ToUTF8); // Afrikaans
  LangConvAdd(1069, @CP1252ToUTF8); // Basque
  LangConvAdd(1027, @CP1252ToUTF8); // Catalan
  LangConvAdd(1030, @CP1252ToUTF8); // Danish
  LangConvAdd(2067, @CP1252ToUTF8); // Dutch - Belgium
  LangConvAdd(1043, @CP1252ToUTF8); // Dutch - Netherlands
  LangConvAdd(3081, @CP1252ToUTF8); // English - Australia
  LangConvAdd(10249,@CP1252ToUTF8); // English - Belize
  LangConvAdd(4105, @CP1252ToUTF8); // English - Canada
  LangConvAdd(9225, @CP1252ToUTF8); // English - Caribbean
  LangConvAdd(2057, @CP1252ToUTF8); // English - Great Britain
  LangConvAdd(6153, @CP1252ToUTF8); // English - Ireland
  LangConvAdd(8201, @CP1252ToUTF8); // English - Jamaica
  LangConvAdd(5129, @CP1252ToUTF8); // English - New Zealand
  LangConvAdd(13321,@CP1252ToUTF8); // English - Phillippines
  LangConvAdd(7177, @CP1252ToUTF8); // English - Southern Africa
  LangConvAdd(11273,@CP1252ToUTF8); // English - Trinidad
  LangConvAdd(1033, @CP1252ToUTF8); // English - United States
  LangConvAdd(12297,@CP1252ToUTF8); // English - Zimbabwe
  LangConvAdd(1080, @CP1252ToUTF8); // Faroese
  LangConvAdd(1035, @CP1252ToUTF8); // Finnish
  LangConvAdd(2060, @CP1252ToUTF8); // French - Belgium
  LangConvAdd(3084, @CP1252ToUTF8); // French - Canada
  LangConvAdd(1036, @CP1252ToUTF8); // French - France
  LangConvAdd(5132, @CP1252ToUTF8); // French - Luxembourg
  LangConvAdd(6156, @CP1252ToUTF8); // French - Monaco
  LangConvAdd(4108, @CP1252ToUTF8); // French - Switzerland
  LangConvAdd(1110, @CP1252ToUTF8); // Galician
  LangConvAdd(3079, @CP1252ToUTF8); // German - Austria
  LangConvAdd(1031, @CP1252ToUTF8); // German - Germany
  LangConvAdd(5127, @CP1252ToUTF8); // German - Liechtenstein
  LangConvAdd(4103, @CP1252ToUTF8); // German - Luxembourg
  LangConvAdd(2055, @CP1252ToUTF8); // German - Switzerland
  LangConvAdd(1039, @CP1252ToUTF8); // Icelandic
  LangConvAdd(1057, @CP1252ToUTF8); // Indonesian
  LangConvAdd(1040, @CP1252ToUTF8); // Italian - Italy
  LangConvAdd(2064, @CP1252ToUTF8); // Italian - Switzerland
  LangConvAdd(2110, @CP1252ToUTF8); // Malay - Brunei
  LangConvAdd(1086, @CP1252ToUTF8); // Malay - Malaysia
  LangConvAdd(1044, @CP1252ToUTF8); // Norwegian - Bokml
  LangConvAdd(2068, @CP1252ToUTF8); // Norwegian - Nynorsk
  LangConvAdd(1046, @CP1252ToUTF8); // Portuguese - Brazil
  LangConvAdd(2070, @CP1252ToUTF8); // Portuguese - Portugal
  LangConvAdd(1274, @CP1252ToUTF8); // Spanish - Argentina
  LangConvAdd(16394,@CP1252ToUTF8); // Spanish - Bolivia
  LangConvAdd(13322,@CP1252ToUTF8); // Spanish - Chile
  LangConvAdd(9226, @CP1252ToUTF8); // Spanish - Colombia
  LangConvAdd(5130, @CP1252ToUTF8); // Spanish - Costa Rica
  LangConvAdd(7178, @CP1252ToUTF8); // Spanish - Dominican Republic
  LangConvAdd(12298,@CP1252ToUTF8); // Spanish - Ecuador
  LangConvAdd(17418,@CP1252ToUTF8); // Spanish - El Salvador
  LangConvAdd(4106, @CP1252ToUTF8); // Spanish - Guatemala
  LangConvAdd(18442,@CP1252ToUTF8); // Spanish - Honduras
  LangConvAdd(2058, @CP1252ToUTF8); // Spanish - Mexico
  LangConvAdd(19466,@CP1252ToUTF8); // Spanish - Nicaragua
  LangConvAdd(6154, @CP1252ToUTF8); // Spanish - Panama
  LangConvAdd(15370,@CP1252ToUTF8); // Spanish - Paraguay
  LangConvAdd(10250,@CP1252ToUTF8); // Spanish - Peru
  LangConvAdd(20490,@CP1252ToUTF8); // Spanish - Puerto Rico
  LangConvAdd(1034, @CP1252ToUTF8); // Spanish - Spain (Traditional)
  LangConvAdd(14346,@CP1252ToUTF8); // Spanish - Uruguay
  LangConvAdd(8202, @CP1252ToUTF8); // Spanish - Venezuela
  LangConvAdd(1089, @CP1252ToUTF8); // Swahili
  LangConvAdd(2077, @CP1252ToUTF8); // Swedish - Finland
  LangConvAdd(1053, @CP1252ToUTF8); // Swedish - Sweden

  LangConvAdd(1032, @CP1253ToUTF8); // greek

  LangConvAdd(1068, @CP1254ToUTF8); // Azeri - Latin
  LangConvAdd(1055, @CP1254ToUTF8); // turkish
  LangConvAdd(1091, @CP1254ToUTF8); // Uzbek - Latin

  LangConvAdd(1037, @CP1255ToUTF8); // hebrew

  LangConvAdd(5121, @CP1256ToUTF8); // Arabic - Algeria
  LangConvAdd(15361,@CP1256ToUTF8); // Arabic - Bahrain
  LangConvAdd(3073, @CP1256ToUTF8); // Arabic - Egypt
  LangConvAdd(2049, @CP1256ToUTF8); // Arabic - Iraq
  LangConvAdd(11265,@CP1256ToUTF8); // Arabic - Jordan
  LangConvAdd(13313,@CP1256ToUTF8); // Arabic - Kuwait
  LangConvAdd(12289,@CP1256ToUTF8); // Arabic - Lebanon
  LangConvAdd(4097, @CP1256ToUTF8); // Arabic - Libya
  LangConvAdd(6145, @CP1256ToUTF8); // Arabic - Morocco
  LangConvAdd(8193, @CP1256ToUTF8); // Arabic - Oman
  LangConvAdd(16385,@CP1256ToUTF8); // Arabic - Qatar
  LangConvAdd(1025, @CP1256ToUTF8); // Arabic - Saudi Arabia
  LangConvAdd(10241,@CP1256ToUTF8); // Arabic - Syria
  LangConvAdd(7169, @CP1256ToUTF8); // Arabic - Tunisia
  LangConvAdd(14337,@CP1256ToUTF8); // Arabic - United Arab Emirates
  LangConvAdd(9217, @CP1256ToUTF8); // Arabic - Yemen
  LangConvAdd(1065, @CP1256ToUTF8); // Farsi - Persian
  LangConvAdd(1056, @CP1256ToUTF8); // Urdu

  LangConvAdd(1061, @CP1257ToUTF8); // Estonian
  LangConvAdd(1062, @CP1257ToUTF8); // Latvian
  LangConvAdd(1063, @CP1257ToUTF8); // Lithuanian

  LangConvAdd(1066, @CP1258ToUTF8); // vietnam
end;

{ TRTFMemoParserr }

procedure TRTFMemoParser.classUnk;
var
  txt : string;
  ws : UnicodeString;
begin
  //writelN('unk: ', rtfMajor, ' ',rtfMinor,' ', rtfParam,' ', GetRtfText);
  txt:=GetRtfText;
  if (length(txt)>2) and (txt[1]='\') and (txt[2]='u') and (txt[3] in ['0'..'9']) then begin
    SetLength(Ws,1);
    ws[1]:=UnicodeChar(rtfParam);
    txtbuf:=txtbuf+UTF8Encode(ws);
    txtlen:=length(txtbuf);
  end; 
end;

function CharToByte(const ch: AnsiChar): Byte;
begin
  Result:=0;
  if ch in ['0'..'9'] then Result:=byte(ch)-byte('0')
  else if ch in ['a'..'f'] then Result:=byte(ch)-byte('a')+10
  else if ch in ['A'..'F'] then Result:=byte(ch)-byte('A')+10
end;

function RTFCharToByte(const s: string): byte; inline;
begin
  // \'hh 	A hexadecimal value, based on the specified character set (may be used to identify 8-bit values).
  Result:=(CharToByte(s[3]) shl 4) or (CharToByte(s[4]));
end;

procedure TRTFMemoParser.classText;
var
  txt : string;
  bt  : Char;
begin
  txt:=Self.GetRtfText;
  //writeln('txt:  ', rtfMajor, ' ',rtfMinor,' ', rtfParam,' ',);
  if (length(txt)=4) and (txt[1]='\') and (txt[2]=#39) then begin
    if Assigned(langproc) then begin
      bt:=char(RTFCharToByte(txt));
      txtbuf:=txtbuf+langproc(bt);
      txtlen:=length(txtbuf);
    end;
  end else
    case rtfMinor of
      rtfOptDest: {skipping option generator};
    else
      txtbuf:=txtbuf+txt;
      txtlen:=length(txtbuf);
    end;
end;

procedure TRTFMemoParser.classControl;
begin
  if txtbuf<>'' then
    PushText;
  //writeln('ctrl: ', rtfClass,' ', rtfMajor, ' ', Self.GetRtfText, ' ',rtfMinor,' ', rtfParam);
  case rtfMajor of
    rtfSpecialChar: doSpecialChar;
    rtfCharAttr: doChangeCharAttr(rtfMinor, rtfParam);
    rtfParAttr: doChangePara(rtfMinor, rtfParam);
  end;
end;

procedure TRTFMemoParser.classGroup;
begin
  //writeln('group:  ', rtfMajor, ' ',rtfMinor,' ', rtfParam, ' ', GetRtfText);
end;

procedure TRTFMemoParser.classEof;
begin
  PushText;
end;

procedure TRTFMemoParser.doChangePara(aminor, aparam: Integer);
begin
  case aminor of
    rtfParDef:begin
      FillChar(pm, sizeof(pm), 0);
      pa:=paLeft;
    end;
    rtfQuadLeft:    pa:=paLeft;
    rtfQuadRight:   pa:=paRight;
    rtfQuadJust:    pa:=paJustify;
    rtfQuadCenter:  pa:=paCenter;
    rtfFirstIndent: begin
      pm.FirstLine:=aparam / 20;
      pm.FirstLine:=pm.FirstLine+pm.HeadIndent;
    end;
    rtfLeftIndent: begin
      pm.HeadIndent:=aparam / 20;
      pm.FirstLine:=pm.FirstLine+pm.HeadIndent;
    end;
    rtfRightIndent:  pm.TailIndent  := aparam / 20;
    rtfSpaceBefore:  pm.SpaceBefore := aparam / 20;
    rtfSpaceAfter:   pm.SpaceAfter  := aparam / 20;
    rtfSpaceBetween: pm.LineSpacing := aparam / 240;
    rtfLanguage: begin
      lang:=rtfParam;
      langproc:=nil;
      LangConvGet(lang, langproc);
    end;
  end;
end;

procedure TRTFMemoParser.doSpecialChar;
const
  {$ifdef MSWINDOWS}
  CharPara = #13#10;
  {$else}
  CharPara = #10;
  {$endif}
  CharTab  = #9;
  CharLine = #13;
begin
  case rtfMinor of
    rtfLine: txtbuf:=txtbuf+CharLine;
    rtfPar:  txtbuf:=txtbuf+CharPara;
    rtfTab:  txtbuf:=txtbuf+CharTab;
  end;
end;

procedure TRTFMemoParser.doChangeCharAttr(aminor, aparam: Integer);
var
  p : PRTFColor;
begin
  if txtbuf<>'' then PushText;

  case aminor of
    rtfPlain: fst:=[];
    rtfBold: if aparam=0 then Exclude(fst,fsBold)  else Include(fst, fsBold);
    rtfItalic: if aparam=0 then Exclude(fst,fsItalic)  else Include(fst, fsItalic);
    rtfStrikeThru: if aparam=0 then Exclude(fst,fsStrikeOut)  else Include(fst, fsStrikeOut);
    rtfFontNum: fnum:=aparam;
    rtfFontSize: fsz:=aparam/2;
    rtfUnderline: if aparam=0 then Exclude(fst,fsUnderline)  else Include(fst, fsUnderline);
    rtfNoUnderline: Exclude(fst, fsUnderline);
    rtfForeColor: begin
      if rtfParam<>0 then p:=Colors[rtfParam]
      else p:=nil;
      if not Assigned(p) then
        fcolor:=DefaultTextColor
      else
        fcolor:=RGBToColor(p^.rtfCRed, p^.rtfCGreen, p^.rtfCBlue);
    end;
  end;
end;

function TRTFMemoParser.DefaultTextColor:TColor;
begin
  Result:=ColorToRGB(Memo.Font.Color);
end;

procedure TRTFMemoParser.PushText;
var
  len   : Integer;
  font  : TFontParams;
  pf    : PRTFFONT;
  selst : Integer;
begin
  len:=UTF8Length(txtbuf);
  if len=0 then Exit;

  Memo.SelStart:=MaxInt;
  selst:=Memo.SelStart;
  // in order to get the start selection, we need to switch to the last character
  // and then get the value. SelStart doesn't match GetTextLen, since
  // "StartSel" is based on number of visible characters (i.e. line break is 1 character)
  // while GetTextLen is based on number of actual string characters
  // selst:=Memo.GetTextLen;

  Memo.SelStart:=selst;
  Memo.SelLength:=0;
  Memo.SelText:=txtbuf;

  Memo.SetParaMetric(selst, 1, pm);
  Memo.SetParaAlignment(selst, 1, pa);

  Memo.GetTextAttributes(selst, font);
  pf:=Fonts[fnum];
  if Assigned(pf) then
    font.Name:=pf^.rtfFName;
  font.Size:=round(fsz);
  font.Style:=fst;
  font.Color:=ColorToRGB(fColor);
  Memo.SetTextAttributes(selst, len, font);
  txtbuf:='';
end;

constructor TRTFMemoParser.Create(AMemo:TCustomRichMemo;AStream:TStream);
begin
  inherited Create(AStream);
  Memo:=AMemo;
  ClassCallBacks[rtfText]:=@classText;
  ClassCallBacks[rtfControl]:=@classControl;
  ClassCallBacks[rtfGroup]:=@classGroup;
  ClassCallBacks[rtfUnknown]:=@classUnk;
  ClassCallBacks[rtfEof]:=@classEof;
end;

procedure TRTFMemoParser.StartReading;
begin
  Memo.Lines.BeginUpdate;
  try
    fsz:=12;//\fsN Font size in half-points (the default is 24).
    fnum:=0;

    inherited StartReading;
    PushText;
    Memo.SelStart:=0;
    Memo.SelLength:=0;
  finally
    Memo.Lines.EndUpdate;
  end;
end;

function MVCParserLoadStream(ARich: TCustomRichMemo; Source: TStream): Boolean;
var
  p   : TRTFMemoParser;
begin
  Result:=Assigned(ARich) and Assigned(Source);
  if not Result then Exit;

  p:=TRTFMemoParser.Create(ARich, Source);
  try
    p.StartReading;
  finally
    p.Free;
  end;
  Result:=True;
end;

procedure RegisterRTFLoader;
begin
  RTFLoadStream:=@MVCParserLoadStream;
  LangConvInit;
end;

initialization

end.
