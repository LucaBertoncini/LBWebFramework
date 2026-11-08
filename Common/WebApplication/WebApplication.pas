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
    // True dal momento in cui l'applicazione ha ottenuto il wake lock fino a
    // ReleaseWakeLock: e' l'unico caso in cui ha senso riacquisirlo quando
    // la pagina torna visibile (il browser lo rilascia da solo quando la
    // pagina viene nascosta).
    FWakeLockWanted : Boolean;
    // Riferimento conservato per poter RIMUOVERE il listener: ogni
    // @Self.Metodo crea un callback nuovo, quindi passarlo una seconda volta
    // a removeEventListener non rimuoverebbe nulla.
    FVisibilityHandler : TJSRawEventHandler;
    procedure refreshWakeLock(); async;
    procedure HandleVisibilityChange(aEvent: TJSEvent);

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

uses
  SysUtils;

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
  if FVisibilityHandler <> nil then
  begin
    document.removeEventListener('visibilitychange', FVisibilityHandler);
    FVisibilityHandler := nil;
  end;
  FWakeLock := nil;
  FWakeLockWanted := False;

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
        FWakeLockWanted := True;
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
  if not FWakeLockWanted then Exit;

  try
    // Il lock precedente e' gia' stato rilasciato dal browser quando la
    // pagina e' stata nascosta; rilasciarlo ancora e' innocuo ma, se fallisce,
    // non deve impedire di richiederne uno nuovo.
    if FWakeLock <> nil then
    begin
      try
        AWait(TJSObject, TJSPromiseFunction(FWakeLock['release'])());
      except
      end;
    end;
    FWakeLock := AWait(TJSObject, TJSPromiseFunction(TJSObject(window.navigator['wakeLock'])['request'])('screen'));
  except
    on E: Exception do
      console.warn('Wake Lock: impossibile riacquisirlo: ' + E.Message);
  end;
end;

procedure TWebApplication.HandleVisibilityChange(aEvent: TJSEvent);
begin
  // La richiesta del wake lock e' consentita solo a pagina visibile: con la
  // pagina nascosta il browser la rifiuta (NotAllowedError).
  if String(TJSObject(document)['visibilityState']) = 'visible' then
    Self.refreshWakeLock;
end;

procedure TWebApplication.SetupWakeLockAutoRenew();
begin
  if FVisibilityHandler <> nil then Exit; // gia' attivo: nessun doppio listener
  FVisibilityHandler := @Self.HandleVisibilityChange;
  document.addEventListener('visibilitychange', FVisibilityHandler);
end;

procedure TWebApplication.ReleaseWakeLock();
begin
  FWakeLockWanted := False;
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
