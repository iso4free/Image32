unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Math,
  Types, Menus, ExtCtrls, ComCtrls, Image32, Image32_Layers, ImagePanels,
  Dialogs, ClipBrd, Vcl.StdCtrls;

type
  TTransformType = (ttAffineSkew, ttProjective, ttSpline, ttAffineRotate);

  TForm1 = class(TForm)
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    Exit1: TMenuItem;
    N1: TMenuItem;
    StatusBar1: TStatusBar;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    mnuOpen: TMenuItem;
    mnuSave: TMenuItem;
    N2: TMenuItem;
    CopytoClipboard1: TMenuItem;
    mnuPastefromClipboard: TMenuItem;
    ransformType1: TMenuItem;
    mnuVertSkew: TMenuItem;
    mnuHorizontalSkew: TMenuItem;
    mnuVertProjective: TMenuItem;
    mnuVerticalSpline: TMenuItem;
    PopupMenu1: TPopupMenu;
    mnuAddNewCtrlPoint: TMenuItem;
    N3: TMenuItem;
    mnuHideControls: TMenuItem;
    Rotate1: TMenuItem;
    N4: TMenuItem;
    mnuHideDesigners: TMenuItem;
    procedure Exit1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure pnlMainMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pnlMainMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure mnuOpenClick(Sender: TObject);
    procedure mnuSaveClick(Sender: TObject);
    procedure CopytoClipboard1Click(Sender: TObject);
    procedure mnuPastefromClipboardClick(Sender: TObject);
    procedure mnuVerticalSplineClick(Sender: TObject);
    procedure mnuAddNewCtrlPointClick(Sender: TObject);
    procedure File1Click(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure PopupMenu1Popup(Sender: TObject);
    procedure FormDblClick(Sender: TObject);
    procedure mnuHideDesignersClick(Sender: TObject);
  private
    layeredImage: TLayeredImage32;
    buttonGroup: TButtonGroupLayer32;
    rotateGroup: TRotatingGroupLayer32;
    transformLayer: TRasterLayer32;
    clickedLayer: TLayer32;

    popupPoint: TPoint;
    clickPoint: TPoint;
    ctrlPoints: TPathD;
    transformType: TTransformType;
    doTransformOnIdle: Boolean;
    allowRotatePivotMove: Boolean;
    procedure ResetSpline;
    procedure ResetVertProjective;
    procedure ResetSkew(isVerticalSkew: Boolean);
    procedure ResetRotate;
    procedure DoTransform;
    procedure AppIdle(Sender: TObject; var Done: Boolean);
  protected
    procedure WMERASEBKGND(var message: TMessage); message WM_ERASEBKGND;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}
{$R image.res}

uses
  Image32_BMP, Image32_PNG, Image32_JPG, Image32_Draw, Image32_Vector,
  Image32_Extra, Image32_Transform;

//------------------------------------------------------------------------------

procedure TForm1.FormCreate(Sender: TObject);
begin

  //SETUP THE LAYERED IMAGE
  DefaultButtonSize := DPIAware(10);
  allowRotatePivotMove := true;

  Application.OnIdle := AppIdle;

  layeredImage := TLayeredImage32.Create;
  layeredImage.BackgroundColor := Color32(clBtnFace);

  //Layer 0: bottom 'hatched' design layer
  layeredImage.AddLayer(TDesignerLayer32, nil, 'hatched');

  //Layer 1: for the transformed image
  transformLayer := TRasterLayer32(layeredImage.AddLayer(TRasterLayer32));
  transformLayer.MasterImage.LoadFromResource('GRADIENT', 'PNG');

  transformLayer.CursorId := crHandPoint;
  transformLayer.AutoPivot := true;
  transformLayer.UpdateHitTestMaskTransparent;

  ResetSkew(mnuVertSkew.Checked);
end;
//------------------------------------------------------------------------------

procedure TForm1.FormResize(Sender: TObject);
var
  w,h: integer;
  mp: TPointD;
  dx, dy: double;
begin
  if csDestroying in ComponentState then Exit;

  w := ClientWidth; h := ClientHeight;

  //resize layeredImage and the background hatch layer
  layeredImage.SetSize(w, h);
  with layeredImage[0] do
  begin
    SetSize(w, h);
    HatchBackground(Image, clWhite32, $FFE0E0E0);
  end;
  //and center transformlayer
  mp := transformLayer.MidPoint;
  transformlayer.PositionCenteredAt(w/2,h/2);

  //and offset everything else
  with transformLayer.MidPoint do
  begin
    dx := X - mp.X;
    dy := Y - mp.Y;
  end;
  if Assigned(buttonGroup) then
    buttonGroup.Offset(dx, dy)
  else if Assigned(rotateGroup) then
    rotateGroup.Offset(dx, dy);
  ctrlPoints := OffsetPath(ctrlPoints, dx, dy);
  Invalidate;
