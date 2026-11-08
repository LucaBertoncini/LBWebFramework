# LBWebFramework — pas2js SPA Framework

A lightweight, component-based framework for building Single-Page Applications with pas2js, writing the application
logic entirely in Pascal. It gives a solid architectural base (application shell, routing, components, event bus,
ready-made UI helpers) and stays minimal and unopinionated: the HTML and CSS are yours.

This file is the entry point. Detailed documentation is in `docs/`:

| File | Content |
| --- | --- |
| `docs/GETTING_STARTED.md` | A first "Hello" page step by step. |
| `docs/FRAMEWORK_REFERENCE.md` | Reference of every unit: signatures, behaviour, conventions. |
| `docs/Pas2JS_SPA_Framework_Docs*.docx / .pdf` | Full manual (Italian and English) with a complete example application. |
| `docs/CHANGELOG.md` | What changed between versions of the framework. |
| `LBWebFramework-AI-SDK/` | Rules and examples for AI assistants working with the framework. |

## Core concepts

1. **Application shell (`TWebApplication`).** The whole application is managed by one shell class. Your application
   inherits from it, registers its routes and, optionally, fills the layout areas (header, footer, side columns).
   The shell is a singleton, reachable through `gv_WebApplication`.

2. **Components (`TWebComponent`, `TBaseForm`).** Every piece of the UI, from a header to a full page, is a
   component: a Pascal class that manages a part of the DOM. A page is a `TBaseForm` bound to a route.

3. **View and logic are separate.** The HTML (the view) is declarative and exposes elements through `id`. The Pascal
   class finds the elements with `getElementById` and binds events in `BindUI`. The Pascal code does not generate
   complex markup.

4. **Decoupled communication (`TjsEventsManager`).** Components do not call each other directly: they talk through
   the global event bus `gv_EventsManager`. One component raises a named event (`RaiseEvent`), the others listen
   to it (`AddListener`) without knowing who raised it.

5. **Data shared between pages.** Pages are destroyed on every navigation. Data that must be available from one page
   to the next lives in the application object: add fields and properties to your `TWebApplication` descendant and
   read them from any form, e.g. `TMyApp(gv_WebApplication).SelectedItem`.

6. **Adaptive layouts.** The framework is responsive through CSS and adaptive through `TPageManager`, which can
   register several forms (or HTML files) for the same route, one per screen size. Side columns
   (`TSideColumnComponent`) hide themselves on small screens.

## Folder structure

```
Common/                          Reusable framework units: do not modify them for a single project
  WebApplication/
    WebApplication.pas           Application shell
    PageManager.pas              Routing and page lifecycle
    WebComponent.pas             TUIElementWrapper, TWebComponent, TBaseForm
    LayoutComponents.pas         Header, footer, side columns
    Dialogs.pas                  Modal dialogs
    css/, html/index.html        Base styles and the application shell page
  EventsManager.pas              Event bus
  InfiniteScroller.pas           Progressive loading of long lists
  TemplateEngine/                Template engine and template loader
  LBTreeView/                    Tree view component
  uJSTabulator.pas               Wrapper of the Tabulator library
  uLBWebUtils.pas                HTTP POST requests, resource loading, text helpers
  WSManager.pas                  WebSocket manager
  indexeddbhelper.pas            IndexedDB helper
  leastrecentlyusedcache.pas     LRU cache
docs/                            Documentation
LBWebFramework-AI-SDK/           Instructions for AI assistants
```

A project using the framework keeps its own files outside `Common/`:

```
html/
  index.html                     Copy of Common/WebApplication/html/index.html
  css/                           Copy of Common/WebApplication/css/
  pages/                         One HTML fragment per route (hello.html, ...)
src/
  MyApp.pas                      Application class
  Form.Hello.pas                 One unit per page
  MyProject.lpr                  Main program
```

## Building an application

### Step 1: the application class

The application class inherits from `TWebApplication`. `RegisterRoutes` is mandatory; the `Initialize...` methods
are optional.

```pascal
unit MyApp;

interface

uses
  JS, WebApplication, PageManager, LayoutComponents;

type
  TMyApp = class(TWebApplication)
  strict private
    FSelectedItem : TJSObject;  // data shared between pages
  protected
    procedure RegisterRoutes(); override;
    procedure InitializeHeader; override; async;
    procedure InitializeLeftColumn; override; async;
  public
    property SelectedItem : TJSObject read FSelectedItem write FSelectedItem;
  end;

implementation

uses
  Form.Home, Form.Login;

procedure TMyApp.RegisterRoutes();
begin
  FPageManager.RegisterForm('home', TFormHome);
  FPageManager.RegisterForm('login', TFormLogin);
end;

procedure TMyApp.InitializeHeader;
begin
  AWait(FHeader.LoadContent('partials/header.html'));
end;

procedure TMyApp.InitializeLeftColumn;
begin
  // The column is shown only if its content was loaded successfully
  if AWait(Boolean, FLeftColumn.LoadContent('partials/left-menu.html')) then
    FLeftColumn.Show;
end;

end.
```

