unit IndexedDBHelper;

{$mode ObjFPC}

interface

uses
  JS, Web, uLBWebUtils;

type
  (* TIndexedDBHelper
    Contenitore chiave/valore su IndexedDB. I record sono salvati come
    { id, data, timestamp }: GetRecord restituisce il record INTERO (o
    undefined se non esiste), il valore salvato e' nella proprieta' 'data'.
    Tutte le operazioni sono asincrone e vanno attese con AWait: StoreRecord,
    DeleteRecord e DeleteOldRecords terminano solo a transazione COMPLETATA, e
    un errore del database arriva al chiamante come eccezione. *)
  TIndexedDBHelper = class(TObject)
  strict private
    FDB: TIDBDatabase;
    // Promessa di apertura condivisa: chiamate concorrenti prima che il
    // database sia aperto non lo aprono piu' volte.
    FDBPromise: TJSPromise;
    FDBName: String;
    FDBVersion: Integer;
    FStoreName: String;
    function GetDB: TJSPromise;
    function RequestToPromise(aRequest: TJSIDBRequest): TJSPromise;
    function TransactionToPromise(aTransaction: TJSIDBTransaction): TJSPromise;
  public
    constructor Create(const aDBName: String; aDBVersion: Integer; const aStoreName: String);
    function GetRecord(const aId: String): JSValue; async;
    procedure StoreRecord(const aId: String; const aDataToStore: JSValue); async;
    procedure DeleteRecord(const aId: String); async;
    procedure DeleteOldRecords(aMaxAgeInMs: NativeInt); async;
  end;

implementation

{ TIndexedDBHelper }

constructor TIndexedDBHelper.Create(const aDBName: String; aDBVersion: Integer; const aStoreName: String);
begin
  inherited Create;
  FDB := nil;
  FDBPromise := nil;
  FDBName := aDBName;
  FDBVersion := aDBVersion;
  FStoreName := aStoreName;
end;

function TIndexedDBHelper.GetDB: TJSPromise;
begin
  if hasValue(FDBPromise) then
  begin
    Result := FDBPromise;
    Exit;
  end;

  FDBPromise := TJSPromise.New(procedure(resolve, reject: TJSPromiseResolver)
    var
      _Request: TJSIDBOpenDBRequest;
    begin
      _Request := globalThis.indexedDB.open(FDBName, FDBVersion);

      _Request.onupgradeneeded := function(e: TJSEvent): Boolean
        var
          db: TIDBDatabase;
          storeExists : Boolean;
          i : Integer;
          _Opts : TJSCreateObjectStoreOptions;
        begin
          db := TIDBDatabase(TJSIDBOpenDBRequest(e.target).result);

          storeExists := False;
          for i := 0 to High(db.objectStoreNames) do
          begin
            if db.objectStoreNames[i] = FStoreName then
            begin
              storeExists := True;
              break;
            end;
          end;

          if not storeExists then
          begin
            _Opts.keyPath := 'id';
            db.createObjectStore(FStoreName, _Opts);
          end;
        end;

      _Request.onsuccess := function(e: TJSEvent): Boolean
        begin
          FDB := TIDBDatabase(TJSIDBOpenDBRequest(e.target).result);
          resolve(FDB);
        end;

      _Request.onerror := function(e: TJSEvent): Boolean
        begin
          // Apertura fallita: non resta in cache, la prossima chiamata riprova.
          FDBPromise := nil;
          reject(TJSIDBOpenDBRequest(e.target).error);
        end;
    end);

  Result := FDBPromise;
end;

function TIndexedDBHelper.RequestToPromise(aRequest: TJSIDBRequest): TJSPromise;
begin
  Result := TJSPromise.New(procedure(resolve, reject: TJSPromiseResolver)
    begin
      aRequest.onsuccess := function(e: TJSEvent): Boolean
        begin
          resolve(TJSIDBRequest(e.target).result);
        end;
      aRequest.onerror := function(e: TJSEvent): Boolean
        begin
          reject(TJSIDBRequest(e.target).error);
        end;
    end);
