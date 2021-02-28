unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls,
  Forms, Math, Types, Menus, ExtCtrls, ComCtrls, Dialogs, ShellApi,
  Image32, Image32_Layers, Image32_Ttf, Image32_Draw;

type

  //----------------------------------------------------------------------
  // A couple of custom layer classes ...
  //----------------------------------------------------------------------

  TMyVectorLayer32 = class(TVectorLayer32) //for vector drawn layers
  private
    fPenColor: TColor32;
    fBrushColor: TColor32;
    procedure InitRandomColors;
  public
    constructor Create(groupOwner: TGroupLayer32; const name: string = ''); override;
    procedure RedrawVector(const p: TPathsD = nil);
  end;

  TMyRasterLayer32 = class(TRasterLayer32) //for imported raster image layers
  public
    procedure Init(const pt: TPoint);
  end;

  //----------------------------------------------------------------------
  //----------------------------------------------------------------------

  TMainForm = class(TForm)
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    Exit1: TMenuItem;
    StatusBar1: TStatusBar;
    SaveDialog1: TSaveDialog;
    N2: TMenuItem;
    CopytoClipboard1: TMenuItem;
    PopupMenu1: TPopupMenu;
    mnuBringToFront: TMenuItem;
    mnuSendToBack: TMenuItem;
    N3: TMenuItem;
    mnuDeleteLayer: TMenuItem;
    AddEllipse1: TMenuItem;
    N4: TMenuItem;
    AddRectangle1: TMenuItem;
    AddText1: TMenuItem;
    OpenDialog1: TOpenDialog;
    PastefromClipboard1: TMenuItem;
    Action1: TMenuItem;
    mnuAddImage2: TMenuItem;
    mnuAddRectangle: TMenuItem;
    mnuAddEllipse: TMenuItem;
    mnuAddText: TMenuItem;
    N5: TMenuItem;
    mnuDeleteLayer2: TMenuItem;
    N6: TMenuItem;
    mnuBringtoFront2: TMenuItem;
    mnuSendtoBack2: TMenuItem;
    mnuAddImage: TMenuItem;
    mnuCutToClipboard: TMenuItem;
    procedure mnuExitClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure pnlMainMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pnlMainMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure pnlMainMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure mnuCopytoClipboardClick(Sender: TObject);
    procedure mnuBringToFrontClick(Sender: TObject);
    procedure mnuSendToBackClick(Sender: TObject);
    procedure mnuDeleteLayerClick(Sender: TObject);
    procedure PopupMenu1Popup(Sender: TObject);
    procedure mnuAddEllipseClick(Sender: TObject);
    procedure mnuAddRectangleClick(Sender: TObject);
    procedure mnuAddTextClick(Sender: TObject);
    procedure mnuPastefromClipboardClick(Sender: TObject);
    procedure mnuAddImageClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure mnuCutToClipboardClick(Sender: TObject);
  private
    layeredImage32: TLayeredImage32;

    fontReader: TFontReader; //TTF font reader
    fontCache: TGlyphCache;

    wordStrings: TStringList;

    clickedLayer: TLayer32;
    targetLayer: TLayer32;

    buttonGroup: TGroupLayer32;
    popupPoint: TPoint;
    clickPoint: TPoint;
    function AddRectangle(const pt: TPoint): TMyVectorLayer32;
    function AddEllipse(const pt: TPoint): TMyVectorLayer32;
    function AddText(const pt: TPoint): TMyVectorLayer32;
    procedure SetTargetLayer(layer: TLayer32);
    procedure DoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure DoDropImage(const filename: string);
  protected
    procedure WMDROPFILES(var msg: TWMDropFiles); message WM_DROPFILES;
    procedure WMERASEBKGND(var message: TMessage); message WM_ERASEBKGND;
  public
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

{$R WORDS.RES}
{$R FONT.RES}

