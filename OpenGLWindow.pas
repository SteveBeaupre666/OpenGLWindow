unit OpenGLWindow;
interface
////////////////////////////////////////////////////////////////////////////////////////////
uses
  Windows, Messages, Forms, Dialogs, Classes, Graphics, Controls, StdCtrls, OpenGL;
////////////////////////////////////////////////////////////////////////////////////////////
const
  ClearFlags = GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT;
////////////////////////////////////////////////////////////////////////////////////////////
type
  TOnMouseRollEvent = procedure(WheelDelta: SmallInt) of object;

  TOnStartup = procedure() of object;
  TOnCleanup = procedure() of object;

  TOnRenderScene = procedure() of object;
  TOnUpdateScene = procedure(ElapsedTime: Single) of object;
////////////////////////////////////////////////////////////////////////////////////////////
type
  TOpenGLWindow = class(TCustomControl)
  private

    dc: HDC;
    rc: HGLRC;

    FOnMouseRoll: TOnMouseRollEvent;

    FOnStartup: TOnStartup;
    FOnCleanup: TOnCleanup;

    FOnRenderScene: TOnRenderScene;
    FOnUpdateScene: TOnUpdateScene;

    procedure Reset();
    function  SetupPixelFormatDescriptor(): Boolean;
  protected
    procedure Paint; override;
    procedure WmMouseWheel(var Msg: TWMMouseWheel); message WM_MOUSEWHEEL;
  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;

    function  IsOpenGLInitialized(): Boolean;
    function  InitializeOpenGL(): Boolean;
    procedure ShutdownOpenGL();

    procedure SetVSync(Enabled: Boolean);

    procedure RenderScene();
    procedure UpdateScene(ElapsedTime: Single);

    procedure ClearScene(flags: GLbitfield = ClearFlags);
    procedure SetClearColor(r,g,b,a: Single);
    procedure SetColor3f(r,g,b: Single);
    procedure Set2DMode();
    procedure Swap();
  published

    property Align;
    property Anchors;
    property Color;
    property Cursor;
    property Hint;
    property Tag;
    property Visible;

    property Left;
    property Top;
    property Width;
    property Height;

    property OnKeyDown;
    property OnKeyUp;

    property OnMouseDown;
    property OnMouseUp;
    property OnMouseMove;

    property OnMouseRoll: TOnMouseRollEvent read FOnMouseRoll write FOnMouseRoll;

    property OnStartup: TOnStartup read FOnStartup write FOnStartup;
    property OnCleanup: TOnCleanup read FOnCleanup write FOnCleanup;

    property OnRenderScene: TOnRenderScene read FOnRenderScene write FOnRenderScene;
    property OnUpdateScene: TOnUpdateScene read FOnUpdateScene write FOnUpdateScene;
  end;
////////////////////////////////////////////////////////////////////////////////////////////
//function SwapIntervalEXT(interval: Integer): BOOL; stdcall; external 'OpenGL.dll';
////////////////////////////////////////////////////////////////////////////////////////////
procedure Register;
implementation
////////////////////////////////////////////////////////////////////////////////////////////
constructor TOpenGLWindow.Create(AOwner: TComponent);
begin
inherited Create(AOwner);

//SetVSync = 0;
Reset();

Left    := 0;
Top     := 0;
Width   := 256;
Height  := 256;

Visible := True;
Color   := clBlack;

Align   := alNone;
Anchors := [akLeft,akTop];

Tag     := 0;
Hint    := '';
Cursor  := crDefault;
end;
////////////////////////////////////////////////////////////////////////////////////////////
destructor TOpenGLWindow.Destroy;
begin
if(IsOpenGLInitialized()) then
  ShutdownOpenGL();
  
Inherited Destroy;
end;
////////////////////////////////////////////////////////////////////////////////////////////
procedure TOpenGLWindow.WmMouseWheel(var Msg: TWMMOUSEWHEEL);
begin
if(Assigned(OnMouseRoll)) then
  OnMouseRoll(Msg.WheelDelta);
end;
////////////////////////////////////////////////////////////////////////////////////////////
procedure TOpenGLWindow.Paint;
begin
if(IsOpenGLInitialized()) then begin
  //if(Assigned(OnRenderScene)) then
  //  OnRenderScene();
end else begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := clBlack;
  Canvas.FillRect(GetClientRect);
end;
end;
////////////////////////////////////////////////////////////////////////////////////////////
procedure TOpenGLWindow.Reset();
begin
dc := 0;
rc := 0;
end;
////////////////////////////////////////////////////////////////////////////////////////////
function TOpenGLWindow.IsOpenGLInitialized(): Boolean;
begin
Result := rc <> 0;
end;
////////////////////////////////////////////////////////////////////////////////////////////
function TOpenGLWindow.SetupPixelFormatDescriptor(): Boolean;
const
 PFDSize = sizeof(PIXELFORMATDESCRIPTOR);
var
  PixelFormat: Integer;
  PixelFormatDesc: PIXELFORMATDESCRIPTOR;
begin
ZeroMemory(@PixelFormatDesc, PFDSize);
PixelFormatDesc.nSize := PFDSize;
PixelFormatDesc.nVersion := 1;

PixelFormatDesc.iPixelType  := PFD_TYPE_RGBA;
PixelFormatDesc.dwLayerMask := PFD_MAIN_PLANE;
PixelFormatDesc.dwFlags     := PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER;

