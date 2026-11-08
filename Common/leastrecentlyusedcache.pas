unit LeastRecentlyUsedCache;

{$mode ObjFPC}

interface

uses
  Classes, JS, SysUtils;

type
  { TLRUCache
    Cache a capacita' fissa che scarta l'elemento usato meno di recente.
    Usa l'ordine di inserimento di TJSMap (garantito da JavaScript): per
    segnare una chiave come "usata ora" basta rimuoverla e reinserirla,
    la meno recente e' sempre la prima. Put/Get/Has/Remove sono O(1). }
  TLRUCache = class(TObject)
  private
    FCapacity: Integer;
    FMap: TJSMap;
    procedure Touch(const Key: string; const Value: JSValue);
  public
    constructor Create(ACapacity: Integer);
    procedure Put(const Key: string; const Value: JSValue);
    function Get(const Key: string): JSValue;
    function Has(const Key: string): Boolean;
    procedure Remove(const Key: string);
    procedure Clear;
    function Count: Integer;
  end;

implementation

constructor TLRUCache.Create(ACapacity: Integer);
begin
  inherited Create;
  // Una capacita' < 1 non avrebbe senso (e la vecchia versione, in quel caso,
  // cercava di scartare da una lista vuota): si impone almeno 1.
  if ACapacity < 1 then
    ACapacity := 1;
  FCapacity := ACapacity;
  FMap := TJSMap.new;
end;

procedure TLRUCache.Touch(const Key: string; const Value: JSValue);
begin
  FMap.delete(Key);
  FMap.&set(Key, Value);
end;

procedure TLRUCache.Put(const Key: string; const Value: JSValue);
var
  _Oldest: TJSIteratorValue;
begin
  if FMap.has(Key) then
    Self.Touch(Key, Value)
  else
  begin
    if FMap.size >= FCapacity then
    begin
      // La prima chiave dell'iteratore e' la meno recente.
      _Oldest := FMap.keys().next();
      if not _Oldest.done then
        FMap.delete(String(_Oldest.value));
    end;
    FMap.&set(Key, Value);
  end;
end;

function TLRUCache.Get(const Key: string): JSValue;
begin
  if not FMap.has(Key) then
    Exit(nil);

  Result := FMap.get(Key);
  Self.Touch(Key, Result);
end;

function TLRUCache.Has(const Key: string): Boolean;
begin
  Result := FMap.has(Key);
end;

procedure TLRUCache.Remove(const Key: string);
begin
  FMap.delete(Key);
end;

procedure TLRUCache.Clear;
begin
  FMap.clear;
end;

function TLRUCache.Count: Integer;
begin
  Result := FMap.size;
end;

end.