uses
  Image32_BMP, Image32_PNG, Image32_JPG,
  Image32_Vector, Image32_Extra, Image32_Clipper;

const
  margin = 100;


//------------------------------------------------------------------------------
// Miscellaneous functions
//------------------------------------------------------------------------------

function MakeDarker(color: TColor32; percent: integer): TColor32;
var
  pcFrac: double;
  r: TARGB absolute Result;
begin
  percent := Max(0, Min(100, percent));
  pcFrac := percent/100;
  Result := color;
  r.R := r.R - Round(r.R * pcFrac);
  r.G := r.G - Round(r.G * pcFrac);
  r.B := r.B - Round(r.B * pcFrac);
end;

//------------------------------------------------------------------------------
// TMyVectorLayer32
//------------------------------------------------------------------------------

constructor TMyVectorLayer32.Create(groupOwner: TGroupLayer32;
  const name: string = '');
begin
  inherited;
  InitRandomColors;
  CursorId := crHandPoint;
end;
//------------------------------------------------------------------------------

procedure TMyVectorLayer32.InitRandomColors;
var
  hsl: THsl;
begin
  hsl.hue := Random(256);
  hsl.sat := 240;
  hsl.lum := 200;
  hsl.Alpha := 128;
  fBrushColor := HslToRgb(hsl);
  fPenColor := MakeDarker(fBrushColor, 60) or $FF000000;
end;
//------------------------------------------------------------------------------

procedure TMyVectorLayer32.RedrawVector(const p: TPathsD = nil);
var
  vectorRect: TRectD;
  scaleX, scaleY: double;
const
  marg = 2;
begin
  if Assigned(p) then Paths := p;
  //stretch the vectors so they fit neatly into the layer
  vectorRect := GetBoundsD(Paths);
  scaleX := (Image.Width - marg*2) / vectorRect.Width;
  scaleY := (Image.Height - marg*2) / vectorRect.Height;
  Paths := ScalePath(Paths, scaleX, scaleY);
  Paths := OffsetPath(Paths,
    marg - vectorRect.Left*scaleX,
    marg - vectorRect.Top*scaleY);
  DrawPolygon(Image, Paths, frEvenOdd, fBrushColor);
  DrawLine(Image, Paths, 4, fPenColor, esPolygon);
  UpdateHitTestMask(Paths, frEvenOdd);
end;

//------------------------------------------------------------------------------
// TMyRasterLayer32 methods
//------------------------------------------------------------------------------

procedure TMyRasterLayer32.Init(const pt: TPoint);
begin
  MasterImage.CropTransparentPixels;
  image.Assign(MasterImage);
  PositionCenteredAt(pt);
  CursorId := crHandPoint;
  UpdateHitTestMaskTransparent;
end;

//------------------------------------------------------------------------------
// TForm1 methods
//------------------------------------------------------------------------------

procedure TMainForm.FormCreate(Sender: TObject);
var
  resStream: TResourceStream;
begin
  Randomize;
  DefaultButtonSize := DPIAware(10); //ie the layered image's control buttons

  OnKeyDown := DoKeyDown;

  layeredImage32 := TLayeredImage32.Create; //sized in FormResize() below.

  //add a design layer that displays a hatched background.
  layeredImage32.AddLayer(TDesignerLayer32, nil, 'grid');

  //text support objects
  fontReader := TFontReader.Create;
  fontReader.LoadFromResource('FONT_NSB', RT_RCDATA);
  fontCache := TGlyphCache.Create(fontReader, DPIAware(48));

  //random words
  wordStrings := TStringList.Create;
  resStream := TResourceStream.Create(hInstance, 'WORDS', RT_RCDATA);
  try
    wordStrings.LoadFromStream(resStream);
  finally
    resStream.Free;
  end;

  DragAcceptFiles(Handle, True);
end;
//------------------------------------------------------------------------------

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  DragAcceptFiles(Handle, False);
  wordStrings.Free;
  fontCache.Free;
  fontReader.Free;
  layeredImage32.Free;