PixelFormatDesc.cColorBits  := 32;
PixelFormatDesc.cDepthBits  := 32;
PixelFormatDesc.cAlphaBits  := 8;

PixelFormat := ChoosePixelFormat(dc, @PixelFormatDesc);
if(PixelFormat = 0) then begin
  Result := False;
  Exit;
end;

if(SetPixelFormat(dc, PixelFormat, @PixelFormatDesc) = False) then begin
  Result := False;
  Exit;
end;

Result := True;
end;
////////////////////////////////////////////////////////////////////////////////////////////
function TOpenGLWindow.InitializeOpenGL(): Boolean;
begin
if(IsOpenGLInitialized()) then begin
  Result := False;
  Exit;
end;

dc := GetDC(Self.Handle);

if(SetupPixelFormatDescriptor() = False) then begin
  ReleaseDC(Self.Handle, dc);
  Reset();
  Result := False;
  Exit;
end;

rc := wglCreateContext(dc);
wglMakeCurrent(dc, rc);

///////////////////////////////////////////////////////////////////////////////////////////
glClearDepth(1.0);                 // Set depth buffer range...
glColor3f(1.0, 1.0, 1.0);          // Set color...
glClearColor(0.0, 0.0, 0.0, 0.0);  // Set background color...
glClear(ClearFlags);               // Clear stencil buffer
///////////////////////////////////////////////////////////////////////////////////////////
glDisable(GL_LIGHTING);            // Disable depth testing
glDisable(GL_DEPTH_TEST);          // Disable lighting
glEnable(GL_TEXTURE_2D);           // Enable texture mapping
///////////////////////////////////////////////////////////////////////////////////////////
glHint(GL_POINT_SMOOTH_HINT, GL_NICEST);
glHint(GL_LINE_SMOOTH_HINT, GL_NICEST);
glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST);
glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
///////////////////////////////////////////////////////////////////////////////////////////
glDepthFunc(GL_LEQUAL);    // Default deep test mode
glShadeModel(GL_SMOOTH);   // Enable smooth shading
glEnable(GL_LINE_SMOOTH);  // Enables line antialiasing
///////////////////////////////////////////////////////////////////////////////////////////
glPixelStorei(GL_UNPACK_ALIGNMENT, 4);  // Set default aligment for textures width...
///////////////////////////////////////////////////////////////////////////////////////////

//if(CheckExtension('WGL_EXT_swap_control')) then begin
//  SwapIntervalEXT = (PFVSYNC)wglGetProcAddress('wglSwapIntervalEXT');
//end;

///////////////////////////////////////////////////////////////////////////////////////////

if(Assigned(OnStartup)) then begin
  OnStartup();
end;

RenderScene();

///////////////////////////////////////////////////////////////////////////////////////////

Result := True;
end;
////////////////////////////////////////////////////////////////////////////////////////////
procedure TOpenGLWindow.ShutdownOpenGL();
begin
if(IsOpenGLInitialized()) then begin

  if(Assigned(OnCleanup)) then
    OnCleanup();

  if(rc <> 0) then begin wglDeleteContext(rc); end;
  if(dc <> 0) then begin ReleaseDC(Self.Handle, dc); end;

  Reset();
  Invalidate();
end;
end;
////////////////////////////////////////////////////////////////////////////////////////////
procedure TOpenGLWindow.SetVSync(Enabled: Boolean);
begin
{if(SwapIntervalEXT <> 0) then begin
  case(Enabled) of
    False: SwapIntervalEXT(0);
    True:  SwapIntervalEXT(1);
  end;
end;}
end;
////////////////////////////////////////////////////////////////////////////////////////////
procedure TOpenGLWindow.RenderScene();
begin
if((IsOpenGLInitialized()) and (Assigned(OnRenderScene))) then
  OnRenderScene();
end;
////////////////////////////////////////////////////////////////////////////////////////////
procedure TOpenGLWindow.UpdateScene(ElapsedTime: Single);
begin
if((IsOpenGLInitialized()) and (Assigned(OnUpdateScene))) then
  OnUpdateScene(ElapsedTime);
end;
////////////////////////////////////////////////////////////////////////////////////////////
procedure TOpenGLWindow.ClearScene(flags: GLbitfield = ClearFlags);
begin
glClear(flags);
end;
////////////////////////////////////////////////////////////////////////////////////////////
procedure TOpenGLWindow.SetClearColor(r,g,b,a: Single);
begin
glClearColor(r,g,b,a);
end;
////////////////////////////////////////////////////////////////////////////////////////////
procedure TOpenGLWindow.SetColor3f(r,g,b: Single);
begin
glColor3f(r,g,b);
end;
////////////////////////////////////////////////////////////////////////////////////////////
procedure TOpenGLWindow.Set2DMode();
begin
glViewport(0, 0, Width, Height);
glMatrixMode(GL_PROJECTION);

glLoadIdentity();
gluOrtho2D(0, Width, 0, Height);
glMatrixMode(GL_MODELVIEW);
end;
////////////////////////////////////////////////////////////////////////////////////////////
procedure TOpenGLWindow.Swap();
begin
SwapBuffers(dc);
end;
////////////////////////////////////////////////////////////////////////////////////////////
procedure Register;
begin
RegisterComponents('OpenGL', [TOpenGLWindow]);
end;
////////////////////////////////////////////////////////////////////////////////////////////
end.
