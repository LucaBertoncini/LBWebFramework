unit uJSGoogleMap;

{$mode ObjFPC}{$H+}
{$modeswitch externalclass}
{$modeswitch advancedrecords}

interface

uses
  JS, Classes, SysUtils, web;

type
  TGMapType = (gmRoadmap, gmSatellite, gmHybrid, gmTerrain);

  TJSGoogleMap = class external name 'google.maps.Map' (TJSObject)
    procedure setCenter(latLng: TJSObject);
    procedure setZoom(zoom: Integer);
    procedure setRotation(heading: Double);
    procedure fitBounds(bounds: TJSObject);
    function getBounds(): TJSObject;
    procedure setMapTypeId(mapTypeId: String);
  end;

  TJSGoogleMarker = class external name 'google.maps.Marker' (TJSObject)
    procedure setMap(map: TJSGoogleMap);
    procedure setPosition(latLng: TJSObject);
    procedure setIcon(icon: TJSObject);
  end;

  TJSGooglePolyline = class external name 'google.maps.Polyline' (TJSObject)
    procedure setMap(map: TJSGoogleMap);
  end;

  TGMap_onClickEvent = reference to procedure(aEvent: TJSObject); safecall;

  { TGMap_MarkerOptions }

  TGMap_MarkerOptions = record
    Code: String;
    imgURL: String;
    Lon, Lat: Double;
    anchorX, anchorY: Double;
    centerMap: Boolean;
    scale: Double;

    procedure Initialize();
    procedure setMaxDim(aWidth, aHeight: NativeInt; aMaxValue: NativeInt);
  end;

  { TGMap_LineOptions }

  TGMap_LineOptions = record
    color: String;
    width: Integer;
    lineDash: TJSArray;

    procedure Initialize();
  end;

  { TGoogleMap }

  TGoogleMap = class(TObject)
    strict private
      FMap: TJSGoogleMap;
      FMarkersHashMap: TJSMap;
      FOpacity: Double;
      FClickListener: JSValue;
      FRouteLayers: TJSArray;
      FMapType: TGMapType;

      procedure destroyMap();
      procedure set_OnClick(AValue: TGMap_OnClickEvent);
      procedure set_MapType(AValue: TGMapType);

    public
      constructor Create;
      destructor Destroy; override;

      function createMap(aDestinationDiv: String): Boolean;
      function updateMarker(options: TGMap_MarkerOptions): Boolean;

      function addLineLayer(coords: TJSArray; lineOptions: TGMap_LineOptions): JSValue;
      procedure clearLineLayers;
      procedure setMapRotation(aRadiantValue: Double);

      procedure resize();

      function viewExtent(): TJSArray;

      property Opacity: Double write FOpacity;
      property onClick: TGMap_onClickEvent write set_OnClick;
      property MapType: TGMapType read FMapType write set_MapType;
  end;

  TOnGoogleMapsInitialization = procedure() of object;

  function isGoogleMapsLoaded(): Boolean;
  function initializeGoogleMaps(aApiKey: String; onSuccessCallback: TOnGoogleMapsInitialization): Boolean; async;

implementation

uses
  uLBwebUtils;

const
  cGoogleMapsLibraryState_NotInitialized = Byte(0);
  cGoogleMapsLibraryState_Initializing = Byte(1);
  cGoogleMapsLibraryState_Loaded = Byte(2);
  cGoogleMapsLibraryState_NotLoaded = Byte(3);

var
  gv_GoogleMapsState: Byte = cGoogleMapsLibraryState_NotInitialized;

function initializeGoogleMaps(aApiKey: String; onSuccessCallback: TOnGoogleMapsInitialization): Boolean;
var
  scriptUrl: String;