end;
//------------------------------------------------------------------------------

procedure TMainForm.WMDROPFILES(var msg: TWMDropFiles);
var
  dropHdl: HDROP;
  len: integer;
  filename: string;
begin
  dropHdl := msg.Drop;
  len := DragQueryFile(dropHdl, 0, nil, 0);
  SetLength(filename, len);
  DragQueryFile(dropHdl, 0, PChar(FileName), len + 1);
  OpenDialog1.InitialDir := ExtractFilePath(filename);
  OpenDialog1.FileName := filename;
  DragFinish(dropHdl);
  msg.Result := 0;     //ie message has been handled.
  DoDropImage(filename);
end;
//------------------------------------------------------------------------------

procedure TMainForm.WMERASEBKGND(var message: TMessage);
begin
  message.Result := 1; //don't erase!
end;
//------------------------------------------------------------------------------

procedure TMainForm.FormResize(Sender: TObject);
begin
  if (csDestroying in ComponentState) then Exit;

  layeredImage32.SetSize(ClientWidth, ClientHeight);

  //resize the hatched design background layer
  //nb use SetSize rather than Resize() to avoid stretching
  with TDesignerLayer32(layeredImage32.Root[0]) do
  begin
    SetSize(layeredImage32.Width, layeredImage32.Height);
    HatchBackground(Image);
  end;
  Invalidate;
end;
//------------------------------------------------------------------------------

procedure TMainForm.mnuAddEllipseClick(Sender: TObject);
begin
  SetTargetLayer(AddEllipse(popupPoint));
end;
//------------------------------------------------------------------------------

procedure TMainForm.mnuAddRectangleClick(Sender: TObject);
begin
  SetTargetLayer(AddRectangle(popupPoint));
end;
//------------------------------------------------------------------------------

procedure TMainForm.mnuAddTextClick(Sender: TObject);
begin
  SetTargetLayer(AddText(popupPoint));
end;
//------------------------------------------------------------------------------

function TMainForm.AddRectangle(const pt: TPoint): TMyVectorLayer32;
begin
  Result := TMyVectorLayer32(layeredImage32.AddLayer(TMyVectorLayer32));
  with TMyVectorLayer32(Result) do
  begin
    SetSize(DPIAware(50 + Random(200)), DPIAware(50 + Random(200)));
    RedrawVector(Image32_Vector.Paths(Rectangle(Bounds)));
  end;
  Result.PositionCenteredAt(pt);
end;
//------------------------------------------------------------------------------

function TMainForm.AddEllipse(const pt: TPoint): TMyVectorLayer32;
begin
  Result := TMyVectorLayer32(layeredImage32.AddLayer(TMyVectorLayer32));
  with TMyVectorLayer32(Result) do
  begin
    SetSize(DPIAware(50 + Random(200)), DPIAware(50 + Random(200)));
    RedrawVector(Image32_Vector.Paths(Ellipse(Bounds)));
    PositionCenteredAt(pt);
  end;
end;
//------------------------------------------------------------------------------

function TMainForm.AddText(const pt: TPoint): TMyVectorLayer32;
var
  randomWord: string;
  tmp: TPathsD;
begin
  randomWord := wordStrings[Random(wordStrings.Count)];
  Result := TMyVectorLayer32(layeredImage32.AddLayer(TMyVectorLayer32));
  with Result as TMyVectorLayer32 do
  begin
    fontCache.GetTextGlyphs(0,0,randomWord, tmp);
    Paths := ScalePath(tmp, 1, 2.0);
    SetBounds(Image32_Vector.GetBounds(Paths));
    RedrawVector;
    PositionCenteredAt(pt);
  end;
end;
//------------------------------------------------------------------------------

procedure TMainForm.mnuAddImageClick(Sender: TObject);
var
  rasterLayer: TMyRasterLayer32;