`async` appears only in the declaration of the interface, never in the implementation.

### Step 2: the pages

A page is an HTML fragment plus a class derived from `TBaseForm`:

```pascal
unit Form.Home;

interface

uses
  Web, JS, WebComponent;

type
  TFormHome = class(TBaseForm)
  strict private
    FTitle  : TUIElementWrapper;
    FButton : TUIElementWrapper;
    function OnButtonClick(aSender: TUIElementWrapper; aEvent: TJSMouseEvent): Boolean;
  public
    procedure BindUI; override;
  end;

implementation

procedure TFormHome.BindUI;
begin
  FTitle  := Self.getElementById('title');
  FButton := Self.getElementById('my-button');
  FButton.onclick := @Self.OnButtonClick;
end;

function TFormHome.OnButtonClick(aSender: TUIElementWrapper; aEvent: TJSMouseEvent): Boolean;
begin
  Result := True;
  FTitle.textContent := 'Clicked!';
end;

end.
```

The wrappers returned by `getElementById` and their event handlers are released by the framework when the page is
destroyed.

### Step 3: the entry point

The main program creates the application and runs it. The four parameters are the layout component classes; `nil`
means "use the base class".

```pascal
program MyProject;

uses
  MyApp;

var
  gv_App : TMyApp;

begin
  gv_App := TMyApp.Create(nil, nil, nil, nil);
  gv_App.Run;
end.
```

### Moving between pages

```pascal
// In the source page: store the data in the application object, then navigate
TMyApp(gv_WebApplication).SelectedItem := _item;
gv_WebApplication.PageManager.NavigateTo('detail');

// In the destination page (BindUI)
_item := TMyApp(gv_WebApplication).SelectedItem;
```

### Communicating through the event bus

```pascal
// Declare the event once, then listen to it
gv_EventsManager.AddEvent('column-toggled');
gv_EventsManager.AddListener('column-toggled', Self,
  procedure(Sender: JSValue)
  begin
    // react to the event
  end);

// Raise it from anywhere
gv_EventsManager.RaiseEvent('column-toggled', Self);

// Remove every listener registered by an object (typically in its destructor)
gv_EventsManager.RemoveListenersFor(Self);
```

## Framework units

| Unit | Purpose |
| --- | --- |
| `WebComponent.pas` | Base classes: `TUIElementWrapper` (typed access to a DOM element), `TWebComponent` (lifecycle, `BindUI`, `LoadContent`), `TBaseForm` (a page bound to a route). |
| `PageManager.pas` | Routing on the URL hash, one navigation at a time, forms registered per screen size, browser back/forward support. |
| `WebApplication.pas` | The application shell and the `gv_WebApplication` singleton; wake lock management. |
| `LayoutComponents.pas` | `THeaderComponent`, `TFooterComponent`, `TSideColumnComponent`: the fixed areas of `index.html`. |
| `EventsManager.pas` | Global event bus (`AddEvent`, `AddListener`, `RaiseEvent`, `RemoveListenersFor`). |
| `Dialogs.pas` | Non-blocking modal dialogs: `ShowMessage(aTitle, aMessage, aMsgType)`. |
| `TemplateEngine.pas`, `uLBTemplateLoader.pas` | Templates with `{{field}}`, `{{#each}}`, `{{#if}}`, `{{#unless}}` and partials; loading of templates from files. |
| `InfiniteScroller.pas` | Efficient display of long lists, rendered in chunks as the user scrolls. |
| `uLBTreeView.pas` | Tree view with context menus. |
| `uJSTabulator.pas` | Wrapper of the Tabulator library (the library itself must be loaded by the project). |
| `uLBWebUtils.pas` | Asynchronous HTTP POST requests, loading of CSS/JS resources, HTML encoding helpers. |
| `WSManager.pas` | WebSocket connection that turns incoming messages into events on the event bus. |
| `indexeddbhelper.pas` | Promise-based access to IndexedDB. |
| `leastrecentlyusedcache.pas` | Fixed-capacity cache with least-recently-used eviction. |

## Writing conventions

- Fields `F...`, parameters `a...`/`an...`, local variables `_...` (one-character names such as loop indexes are the
  only exception).
- Calls to a method of the class itself are prefixed with `Self.`.
- Variable names state their purpose and are as specific as possible.
- A blank line separates one routine from the next.
- Repeated code goes into a shared project unit; code of general validity is proposed for the base framework.
- `async` appears only in the interface declaration. `AWait` is used only inside `async` routines.
- A callback declared `of object` accepts only a real method (`@Self.Method`); a `reference to` callback also
  accepts anonymous procedures.

The code in this file has not been compiled; if the compiler disagrees, the compiler is right.
