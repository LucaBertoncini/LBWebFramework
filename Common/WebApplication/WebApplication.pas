unit WebApplication;

interface

uses
  JS, Web, PageManager, LayoutComponents;

type
  // The main application shell class.
  // A specific application will inherit from this and override methods.

  { TWebApplication }

  TWebApplication = class(TObject)
  strict private
    FWakeLock : TJSObject;
    procedure refreshWakeLock(); async;

  strict protected
    FHeader: THeaderComponent;
    FFooter: TFooterComponent;
    FLeftColumn: TSideColumnComponent;
    FRightColumn: TSideColumnComponent;
    FPageManager: TPageManager;

    // Abstract method that descendants must implement to register their pages.
    procedure RegisterRoutes(); virtual; abstract;
    
    // Virtual methods for custom initialization of layout components.
    procedure InitializeHeader; virtual; async;
    procedure InitializeFooter; virtual; async;
    procedure InitializeLeftColumn; virtual; async;
    procedure InitializeRightColumn; virtual; async;
    // Main initialization sequence orchestrator.
    procedure InitializeLayout; virtual; async;


  public
    constructor Create(aHeaderClass, aFooterClass, aLeftColumnClass, aRightColumnClass: TLayoutComponentClass); virtual; reintroduce;
    destructor Destroy; override;

    // The main entry point to start the application.
    procedure Run; async;

    function RequestWakeLock(): boolean; async;
    procedure ReleaseWakeLock(); async;
    procedure SetupWakeLockAutoRenew();

    property PageManager: TPageManager read FPageManager;
  end;

var
  gv_WebApplication : TWebApplication = nil;

implementation

type
  TJSPromiseFunction = reference to function (aValue: JSValue = nil): TJSPromise;

{ TWebApplication }

constructor TWebApplication.Create(aHeaderClass, aFooterClass, aLeftColumnClass, aRightColumnClass: TLayoutComponentClass);
var
  _headerEl, _footerEl, _leftColEl, _rightColEl, _containerEl : TJSHTMLElement;
begin
  inherited Create;

  // Find the main layout elements from the DOM.
  _headerEl := TJSHTMLElement(document.getElementById('app-header'));
  _footerEl := TJSHTMLElement(document.getElementById('app-footer'));
  _leftColEl := TJSHTMLElement(document.getElementById('left-column'));
  _rightColEl := TJSHTMLElement(document.getElementById('right-column'));
  _containerEl := TJSHTMLElement(document.getElementById('center-container'));

  // Create instances of all the main layout components.
  if hasValue(aHeaderClass) then
    FHeader := THeaderComponent(aHeaderClass.Create(_headerEl))
  else
    FHeader := THeaderComponent.Create(_headerEl);

  if hasValue(aFooterClass) then
    FFooter := TFooterComponent(aFooterClass.Create(_footerEl))
  else
    FFooter := TFooterComponent.Create(_footerEl);

  if hasValue(aLeftColumnClass) then
    FLeftColumn := TSideColumnComponent(aLeftColumnClass.Create(_leftColEl))
  else
    FLeftColumn := TSideColumnComponent.Create(_leftColEl);

  if hasValue(aRightColumnClass) then
    FRightColumn := TSideColumnComponent(aRightColumnClass.Create(_rightColEl))
  else
    FRightColumn := TSideColumnComponent.Create(_rightColEl);

  FPageManager := TPageManager.Create(_containerEl);

  gv_WebApplication := Self;
end;

destructor TWebApplication.Destroy;
begin
  FPageManager.Free;
  FRightColumn.Free;
  FLeftColumn.Free;
  FFooter.Free;
  FHeader.Free;

  // Rimuove listener in modo sincrono
  document.removeEventListener('visibilitychange', @Self.refreshWakeLock);
  FWakeLock := nil;

  inherited Destroy;
end;

procedure TWebApplication.Run;
begin
  // Standard application startup sequence.
  Await(Self.InitializeLayout);
  Self.RegisterRoutes();
  FPageManager.StartRouting;
end;

procedure TWebApplication.InitializeLayout;
begin
  // Default sequence. Descendants can override this for different ordering.
  AWait(Self.InitializeHeader);
  AWait(Self.InitializeFooter);
  AWait(Self.InitializeLeftColumn);
  AWait(Self.InitializeRightColumn);
end;

function TWebApplication.RequestWakeLock(): boolean;
begin
  Result := false;

  if hasValue(window.navigator) and hasValue(window.navigator['wakeLock']) then
  begin
    try
      FWakeLock := AWait(TJSObject, TJSPromiseFunction(TJSObject(window.navigator['wakeLock'])['request'])('screen'));
      if FWakeLock <> nil then
      begin
        Result := True;
        console.log('Wake Lock activated');
      end;
    except
      on E: TJSError do
        FWakeLock := nil;
    end;
  end
  else
    console.log('Wake Lock non supportato dal browser');
end;

procedure TWebApplication.refreshWakeLock();
begin
  if FWakeLock <> nil then
  begin
    AWait(TJSObject, TJSPromiseFunction(FWakeLock['release'])());
    FWakeLock := AWait(TJSObject, TJSPromiseFunction(TJSObject(window.navigator['wakeLock'])['request'])('screen'));
  end;
end;

procedure TWebApplication.SetupWakeLockAutoRenew();
begin
  document.addEventListener('visibilitychange', @self.refreshWakeLock);
end;

procedure TWebApplication.ReleaseWakeLock();
begin
  if FWakeLock <> nil then
  begin
    AWait(TJSObject, TJSPromiseFunction(FWakeLock['release'])());
    FWakeLock := nil;
    console.log('Wake Lock released');
  end;
end;

procedure TWebApplication.InitializeHeader;
begin
  // Default implementation is empty.
end;

procedure TWebApplication.InitializeFooter;
begin
  // Default implementation is empty.
end;

procedure TWebApplication.InitializeLeftColumn;
begin
  // Default implementation is empty.
end;

procedure TWebApplication.InitializeRightColumn;
begin
  // Default implementation is empty.
end;

end.