begin
  if not OpenDialog1.Execute then Exit;
  rasterLayer := TMyRasterLayer32(layeredImage32.AddLayer(TMyRasterLayer32));
  rasterLayer.MasterImage.LoadFromFile(OpenDialog1.FileName);
  rasterLayer.Init(Point(layeredImage32.MidPoint));
  Invalidate;
end;
//------------------------------------------------------------------------------

procedure TMainForm.mnuPastefromClipboardClick(Sender: TObject);
var
  rasterLayer: TMyRasterLayer32;
begin
  if not TImage32.CanPasteFromClipBoard then Exit;
  FreeAndNil(buttonGroup);
  rasterLayer := TMyRasterLayer32(layeredImage32.AddLayer(TMyRasterLayer32));
  rasterLayer.MasterImage.PasteFromClipBoard;
  rasterLayer.Init(Point(layeredImage32.MidPoint));
  Invalidate;
end;
//------------------------------------------------------------------------------

procedure TMainForm.DoDropImage(const filename: string);
var
  rasterLayer: TMyRasterLayer32;
  pt: TPoint;
begin
  if not TImage32.IsRegisteredFormat(ExtractFileExt(filename)) then Exit;

  GetCursorPos(pt);
  pt := ScreenToClient(pt);

  FreeAndNil(buttonGroup);
  rasterLayer := TMyRasterLayer32(layeredImage32.AddLayer(TMyRasterLayer32));
  rasterLayer.MasterImage.LoadFromFile(FileName);
  rasterLayer.Init(pt);
  Invalidate;
end;
//------------------------------------------------------------------------------

procedure TMainForm.FormPaint(Sender: TObject);
var
  updateRect: TRect;
begin
  //copy layeredImage32 onto the form's canvas
  //nb: layeredImage32.GetMergedImage can also return the portion of
  //the image that's changed since the previous GetMergedImage call.
  //Updating only the changed region significantly speeds up drawing.
  with layeredImage32.GetMergedImage(false, updateRect) do
  begin
    CopyToDc(updateRect, self.Canvas.Handle,
      updateRect.Left, updateRect.Top, false);
  end;
end;
//------------------------------------------------------------------------------


procedure TMainForm.DoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and Assigned(targetLayer) then
  begin
    SetTargetLayer(nil); //deselect the active control
    Key := 0;
  end;
end;
//------------------------------------------------------------------------------

procedure TMainForm.SetTargetLayer(layer: TLayer32);
begin
  if targetLayer = layer then Exit;
  FreeAndNil(buttonGroup);
  targetLayer := layer;
  Invalidate;
  if not assigned(targetLayer) then Exit;
  //add sizing buttons around the target layer
  buttonGroup := CreateSizingButtonGroup(layer,
    ssCorners, bsRound, DPIAware(10), clGreen32);
end;
//------------------------------------------------------------------------------

procedure TMainForm.pnlMainMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  clickPoint := Types.Point(X,Y);
  clickedLayer := layeredImage32.GetLayerAt(clickPoint);

  if not Assigned(clickedLayer) then
  begin
    FreeAndNil(buttonGroup);
    targetLayer := nil;
  end
  else if Assigned(clickedLayer) and
     not (clickedLayer is TButtonDesignerLayer32) and
    (clickedLayer <> targetLayer) then
      SetTargetLayer(clickedLayer);

  Invalidate;
end;
//------------------------------------------------------------------------------

procedure TMainForm.pnlMainMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  dx, dy: integer;
  pt: TPoint;
  layer: TLayer32;
  rec: TRect;
