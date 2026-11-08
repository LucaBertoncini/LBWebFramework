unit WSManager;

{$mode ObjFPC}{$H+}

interface

uses
  JS, Web, SysUtils, EventsManager;


const
  cWS_Connected      = 'ws.connected';       // connessione stabilita
  cWS_Disconnected   = 'ws.disconnected';    // connessione persa



type
  TWSState = (wsDisconnected, wsConnecting, wsConnected, wsError);

  TWSStateChangeEvent = reference to procedure(aState: TWSState);

  { TWSManager }
  // Singleton — usare gv_WSManager.
  // Apre una singola connessione WebSocket verso il server.
  // Quando arriva un messaggio lo decodifica e rilancia l'evento
  // sull'EventsManager globale. I widget si iscrivono agli eventi
  // che li interessano tramite gv_EventsManager.AddListener.

  TWSManager = class(TObject)
  strict private
    FSocket          : TJSWebSocket;
    FState           : TWSState;
    FReconnectTimer  : Integer;
    FReconnectDelay  : Integer;  // ms, con backoff esponenziale
    FOnStateChange   : TWSStateChangeEvent;
    FURL             : String;
    FEventFieldName  : String;
    FDataFieldName   : String;

    procedure Connect;
    procedure ScheduleReconnect;

    function  OnOpen   (aEvent: TJSEvent)         : Boolean;
    function  OnMessage(aEvent: TEventListenerEvent) : Boolean;
    function  OnClose  (aEvent: TJSEvent)          : Boolean;
    function  OnError  (aEvent: TJSEvent)          : Boolean;

    procedure SetState(aState: TWSState);
    procedure DispatchMessage(const aEvent: String; aData: JSValue);

  public
    constructor Create(const aURL: String);
    destructor  Destroy; override;

    procedure Open;
    procedure Close;

    function sendMessage(aMsg: TJSObject): Boolean;

    property State          : TWSState             read  FState;
    property EventFieldName : String               write FEventFieldName;
    // Campo del messaggio che contiene il payload da passare ai listener.
    // Vuoto (default): ai listener arriva l'intero messaggio.
    property DataFieldName  : String               write FDataFieldName;
    property OnStateChange  : TWSStateChangeEvent  write FOnStateChange;
  end;


implementation

uses
  Math;

{ TWSManager }

constructor TWSManager.Create(const aURL: String);
begin
  inherited Create;

  FURL            := aURL;
  FState          := wsDisconnected;
  FSocket         := nil;
  FReconnectTimer := 0;
  FReconnectDelay := 2000;
  FEventFieldName := 'event';
  FDataFieldName  := '';
end;

destructor TWSManager.Destroy;
begin
  Self.Close;
  inherited Destroy;
end;

// ── Connessione ───────────────────────────────────────────────────────────────

procedure TWSManager.Open;
begin
  Self.Connect;
end;

procedure TWSManager.Connect;
begin
  if FReconnectTimer <> 0 then
  begin
    window.clearTimeout(FReconnectTimer);
    FReconnectTimer := 0;
  end;

  if hasValue(FSocket) then
  begin
    FSocket.onopen    := nil;
    FSocket.onmessage := nil;
    FSocket.onclose   := nil;
    FSocket.onerror   := nil;
    try FSocket.close(); except end;
    FSocket := nil;
  end;

  Self.SetState(wsConnecting);

  FSocket           := TJSWebSocket.new(FURL);
  FSocket.onopen    := @Self.OnOpen;
  FSocket.onmessage := @Self.OnMessage;
  FSocket.onclose   := @Self.OnClose;
  FSocket.onerror   := @Self.OnError;
end;

procedure TWSManager.Close;
var
  _WasConnected: Boolean;