end;

function TIndexedDBHelper.TransactionToPromise(aTransaction: TJSIDBTransaction): TJSPromise;
begin
  // La scrittura e' durevole solo a transazione completata: e' quello,
  // non la fine della singola richiesta, il momento in cui risolvere.
  Result := TJSPromise.New(procedure(resolve, reject: TJSPromiseResolver)
    begin
      aTransaction.oncomplete := function(e: TJSEvent): Boolean
        begin
          resolve(True);
        end;
      aTransaction.onerror := function(e: TJSEvent): Boolean
        begin
          reject(aTransaction.error);
        end;
      aTransaction.onabort := function(e: TJSEvent): Boolean
        begin
          reject(aTransaction.error);
        end;
    end);
end;

function TIndexedDBHelper.GetRecord(const aId: String): JSValue;
var
  _DB: TIDBDatabase;
  _Transaction: TJSIDBTransaction;
  _Store: TJSIDBObjectStore;
begin
  // Niente executor asincrono dentro TJSPromise.New (versione precedente): se
  // GetDB falliva, l'errore restava nella promessa interna e quella esterna
  // non si risolveva mai. Qui l'errore si propaga al chiamante.
  _DB := AWait(TIDBDatabase, Self.GetDB());
  _Transaction := _DB.transaction([FStoreName], 'readonly');
  _Store := _Transaction.objectStore(FStoreName);
  Result := AWait(JSValue, Self.RequestToPromise(_Store.get(aId)));
end;

procedure TIndexedDBHelper.StoreRecord(const aId: String; const aDataToStore: JSValue);
var
  _DB: TIDBDatabase;
  _Transaction: TJSIDBTransaction;
  _Store: TJSIDBObjectStore;
  _Data: TJSObject;
begin
  _DB := AWait(TIDBDatabase, Self.GetDB());
  _Transaction := _DB.transaction([FStoreName], 'readwrite');
  _Store := _Transaction.objectStore(FStoreName);
  _Data := TJSObject.new;
  _Data['id'] := aId;
  _Data['data'] := aDataToStore;
  _Data['timestamp'] := TJSDate.now();
  _Store.put(_Data);
  AWait(JSValue, Self.TransactionToPromise(_Transaction));
end;

procedure TIndexedDBHelper.DeleteRecord(const aId: String);
var
  _DB: TIDBDatabase;
  _Transaction: TJSIDBTransaction;
  _Store: TJSIDBObjectStore;
begin
  _DB := AWait(TIDBDatabase, Self.GetDB());
  _Transaction := _DB.transaction([FStoreName], 'readwrite');
  _Store := _Transaction.objectStore(FStoreName);
  _Store.delete(aId);
  AWait(JSValue, Self.TransactionToPromise(_Transaction));
end;

procedure TIndexedDBHelper.DeleteOldRecords(aMaxAgeInMs: NativeInt);
var
  _DB: TIDBDatabase;
  _Transaction: TJSIDBTransaction;
  _Store: TJSIDBObjectStore;
  _CursorRequest: TJSIDBRequest;
  _CutoffDate: NativeInt;
begin
  _DB := AWait(TIDBDatabase, Self.GetDB());
  _Transaction := _DB.transaction([FStoreName], 'readwrite');
  _Store := _Transaction.objectStore(FStoreName);
  _CutoffDate := round(TJSDate.now()) - aMaxAgeInMs;

  _CursorRequest := _Store.openCursor();
  _CursorRequest.onsuccess := function(e: TJSEvent): Boolean
    var
      _Cursor: TJSIDBCursor;
    begin
      _Cursor := TJSIDBCursor(TJSIDBRequest(e.target).result);
      if hasValue(_Cursor) then
      begin
        if NativeInt(TJSObject(_Cursor.Value)['timestamp']) < _CutoffDate then
          _Cursor.delete();

        _Cursor.continue();
      end;
    end;

  AWait(JSValue, Self.TransactionToPromise(_Transaction));
end;


end.