end;
//------------------------------------------------------------------------------

procedure TForm1.AppIdle(Sender: TObject; var Done: Boolean);
begin
  if doTransformOnIdle then
  begin
    doTransformOnIdle := false;
    DoTransform;
  end;
end;
//------------------------------------------------------------------------------

procedure TForm1.WMERASEBKGND(var message: TMessage);
begin
  //Since we want full control of painting (see FormPaint below),
  //we'll stops Windows unhelpfully erasing the form's canvas.
  message.Result := 1;
end;
//------------------------------------------------------------------------------

procedure TForm1.FormPaint(Sender: TObject);
var
  updateRect: TRect;
begin
  //nb: layeredImage32.GetMergedImage returns the rectangular region of the
  //image that has changed since the last GetMergedImage call.
  //This accommodates updating just the region that's changed. This is
  //generally a lot faster than updating the whole merged image).
  with layeredImage.GetMergedImage(mnuHideControls.Checked, updateRect) do
  begin
    //now we just refresh the 'updateRect' region
    CopyToDc(updateRect, updateRect, self.Canvas.Handle, false);
  end;
end;
//------------------------------------------------------------------------------

procedure TForm1.ResetSkew(isVerticalSkew: Boolean);
begin
  FreeAndNil(buttonGroup);
  FreeAndNil(rotateGroup);

  transformType := ttAffineSkew;

  SetLength(ctrlPoints, 2);
  with transformLayer.MasterImage.Bounds do
  begin
    ctrlPoints[0] := PointD(TopLeft);
    ctrlPoints[1] := PointD(BottomRight);
  end;
  //now make fPts relative to the canvas surface
  with transformLayer do
    ctrlPoints := OffsetPath(ctrlPoints, Left, Top);

  buttonGroup := CreateButtonGroup(layeredImage.Root,
    ctrlPoints, bsRound, DefaultButtonSize, clGreen32);

  Invalidate;
  if isVerticalSkew then StatusBar1.SimpleText := ' VERTICAL SKEW'
  else StatusBar1.SimpleText := ' HORIZONTAL SKEW';
end;
//------------------------------------------------------------------------------

procedure TForm1.ResetVertProjective;
begin
  FreeAndNil(buttonGroup);
  FreeAndNil(rotateGroup);

  transformType := ttProjective;
  with transformLayer.MasterImage do     //with the master image
    ctrlPoints := Rectangle(Bounds);
  //now make fPts relative to the canvas surface
  with transformLayer do
    ctrlPoints := OffsetPath(ctrlPoints, Left, Top);

  buttonGroup := CreateButtonGroup(layeredImage.Root, ctrlPoints,
    bsRound, DefaultButtonSize, clGreen32);

  Invalidate;
  StatusBar1.SimpleText := ' PROJECTIVE TRANSFORM';
end;
//------------------------------------------------------------------------------

procedure TForm1.ResetSpline;
begin
  FreeAndNil(buttonGroup);
  FreeAndNil(rotateGroup);

  transformType := ttSpline;
  with transformLayer.MasterImage do
    ctrlPoints := MakePathI([0,0, Width div 2,0, Width,0]);

  //now make fPts relative to the canvas surface
  with transformLayer do
    ctrlPoints := OffsetPath(ctrlPoints, Left, Top);
  buttonGroup := CreateButtonGroup(layeredImage.Root, ctrlPoints,
    bsRound, DefaultButtonSize, clGreen32);

  Invalidate;
  StatusBar1.SimpleText := ' VERT SPLINE TRANSFORM: Right click to add control points';

end;
//------------------------------------------------------------------------------

procedure TForm1.ResetRotate;
begin
  FreeAndNil(buttonGroup);
  FreeAndNil(rotateGroup);

  transformType := ttAffineRotate;
  transformLayer.UpdateHitTestMaskOpaque;

  //nb: CtrlPoints are ignored with rotation

  if allowRotatePivotMove then
    transformLayer.PivotPt := transformLayer.MidPoint;

  //create rotate button group while also disabling pivot button moves
  rotateGroup := CreateRotatingButtonGroup(transformLayer,
    DefaultButtonSize, clWhite32, clAqua32, 0, -Angle90, allowRotatePivotMove);
  rotateGroup.AngleButton.CursorId := crSizeWE;

  Invalidate;
  StatusBar1.SimpleText := ' ROTATE TRANSFORM';