begin
  Result := gv_GoogleMapsState = cGoogleMapsLibraryState_Loaded;

  if not Result and (gv_GoogleMapsState = cGoogleMapsLibraryState_NotInitialized) then
  begin
    try
      gv_GoogleMapsState := cGoogleMapsLibraryState_Initializing;

      scriptUrl := 'https://maps.googleapis.com/maps/api/js?key=' + aApiKey + '&v=weekly';
      Result := AWait(Boolean, loadResource(scriptUrl, 'js'));

      if Result then
        gv_GoogleMapsState := cGoogleMapsLibraryState_Loaded
      else
        gv_GoogleMapsState := cGoogleMapsLibraryState_NotLoaded;

    except
      on E: TJSError do
      begin
        Result := False;
        console.warn(E);
      end;
    end;
  end;

  if gv_GoogleMapsState = cGoogleMapsLibraryState_Loaded then
  begin
    if onSuccessCallback <> nil then
      onSuccessCallback();
  end;
end;

function isGoogleMapsLoaded(): Boolean;
begin
  Result := False;
  asm
    Result = (typeof google !== "undefined" && typeof google.maps !== "undefined");
  end;
end;

{ TGMap_MarkerOptions }

procedure TGMap_MarkerOptions.Initialize();
begin
  Code := '';
  imgURL := '';
  Lon := 0;
  Lat := 0;
  anchorX := 0.5;
  anchorY := 0.5;
  scale := 1;
  centerMap := False;
end;

procedure TGMap_MarkerOptions.setMaxDim(aWidth, aHeight: NativeInt; aMaxValue: NativeInt);
var
  _MaxW, _MaxH: Double;
begin
  _MaxW := aMaxValue / aWidth;
  _MaxH := aMaxValue / aHeight;
  if _MaxW < _MaxH then
    scale := _MaxW
  else
    scale := _MaxH;
end;

{ TGMap_LineOptions }

procedure TGMap_LineOptions.Initialize();
begin
  color := '#000000';
  width := 3;
  lineDash := TJSArray.new;
end;

{ TGoogleMap }

procedure TGoogleMap.set_MapType(AValue: TGMapType);
var
  mapTypeId: String;
begin
  FMapType := AValue;
  
  case FMapType of
    gmRoadmap: mapTypeId := 'roadmap';
    gmSatellite: mapTypeId := 'satellite';
    gmHybrid: mapTypeId := 'hybrid';
    gmTerrain: mapTypeId := 'terrain';
  end;

  if FMap <> nil then
  begin
    asm
      this.FMap.setMapTypeId(mapTypeId);
    end;
  end;
end;

procedure TGoogleMap.destroyMap();
begin
  if FMap <> nil then
  begin
    FMap := nil;
  end;
end;

procedure TGoogleMap.set_OnClick(AValue: TGMap_OnClickEvent);
begin
  if FMap <> nil then
  begin
    if hasValue(FClickListener) then
    begin
      asm
        if (this.FClickListener) {
          google.maps.event.removeListener(this.FClickListener);
        }
      end;
      FClickListener := nil;
    end;

    if hasValue(AValue) then
    begin
      asm
        this.FClickListener = this.FMap.addListener('click', AValue);
      end;
    end;
  end;
end;

constructor TGoogleMap.Create;
begin
  inherited Create;

  FMap := nil;
  FMarkersHashMap := nil;
  FRouteLayers := TJSArray.new;
  FClickListener := nil;
  FOpacity := 1;
  FMapType := gmRoadmap;
end;

destructor TGoogleMap.Destroy;
begin
  Self.onClick := nil;
  FMarkersHashMap := nil;
  FRouteLayers := nil;

  Self.destroyMap();

  inherited Destroy;
end;

function TGoogleMap.createMap(aDestinationDiv: String): Boolean;
begin
  Result := False;
  Self.destroyMap();

  if Length(aDestinationDiv) > 0 then
  begin
    asm
      if (typeof google !== "undefined" && typeof google.maps !== "undefined") {
        let mapElement = document.getElementById(aDestinationDiv);
        if (!mapElement) {
          mapElement = document.querySelector(aDestinationDiv);
        }
        
        if (mapElement) {
          let mapTypeId = 'roadmap';
          switch(this.FMapType) {
            case 0: mapTypeId = 'roadmap'; break;
            case 1: mapTypeId = 'satellite'; break;
            case 2: mapTypeId = 'hybrid'; break;
            case 3: mapTypeId = 'terrain'; break;
          }
          
          this.FMap = new google.maps.Map(mapElement, {
            center: { lat: 0, lng: 0 },
            zoom: 15,
            maxZoom: 20,
            mapTypeId: mapTypeId,
            mapTypeControl: true,
            streetViewControl: false,
            fullscreenControl: true
          });
          
          Result = true;
        }
      }
    end;
  end;
