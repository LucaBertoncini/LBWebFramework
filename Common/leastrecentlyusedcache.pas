unit LeastRecentlyUsedCache;

{$mode ObjFPC}

interface

uses
  Classes, JS, SysUtils;

type
  TLRUCache = class(TObject)
  private
    FCapacity: Integer;
    FMap: TJSMap;
    FOrder: TJSArray; // mantiene l'ordine di utilizzo
  public
    constructor Create(ACapacity: Integer);
    procedure Put(const Key: string; const Value: JSValue);
    function Get(const Key: string): JSValue;
    function Has(const Key: string): Boolean;
  end;

implementation

constructor TLRUCache.Create(ACapacity: Integer);
begin
  FCapacity := ACapacity;
  FMap := TJSMap.new;
  FOrder := TJSArray.new;
end;

procedure TLRUCache.Put(const Key: string; const Value: JSValue);
var
  Index: Integer;
  Oldest : String;
begin
  if FMap.has(Key) then
  begin
    // Rimuove la chiave dall'ordine precedente
    Index := FOrder.indexOf(Key);
    if Index >= 0 then FOrder.splice(Index, 1);
  end
  else if FOrder.length >= FCapacity then
  begin
    // Rimuove la meno recente
    Oldest := string(FOrder.shift);
    FMap.delete(Oldest);
  end;

  // Aggiunge la nuova chiave in fondo (più recente)
  FOrder.push(Key);
  FMap.&set(Key, Value);
end;

function TLRUCache.Get(const Key: string): JSValue;
var
  Index: Integer;
begin
  if not FMap.has(Key) then Exit(nil);

  // Aggiorna l'ordine di utilizzo
  Index := FOrder.indexOf(Key);
  if Index >= 0 then FOrder.splice(Index, 1);
  FOrder.push(Key);

  Result := FMap.get(Key);
end;

function TLRUCache.Has(const Key: string): Boolean;
begin
  Result := FMap.has(Key);
end;

end.