end;
//------------------------------------------------------------------------------

procedure TForm1.DoTransform;
var
  pt: TPoint;
  mat: TMatrixD;
  delta: double;
begin
  //except for rotation, use ctrlPoints to update the 'transformed' layer
  with transformLayer do
  begin
    Image.Assign(masterImage);
    case transformType of
      ttAffineSkew:
        begin
          mat := IdentityMatrix;
          if mnuVertSkew.Checked then
          begin
            delta := (ctrlPoints[1].Y-Image.Height) - ctrlPoints[0].Y;
            mat[0][1] := delta / Image.Width;
          end else
          begin
            delta := (ctrlPoints[1].X-Image.Width) - ctrlPoints[0].X;
            mat[1][0] := delta / Image.Height;
          end;
          //the returned pt states the offset of the new (transformed) image
          pt := AffineTransformImage(Image, mat);
          with Point(ctrlPoints[0]) do
            PositionAt(X +pt.X, Y +pt.Y);
        end;
      ttAffineRotate:
        begin
          //rotation is managed internally by transformlayer
          transformLayer.Angle := rotateGroup.Angle;
          StatusBar1.SimpleText := Format(' ROTATE TRANSFORM - angle:%1.0n',
            [transformLayer.Angle *180/PI]);
        end;
      ttProjective:
        begin
          if not ProjectiveTransform(image,
            Rectangle(image.Bounds), ctrlPoints, NullRect) then Exit;
          pt := GetBounds(ctrlPoints).TopLeft;
          PositionAt(pt);
        end;
      ttSpline:
        begin
          if not SplineVertTransform(Image, ctrlPoints,
            stQuadratic, clRed32, false, pt) then Exit;
          PositionAt(pt);
        end;
    end;
    UpdateHitTestMaskTransparent;
  end;
  Invalidate;
end;
//------------------------------------------------------------------------------

procedure TForm1.mnuVerticalSplineClick(Sender: TObject);
var
  rec: TRect;
  oldTopLeft: TPoint;
begin
  TMenuItem(Sender).Checked := true;

  //rather than started each transform afresh, let's make them additive
  with transformLayer do
  begin
    oldTopLeft := Bounds.TopLeft;
    MasterImage.Assign(Image);
    rec := MasterImage.CropTransparentPixels;
    //adjust for the cropped offset
    PositionAt(oldTopLeft.X + rec.Left, oldTopLeft.Y + rec.Top);
  end;

  if (Sender = mnuVertSkew) then            ResetSkew(true)
  else if (Sender = mnuHorizontalSkew) then ResetSkew(false)
  else if Sender = mnuVertProjective then   ResetVertProjective
  else if Sender = mnuVerticalSpline then   ResetSpline
  else                                      ResetRotate;
end;
//------------------------------------------------------------------------------

procedure TForm1.FormDestroy(Sender: TObject);
begin
  layeredImage.Free;
end;
//------------------------------------------------------------------------------

procedure TForm1.PopupMenu1Popup(Sender: TObject);
begin
  mnuAddNewCtrlPoint.Visible := transformType = ttSpline;

  GetCursorPos(popupPoint);
  popupPoint := ScreenToClient(popupPoint);
end;
//------------------------------------------------------------------------------

procedure TForm1.mnuAddNewCtrlPointClick(Sender: TObject);
var
  len: integer;
begin
  //add an extra spline control point
  if not Assigned(buttonGroup) then Exit;

  len := Length(ctrlPoints);
  SetLength(ctrlPoints, len +1);
  ctrlPoints[len] := PointD(popupPoint);
  with buttonGroup.AddButton(PointD(popupPoint)) do
    CursorId := crSizeAll;
  DoTransform;
end;
//------------------------------------------------------------------------------

procedure TForm1.FormDblClick(Sender: TObject);
begin
  if transformType <> ttSpline then Exit;
  GetCursorPos(popupPoint);
  popupPoint := ScreenToClient(popupPoint);
  mnuAddNewCtrlPointClick(nil);
end;
//------------------------------------------------------------------------------

procedure TForm1.pnlMainMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if (ssRight in Shift) then Exit; //popup menu

  clickPoint := Types.Point(X,Y);
  clickedLayer := layeredImage.GetLayerAt(clickPoint);
end;
//------------------------------------------------------------------------------

procedure TForm1.pnlMainMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  dx, dy, idx, altIdx: integer;
  pt: TPoint;
  layer: TLayer32;