begin
  pt := Types.Point(X,Y);

  //if not moving anything, just update the cursor
  if not (ssLeft in Shift) then
  begin
    layer := layeredImage32.GetLayerAt(pt);
    if Assigned(layer) then
      Cursor := layer.CursorId else
      Cursor := crDefault;
    Exit;
  end;

  if not Assigned(clickedLayer) then Exit;

  dx := pt.X - clickPoint.X;
  dy := pt.Y - clickPoint.Y;
  clickPoint := pt;

  if clickedLayer is TButtonDesignerLayer32 then
  begin
    clickedLayer.Offset(dx, dy);

    //get and assign the new bounds for activeLayer using sizing button group
    rec := Rect(UpdateSizingButtonGroup(
      TButtonDesignerLayer32(clickedLayer)));
    targetLayer.SetBounds(rec);

    if targetLayer is TMyVectorLayer32 then
      with TMyVectorLayer32(targetLayer) do
    begin
      RedrawVector;
    end
    else if targetLayer is TMyRasterLayer32 then
      with TMyRasterLayer32(targetLayer) do
    begin
      Image.Copy(MasterImage, MasterImage.Bounds, Image.Bounds);
      UpdateHitTestMaskTransparent;
    end;
  end
  else if Assigned(targetLayer) then
  begin
    targetLayer.Offset(dx, dy);
    if assigned(buttonGroup) then
       buttonGroup.Offset(dx, dy);
  end;
  Invalidate;
end;
//------------------------------------------------------------------------------

procedure TMainForm.pnlMainMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  clickedLayer := nil;
end;
//------------------------------------------------------------------------------

procedure TMainForm.mnuCutToClipboardClick(Sender: TObject);
begin
  if Assigned(targetLayer) then
  begin
    targetLayer.Image.CopyToClipBoard;
    layeredImage32.DeleteLayer(targetLayer);
    FreeAndNil(buttonGroup);
    Invalidate;
  end;
end;
//------------------------------------------------------------------------------

procedure TMainForm.mnuCopytoClipboardClick(Sender: TObject);
begin
  if Assigned(targetLayer) then
    targetLayer.Image.CopyToClipBoard;
end;
//------------------------------------------------------------------------------

procedure TMainForm.mnuExitClick(Sender: TObject);
begin
  Close;
end;
//------------------------------------------------------------------------------

procedure TMainForm.mnuBringToFrontClick(Sender: TObject);
begin
  if not assigned(targetLayer) then Exit;
  if targetLayer.Index = targetLayer.GroupOwner.ChildCount -1 then Exit;
  if targetLayer.BringForwardOne then
    Invalidate;
end;
//------------------------------------------------------------------------------

procedure TMainForm.mnuSendToBackClick(Sender: TObject);
var
  oldIdx: integer;
begin
  oldIdx := targetLayer.Index;
  //send to bottom except for the hatched background (index = 0)
  if oldIdx = 1 then Exit;
  if targetLayer.SendBackOne then
    Invalidate;
end;
//------------------------------------------------------------------------------

procedure TMainForm.mnuDeleteLayerClick(Sender: TObject);
begin
  if not assigned(targetLayer) then Exit;
  layeredImage32.DeleteLayer(targetLayer);
  FreeAndNil(buttonGroup);
  Invalidate;
end;
//------------------------------------------------------------------------------

procedure TMainForm.PopupMenu1Popup(Sender: TObject);
begin
  mnuBringToFront.Enabled := assigned(targetLayer) and
    (targetLayer.Index < layeredImage32.Root.ChildCount -2);
  mnuBringtoFront2.Enabled := mnuBringtoFront.Enabled;
  mnuSendToBack.Enabled := assigned(targetLayer) and (targetLayer.Index > 1);
  mnuSendtoBack2.Enabled := mnuSendtoBack.Enabled;
  mnuDeleteLayer.Enabled := assigned(targetLayer);
  mnuDeleteLayer2.Enabled := mnuDeleteLayer.Enabled;

  if Sender = PopupMenu1 then
  begin
    GetCursorPos(popupPoint);
    popupPoint := ScreenToClient(popupPoint);
  end else
    popupPoint := Point(layeredImage32.MidPoint);
end;
//------------------------------------------------------------------------------

end.
