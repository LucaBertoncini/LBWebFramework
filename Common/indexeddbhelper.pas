unit IndexedDBHelper;

{$mode ObjFPC}

interface

uses
  JS, Web, uLBWebUtils;

type
  { TIndexedDBHelper }
  TIndexedDBHelper = class(TObject)
  strict private
    FDB: TIDBDatabase;
    FDBName: String;
    FDBVersion: Integer;
    FStoreName: String;
    function GetDB: TJSPromise;
  public
    constructor Create(const aDBName: String; aDBVersion: Integer; const aStoreName: String);
    function GetRecord(const aId: String): TJSPromise;
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
  FDBName := aDBName;
  FDBVersion := aDBVersion;
  FStoreName := aStoreName;
end;

function TIndexedDBHelper.GetDB: TJSPromise;
begin
  Result := TJSPromise.New(procedure(resolve, reject: TJSPromiseResolver)
    var
      _Request: TJSIDBOpenDBRequest;
    begin
      if hasValue(FDB) then
      begin
        resolve(FDB);
        exit;
      end;
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
          reject(TJSIDBOpenDBRequest(e.target).error);
        end;
    end);
end;

function TIndexedDBHelper.GetRecord(const aId: String): TJSPromise;
var
  _DB: TIDBDatabase;
  _Transaction: TJSIDBTransaction;
  _Store: TJSIDBObjectStore;
  _Request: TJSIDBRequest;
begin
  Result := TJSPromise.New(procedure(resolve, reject: TJSPromiseResolver) async
    begin
      _DB := AWait(TIDBDatabase, Self.GetDB());
      _Transaction := _DB.transaction([FStoreName], 'readonly');
      _Store := _Transaction.objectStore(FStoreName);
      _Request := _Store.get(aId);
      _Request.onsuccess := function(e: TJSEvent): Boolean
        begin
          resolve(TJSIDBRequest(e.target).result);
        end;
      _Request.onerror := function(e: TJSEvent): Boolean
        begin
          reject(TJSIDBRequest(e.target).error);
        end;
    end);
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
end;


end.

