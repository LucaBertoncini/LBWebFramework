unit uJSBasePOSTRequest;

{$mode ObjFPC}{$H+}

interface

uses
  JS, SysUtils, libjquery;

type
  { TJSBasePOSTRequest }

  TJSBasePOSTRequest = class(TObject)
    strict private
      FOnSuccess: TJQueryAjaxSettingsSuccessHandler;
      FOnError: TJQueryAjaxSettingsErrorHandler;

    public
      constructor Create(aRequestName: String); virtual; overload;

      function execute(): Boolean; virtual;

      property OnSuccess: TJQueryAjaxSettingsSuccessHandler read FOnSuccess write FOnSuccess;
      property OnError: TJQueryAjaxSettingsErrorHandler read FOnError write FOnError;

    published
      Request : String;
      Token   : String;
      SysCode : String;
  end;

  { TJSBasePOSTRequestHelper }

  TJSBasePOSTRequestHelper = class helper for TJSBasePOSTRequest
    function serializeAsJSON(): String;
  end;


implementation

uses
  web;

{ TJSBasePOSTRequest }

constructor TJSBasePOSTRequest.Create(aRequestName: String);
begin
  inherited Create;

  Request := aRequestName;
end;

function TJSBasePOSTRequest.execute(): Boolean;
var
  _Settings : TJSAjaxSettings;

begin
  _Settings          := TJSAjaxSettings.new;
  _Settings.method   := 'POST';
  _Settings.url      := window.location.protocol + '//' + window.location.host;
  _Settings.data     := Self.serializeAsJSON();
  _Settings.dataType := 'json';
  _Settings.success  := FOnSuccess;
  _Settings.error    := FOnError;

  TJQuery.ajax(_Settings);
  Result := True;

  _Settings := nil;
end;


{ TJSBasePOSTRequestHelper }

function TJSBasePOSTRequestHelper.serializeAsJSON(): String;
begin
  Result := TJSJSON.stringify(Self);
end;


end.

