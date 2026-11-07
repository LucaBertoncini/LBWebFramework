unit EventsManager;

{$mode ObjFPC}{$H+}

interface

uses
  JS, SysUtils;

type
  TjsEventCallback = reference to procedure(Sender: JSValue);

  { TEventSubscription }

  TjsEventSubscription = class(TObject)
  public
    Callback: TjsEventCallback;
    Owner: JSValue;
  end;

  { TEventsManager }

  TjsEventsManager = class
  strict private
    FListeners: TJSMap; // key: event name, value: array of TEventSubscription
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddEvent(const EventName: String);
    procedure AddListener(const EventName: String; Owner: JSValue; Callback: TjsEventCallback);
    procedure RemoveListenersFor(const Owner: JSValue);
    procedure RaiseEvent(const EventName: String; Sender: JSValue);

    function HasEvent(const EventName: String): Boolean;
  end;

var
  gv_EventsManager : TjsEventsManager = nil;

implementation

{ TEventsManager }

constructor TjsEventsManager.Create;
begin
  inherited Create;
  FListeners := TJSMap.new;
end;

destructor TjsEventsManager.Destroy;
var
  _Iter : TJSIterator;
  _Entry: TJSIteratorValue;
  listeners: TJSArray;
  i: Integer;
begin
  _Iter  := FListeners.values();
  _Entry := _Iter.next;
  while not _Entry.done do
  begin
    listeners := TJSArray(_Entry.value);
    for i := 0 to listeners.length - 1 do
      TjsEventSubscription(listeners[i]).Destroy;
    _Entry := _Iter.next;
  end;
  FListeners := nil;
  inherited Destroy;
end;

procedure TjsEventsManager.AddEvent(const EventName: String);
begin
  if not FListeners.has(EventName) then
    FListeners.&set(EventName, TJSArray.new);
end;

procedure TjsEventsManager.AddListener(const EventName: String; Owner: JSValue; Callback: TjsEventCallback);
var
  listeners: TJSArray;
  subscription: TjsEventSubscription;

begin
  if not FListeners.has(EventName) then
    Self.AddEvent(EventName);

  listeners := TJSArray(FListeners.get(EventName));

  subscription := TjsEventSubscription.Create;
  subscription.Owner := Owner;
  subscription.Callback := Callback;

  listeners.push(subscription);
end;

procedure TjsEventsManager.RemoveListenersFor(const Owner: JSValue);
var
  iterator: TJSIterator;
  entry: TJSIteratorValue;
  key: JSValue;
  i: Integer;
  listeners: TJSArray;
  s: TjsEventSubscription;
begin
  iterator := FListeners.keys();

  entry := iterator.next;
  while not entry.done do
  begin
    key := entry.value;
    listeners := TJSArray(FListeners.get(String(key)));

    for i := listeners.length - 1 downto 0 do
    begin
      s := TjsEventSubscription(listeners[i]);
      if s.Owner = Owner then
      begin
        listeners.splice(i, 1);
        s.Destroy;
      end;
    end;

    entry := iterator.next;
  end;
end;

procedure TjsEventsManager.RaiseEvent(const EventName: String; Sender: JSValue);
var
  listeners: TJSArray;
  i: Integer;
  s: TjsEventSubscription;
begin
  if FListeners.has(EventName) then
  begin

    // Create a copy of the array in case a handler unsubscribes during the loop
    listeners := TJSArray(FListeners.get(EventName)).slice(0);

    for i := 0 to listeners.length - 1 do
    begin
      s := TjsEventSubscription(listeners[i]);
      if Assigned(s.Callback) then
      begin
        try
          s.Callback(Sender);
        except
        end;
      end;
    end;

  end;
end;

function TjsEventsManager.HasEvent(const EventName: String): Boolean;
begin
  Result := FListeners.has(EventName);
end;

initialization
  gv_EventsManager := TjsEventsManager.Create;


end.


