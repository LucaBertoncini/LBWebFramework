# pas2js SPA Framework Documentation

## Introduction

This is a lightweight, component-based framework for building modern Single-Page Applications (SPAs) using pas2js. It provides a solid architectural foundation for creating interactive and data-driven web applications while writing the logic entirely in Pascal.

The framework is designed to be minimal, extensible, and unopinionated, giving the developer full control over the final application.

## Core Concepts

The framework is built on a few key architectural ideas:

1.  **Application Shell (`TWebApplication`):** The entire application is managed by a main "shell" class. Your specific app will inherit from `TWebApplication` and override virtual methods to configure itself. This provides a structured, high-level entry point and handles the boilerplate of setting up the main layout components.

2.  **Component-Based Architecture (`TWebComponent`, `TBaseForm`):** Every piece of the UI, from a simple header to a complex page, is a "Component". A component is a Pascal class that manages a piece of the DOM. This pattern encourages encapsulation and reusability.

3.  **Decoupled Views & Logic:** The HTML templates (the "View") are purely declarative and use `id`s to expose elements. The Pascal components (the "ViewModel") contain all the logic, find elements by `id`, and bind events programmatically. This provides a clean separation of concerns.

4.  **Decoupled Communication (`TEventsManager`):** Components do not talk to each other directly. They communicate through a global Event Bus. A component can `Trigger` a named event (e.g., `'column-toggled'`), and other components can `Subscribe` to that event to react, without either component knowing about the other's existence.

5.  **Adaptive and Content-Aware Layouts:** The framework is designed to be both responsive (via CSS) and adaptive.
    *   The `TPageManager` can load different HTML templates based on screen size.
    *   Layout components like `TSideColumnComponent` are intelligent, hiding themselves on mobile by default and only appearing if they are explicitly loaded with content.

## File Structure

The project is organized into the following main directories:

```
Pas2JS_framework/
├── Common/
│   ├── WebApplication.pas
│   └── ...                 # Core, reusable framework units
│
└── DemoApp/
    ├── public/
    │   ├── ...
    │   └── index.html
    └── src/
        ├── forms/
        │   └── Form.Home.pas
        └── DemoApp.lpr
```

-   **`Common/`**: Contains the core, reusable units of the framework. You generally won't need to modify these files.
-   **`DemoApp/`**: Contains the example application that uses the framework. This is where you will build your app.
    -   `public/`: All static assets (HTML, CSS, images).
    -   `src/`: The Pascal source code for your application.

## How to Build Your Application

Building an application with the framework is straightforward. You create your own application class that inherits from `TWebApplication` and tell it what to do.

### Step 1: Create your Application Class

In `DemoApp/src/DemoApplication.pas`, define your main application class. It must inherit from `TWebApplication`. Here you will override methods to set up your specific application.

```pascal
// src/DemoApplication.pas
unit DemoApplication;

interface
uses
  WebApplication in '../../Common/WebApplication.pas',
  // ... include your page units ...
  Form.Home in 'forms/Form.Home.pas';

type
  TDemoApplication = class(TWebApplication)
  protected
    // Override these methods to configure your app
    procedure RegisterRoutes(aPageManager: TPageManager); override;
    procedure InitializeHeader; override;
  end;
// ...
```

### Step 2: Implement Configuration Methods

In the implementation section, provide the logic for the methods you overrode.

**`RegisterRoutes` (Required):** This is where you map URL hashes to your page components.

```pascal
procedure TDemoApplication.RegisterRoutes(aPageManager: TPageManager);
begin
  aPageManager.RegisterForm('home', TFormHome);
  aPageManager.RegisterForm('login', TFormLogin);
  aPageManager.RegisterForm('main', TFormMainDashboard);
end;
```

**`Initialize...` Methods (Optional):** Use these to load content into the main layout components and decide if they should be visible.

```pascal
procedure TDemoApplication.InitializeHeader;
begin
  // Load content into the main header
  FHeader.LoadContent('pages/header.html');
end;

procedure TDemoApplication.InitializeLeftColumn;
begin
  // Load content and, only on success, show the column.
  FLeftColumn.LoadContent('pages/left-menu.html').then(
    procedure(v: JSValue)
    begin
      FLeftColumn.Show;
    end
  );
end;
```

### Step 3: Set the Entry Point

Your main project file (`DemoApp.lpr`) simply creates an instance of your application class and calls `Run`.

```pascal
// src/DemoApp.lpr
program DemoApp;

uses
  DemoApplication in 'DemoApplication.pas';

var
  App: TDemoApplication;

begin
  App := TDemoApplication.Create;
  App.Run;
end.
```

## Framework Components

### `BaseForm.pas` & `WebComponent.pas`
These units define the base classes for all UI components, providing a common lifecycle (`BindUI`, `UnbindUI`). Your pages will typically inherit from `TBaseForm`.

### `PageManager.pas`
The heart of the framework. It handles routing, adaptive layout loading based on screen size, and component lifecycle.

### `Dialogs.pas`
A simple utility for showing styled, modal dialog boxes.

### `TemplateEngine.pas`
A lightweight templating engine that supports nested data paths (`{{object.field}}`) and list iteration (`{{#each array}}...{{/each}}`).

### `InfiniteScroller.pas`
A generic component for efficiently displaying long lists of items with variable heights using the "infinite scrolling" pattern.

### `LayoutComponents.pas`
Contains the classes (`THeaderComponent`, `TSideColumnComponent`) that manage the main sections of the `index.html` layout.

### `EventsManager.pas`
A global event bus that allows components to communicate with each other without being directly linked, enabling a more modular architecture.

### `WebApplication.pas`
The main application shell. Your application inherits from this class, providing a structured entry point and abstracting away the boilerplate setup code.

### `Geolocation.pas`
A wrapper for the browser's Geolocation API. It provides simple, type-safe procedures to get the device's current position or watch for location changes.

### `DeviceSensors.pas`
Contains wrappers for the Device Sensor APIs. Currently includes a `TAccelerometer` class to get readings from the device's accelerometer.

### `BarcodeScanner.pas`
A component that wraps the `zxing-js` library to provide barcode and QR code scanning capabilities using the device's camera. It abstracts away camera access and the decoding process.