begin
  pt := Types.Point(X,Y);

  //if not clicked-moving a layer, then update the cursor and exit.
  if not (ssLeft in Shift) then
  begin
    //get the top-most 'clickable' layer under the mouse cursor
    layer := layeredImage.GetLayerAt(pt);
    if Assigned(layer) then
      Cursor := layer.CursorId else
      Cursor := crDefault;
    Exit;
  end;
  if not Assigned(clickedLayer) then Exit;


  if clickedLayer = transformLayer then
  begin
    dx := pt.X - clickPoint.X;
    dy := pt.Y - clickPoint.Y;
    clickPoint := pt;
    ctrlPoints := OffsetPath(ctrlPoints, dx, dy);
    clickedLayer.Offset(dx, dy);
    if Assigned(buttonGroup) then buttonGroup.Offset(dx, dy);
    if Assigned(rotateGroup) and transformLayer.AutoPivot then
      rotateGroup.Offset(dx, dy);
    Invalidate;
  end else if clickedLayer.GroupOwner = rotateGroup then
  begin
    if clickedLayer = rotateGroup.PivotButton then
    begin
      //moving the pivot button in the rotation group
      dx := pt.X - clickPoint.X;
      dy := pt.Y - clickPoint.Y;
      clickPoint := pt;
      rotateGroup.Offset(dx, dy);
      transformLayer.PivotPt := rotateGroup.PivotButton.MidPoint;
    end else
    begin
      //moving the angle button in the rotation group
      clickedLayer.PositionCenteredAt(pt);
      UpdateRotatingButtonGroup(clickedLayer);
      //we could do the rotation here, but it's
      //much smoother when done via the AppIdle event.
      doTransformOnIdle := True;
    end;
    Invalidate;
  end
  else if clickedLayer.GroupOwner = buttonGroup then
  begin
    //clicking a general purpose button (layer)

    //if skewing, keep the buttons axis aligned
    if mnuVertSkew.Checked then
      pt.X := Round(clickedLayer.MidPoint.X);
    if mnuHorizontalSkew.Checked then
      pt.Y := Round(clickedLayer.MidPoint.Y);

    idx := clickedLayer.Index;
    if mnuVertProjective.Checked then
    begin
      //get the index of the moving button's vertical partner
      //noting that there are 4 buttons in the group ...
      altIdx := 3 - idx;
      ctrlPoints[altIdx].X := pt.X;
      buttonGroup[altIdx].PositionCenteredAt(ctrlPoints[altIdx]);
    end;
    clickedLayer.PositionCenteredAt(pt);
    ctrlPoints[idx] := PointD(pt);
    doTransformOnIdle := true;
  end;
end;
//------------------------------------------------------------------------------

procedure TForm1.mnuHideDesignersClick(Sender: TObject);
begin
  mnuHideDesigners.Checked := not mnuHideDesigners.Checked;
  mnuHideControls.Checked := mnuHideDesigners.Checked;
  Invalidate;
end;
//------------------------------------------------------------------------------

procedure TForm1.mnuOpenClick(Sender: TObject);
begin
  if not OpenDialog1.Execute then Exit;
  transformLayer.MasterImage.LoadFromFile(OpenDialog1.FileName);
  transformLayer.MasterImage.CropTransparentPixels;
  case transformType of
    ttAffineSkew:   ResetSkew(mnuVertSkew.Checked);
    ttProjective:   ResetVertProjective;
    ttSpline:       ResetSpline;
    ttAffineRotate: ResetRotate;
  end;
end;
//------------------------------------------------------------------------------

procedure TForm1.mnuPastefromClipboardClick(Sender: TObject);
begin
  if TImage32.CanPasteFromClipboard and
    transformLayer.MasterImage.PasteFromClipboard then
  begin
    transformLayer.MasterImage.CropTransparentPixels;
    case transformType of
      ttAffineSkew  : ResetSkew(mnuVertSkew.Checked);
      ttProjective  : ResetVertProjective;
      ttSpline      : ResetSpline;
      ttAffineRotate: ResetRotate;
    end;
  end;
end;
//------------------------------------------------------------------------------

procedure TForm1.File1Click(Sender: TObject);
begin
  mnuPastefromClipboard.Enabled := TImage32.CanPasteFromClipboard;
end;
//------------------------------------------------------------------------------

procedure TForm1.mnuSaveClick(Sender: TObject);
begin
  if SaveDialog1.Execute then
    transformLayer.Image.SaveToFile(SaveDialog1.FileName);
end;
//------------------------------------------------------------------------------

procedure TForm1.CopytoClipboard1Click(Sender: TObject);
begin
  transformLayer.Image.CopyToClipBoard;
end;
//------------------------------------------------------------------------------

procedure TForm1.Exit1Click(Sender: TObject);
begin
  Close;
end;
//------------------------------------------------------------------------------

end.