begin
  _WasConnected := FState = wsConnected;
  if FReconnectTimer <> 0 then
  begin
    window.clearTimeout(FReconnectTimer);
    FReconnectTimer := 0;
  end;

  if hasValue(FSocket) then
  begin
    FSocket.onopen    := nil;
    FSocket.onmessage := nil;
    FSocket.onclose   := nil;
    FSocket.onerror   := nil;
    try FSocket.close(); except end;
    FSocket := nil;
  end;

  Self.SetState(wsDisconnected);

  // Coerenza con OnClose: anche la chiusura voluta notifica la
  // disconnessione (altrimenti chi ascolta resta convinto che sia aperta).
  if _WasConnected and (gv_EventsManager <> nil) then
    gv_EventsManager.RaiseEvent(cWS_Disconnected, nil);
end;

function TWSManager.sendMessage(aMsg: TJSObject): Boolean;
var
  _sMsg : String;

begin
  Result := False;

  // Con il socket ancora in connessione (o chiuso) send solleverebbe
  // un'eccezione InvalidStateError: si invia solo a connessione aperta.
  if (FState = wsConnected) and hasValue(FSocket) and hasValue(aMsg) then
  begin
    _sMsg := JS.TJSJSON.stringify(aMsg);
    FSocket.send(_sMsg);
    Result := True;
  end;
end;

procedure TWSManager.ScheduleReconnect;
begin
  if FReconnectTimer <> 0 then Exit;

  console.log('WSManager: reconnect in ' + IntToStr(FReconnectDelay) + 'ms');

  FReconnectTimer := window.setTimeout(
    procedure begin
      FReconnectTimer := 0;
      Self.Connect;
    end,
    FReconnectDelay
  );

  // Backoff esponenziale: 2s → 4s → 8s → max 30s
  FReconnectDelay := Min(FReconnectDelay * 2, 30000);
end;

// ── Handler socket ────────────────────────────────────────────────────────────

function TWSManager.OnOpen(aEvent: TJSEvent): Boolean;
begin
  Result          := True;
  FReconnectDelay := 2000;  // reset backoff
  Self.SetState(wsConnected);
  gv_EventsManager.RaiseEvent(cWS_Connected, nil);
  console.log('WSManager: connected to ' + FURL);
end;

function TWSManager.OnMessage(aEvent: TEventListenerEvent): Boolean;
var
  _Raw  : String;
  _Msg  : TJSObject;
  _Evt  : String;
  _Data : JSValue;
begin
  Result := True;
  if aEvent._type = 'message' then
  begin

  _Raw   := String(TJSMessageEvent(aEvent).Data);

    try
      _Msg  := TJSObject(TJSJSON.parse(_Raw));
      // Un messaggio privo del campo evento non deve diventare l'evento
      // "undefined": lo si scarta.
      if isString(_Msg[FEventFieldName]) then
        _Evt := String(_Msg[FEventFieldName])
      else
        _Evt := '';

      if _Evt <> '' then
      begin
        if FDataFieldName = '' then
          _Data := _Msg
        else
          _Data := _Msg[FDataFieldName];

        Self.DispatchMessage(_Evt, _Data);
      end;

    except
      on E: Exception do
        console.warn('WSManager: invalid message: ' + E.Message);
    end;

  end;
end;

function TWSManager.OnClose(aEvent: TJSEvent): Boolean;
begin
  Result := True;
  Self.SetState(wsDisconnected);
  gv_EventsManager.RaiseEvent(cWS_Disconnected, nil);
  console.log('WSManager: disconnected — scheduling reconnect');
  Self.ScheduleReconnect;
end;

function TWSManager.OnError(aEvent: TJSEvent): Boolean;
begin
  Result := True;
  Self.SetState(wsError);
  console.warn('WSManager: socket error');
  // OnClose verrà chiamato subito dopo da browser — ScheduleReconnect lì
end;

// ── Dispatch ──────────────────────────────────────────────────────────────────

procedure TWSManager.DispatchMessage(const aEvent: String; aData: JSValue);
begin
  // Rilancia l'evento sul bus globale.
  // I widget si iscrivono con gv_EventsManager.AddListener(eventName, Self, ...)
  // e ricevono aData come Sender: JSValue.
  gv_EventsManager.RaiseEvent(aEvent, aData);
end;

procedure TWSManager.SetState(aState: TWSState);
begin
  if FState = aState then Exit;
  FState := aState;
  if Assigned(FOnStateChange) then
    FOnStateChange(aState);
end;

end.
