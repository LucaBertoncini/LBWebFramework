unit DeviceSensors;

interface

uses
  JS, Web, SysUtils, Classes;

type
  // A record to hold the accelerometer data.
  TAccelerometerData = record
    x: Double;
    y: Double;
    z: Double;
  end;
  
  // The event handler for accelerometer readings.
  TAccelerometerReadingEvent = procedure(const aData: TAccelerometerData) of object;

  // A wrapper class for the browser's Accelerometer API.
  TAccelerometer = class(TObject)
  private
    FJSAccelerometer: TJSObject;
    FOnReading: TAccelerometerReadingEvent;
    FOnError: TJSGeoLocationErrorEvent; // Re-using from Web.pas
    // FReadingHandler: TJSProcedure;
    // FErrorHandler: TJSProcedure;
    procedure HandleReading;
    procedure HandleError(aError: TJSError);
  public
    constructor Create(aFrequency: Integer = 60);
    destructor Destroy; override;
    // Starts listening for sensor readings.
    procedure Start;
    // Stops listening for sensor readings.
    procedure Stop;
    // Event triggered on each new reading.
    property OnReading: TAccelerometerReadingEvent write FOnReading;
    // Event triggered on error.
    property OnError: TJSGeoLocationErrorEvent write FOnError;
  end;

implementation

{ TAccelerometer }

constructor TAccelerometer.Create(aFrequency: Integer);
var
  options: TJSObject;
begin
  inherited Create;
  // The Sensor APIs require user permission and a secure context (HTTPS).
  // We create an options object to specify the desired frequency.
  options := TJSObject.new;
  options['frequency'] := aFrequency;
  
  // Create the underlying JS Accelerometer object.
  asm
    try {
      this.FJSAccelerometer = new Accelerometer(options);
    } catch (e) {
      this.FJSAccelerometer = null;
      if (this.FOnError) { this.FOnError(e); }
    }
  end;
end;

destructor TAccelerometer.Destroy;
begin
  Stop;
  inherited Destroy;
end;

procedure TAccelerometer.Start;
begin
  if FJSAccelerometer = nil then Exit;

  // Bind the handlers so 'Self' is available inside them.
  // FReadingHandler := Self.HandleReading;
//  FErrorHandler := procedure (e: TJSError) Self.HandleError(e);

(*
  // Add the event listeners.
  FJSAccelerometer.addEventListener('reading', @Self.HandleReading);
  FJSAccelerometer.addEventListener('error', @Self.HandleError);
  
  // Start the sensor.
  FJSAccelerometer.AsObject.Get('start').apply(FJSAccelerometer, []);

*)
end;

procedure TAccelerometer.Stop;
begin
  if FJSAccelerometer = nil then Exit;

(*
  // Stop the sensor.
  FJSAccelerometer.AsObject.Get('stop').apply(FJSAccelerometer, []);
  
  // Remove the event listeners.
  if Assigned(FReadingHandler) then
    FJSAccelerometer.removeEventListener('reading', FReadingHandler);
  if Assigned(FErrorHandler) then
    FJSAccelerometer.removeEventListener('error', FErrorHandler);
*)
end;

procedure TAccelerometer.HandleReading;
var
  data: TAccelerometerData;
begin
  // This is called by the 'reading' event.
  // We populate our Pascal record with the data from the JS object.
  data.x := Double(FJSAccelerometer.Properties['x']);
  data.y := Double(FJSAccelerometer.Properties['y']);
  data.z := Double(FJSAccelerometer.Properties['z']);
  
  // Trigger the Pascal event.
  if Assigned(FOnReading) then
    FOnReading(data);
end;

procedure TAccelerometer.HandleError(aError: TJSError);
begin
  // This is called by the 'error' event.
//  if Assigned(FOnError) then
//    FOnError(aError);
end;

end.