end;

procedure TGoogleMap.clearLineLayers;
var
  i: Integer;
  layer: TJSObject;
begin
  if (FMap = nil) or (FRouteLayers = nil) then
    Exit;

  for i := 0 to FRouteLayers.length - 1 do
  begin
    layer := TJSObject(FRouteLayers[i]);
    asm
      layer.setMap(null);
    end;
  end;

  FRouteLayers := TJSArray.new;
end;

procedure TGoogleMap.setMapRotation(aRadiantValue: Double);
var
  degrees: Double;
begin
  if FMap <> nil then
  begin
    degrees := aRadiantValue * 180 / 3.14159265359;
    asm
      this.FMap.setHeading(degrees);
    end;
  end;
end;

function TGoogleMap.addLineLayer(coords: TJSArray; lineOptions: TGMap_LineOptions): JSValue;
begin
  Result := nil;

  if (FMap <> nil) and (coords.length >= 2) then
  begin
    asm
      let path = [];
      for (let i = 0; i < coords.length; i++) {
        path.push({ lng: coords[i][0], lat: coords[i][1] });
      }

      let strokeStyle = {
        strokeColor: lineOptions.color,
        strokeWeight: lineOptions.width,
        strokeOpacity: this.FOpacity
      };

      if (lineOptions.lineDash && lineOptions.lineDash.length > 0) {
        strokeStyle.strokeOpacity = this.FOpacity;
        let icons = [{
          icon: {
            path: 'M 0,-1 0,1',
            strokeOpacity: 1,
            scale: lineOptions.width
          },
          offset: '0',
          repeat: lineOptions.lineDash[0] + 'px'
        }];
        strokeStyle.icons = icons;
        strokeStyle.strokeOpacity = 0;
      }

      let polyline = new google.maps.Polyline({
        path: path,
        geodesic: true,
        ...strokeStyle
      });

      polyline.setMap(this.FMap);
      this.FRouteLayers.push(polyline);
      Result = polyline;
    end;
  end;
end;

function TGoogleMap.updateMarker(options: TGMap_MarkerOptions): Boolean;
var
  _MapMarker: TJSObject = nil;
begin
  Result := False;

  if FMap <> nil then
  begin
    if FMarkersHashMap = nil then
      FMarkersHashMap := TJSMap.new
    else
      _MapMarker := TJSObject(FMarkersHashMap.get(options.Code));

    if not hasValue(_MapMarker) then
    begin
      asm
        _MapMarker = new google.maps.Marker({
          position: { lat: options.Lat, lng: options.Lon },
          map: this.FMap
        });
      end;

      FMarkersHashMap.&set(options.Code, _MapMarker);
    end
    else
    begin
      asm
        _MapMarker.setPosition({ lat: options.Lat, lng: options.Lon });
      end;
    end;

    if Length(options.imgURL) > 0 then
    begin
      asm
        let icon = {
          url: options.imgURL,
          scaledSize: new google.maps.Size(
            32 * options.scale,
            32 * options.scale
          ),
          anchor: new google.maps.Point(
            32 * options.scale * options.anchorX,
            32 * options.scale * options.anchorY
          )
        };
        _MapMarker.setIcon(icon);
      end;
    end;

    if options.centerMap then
    begin
      asm
        this.FMap.setCenter({ lat: options.Lat, lng: options.Lon });
      end;
    end;

    Result := True;
  end;
end;

procedure TGoogleMap.resize();
begin
  if FMap <> nil then
  begin
    asm
      google.maps.event.trigger(this.FMap, 'resize');
    end;
  end;
end;

function TGoogleMap.viewExtent(): TJSArray;
begin
  Result := nil;

  if FMap <> nil then
  begin
    asm
      let bounds = this.FMap.getBounds();
      if (bounds) {
        let ne = bounds.getNorthEast();
        let sw = bounds.getSouthWest();
        Result = [sw.lng(), sw.lat(), ne.lng(), ne.lat()];
      }
    end;
  end;
end;

end.
