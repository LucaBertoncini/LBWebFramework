# LBWebFramework — Responsive Form Selection

How to serve a **different form (and a different HTML template) per screen
size**, instead of stretching one layout with CSS media queries.
Everything here is verified against the real framework source
(`PageManager.pas`, `WebComponent.pas`, `LayoutComponents.pas`), not
inferred.

> Lifecycle & memory rules (what the framework frees automatically vs. what
> is your responsibility) used to live at the bottom of this file. They now
> live where they are actually looked for: see `GOLDEN_RULES.md`, "Memory
> and object lifecycle" section. This file is only about responsive layout.

## The mental model: one layout per device class, not one layout that bends

If you know Android's resource qualifiers (`res/layout/` vs.
`res/layout-sw600dp/`, where the system picks the layout folder that fits
the current device), this is the same idea: you author a layout *built for*
a device class, and the framework picks the right one — rather than writing
one markup and hoping CSS reflows it acceptably everywhere. "Responsive"
here means **selection among purpose-built variants**, not adaptation of a
single one.

## The API (verified in PageManager.pas)

```pascal
procedure TPageManager.RegisterForm(aRoute: string; aFormClass: TBaseFormClass;
                                    aMinWidth: NativeInt = 0; aMinHeight: NativeInt = 0;
                                    const aHtmlFile: String = '';
                                    const aBasePath: String = '');
```

`aHtmlFile` (template file, relative to `aBasePath`) and `aBasePath` (the application's root folder) are
optional and last: older calls compile unchanged.

Register the SAME route twice (or more):

```pascal
// Default (fallback for any/small screen): thresholds 0,0
FPageManager.RegisterForm('models', TFormModelsMobile);
// Wide-screen variant: chosen only when window is at least 768px wide
FPageManager.RegisterForm('models', TFormModelsDesktop, 768, 0);
```

## How the choice is made (`GetBestRegistration`, verified)

At navigation time, among all forms registered on the requested route:
- forms whose `MinWidth`/`MinHeight` the current `window.innerWidth`/
  `innerHeight` satisfy are candidates;
- the candidate with the **highest** `MinWidth` wins;
- if no threshold-bearing form fits, the one registered with `0,0` (the
  default) is used.

So order of registration does not matter; the thresholds decide. (Same as
Android picking the most specific qualifier that matches, falling back to
the unqualified `layout/`.)

## THE NON-OBVIOUS RULE: every variant needs its own template

`TPageManager.LoadPage` picks the template in this order:

1. `_FormClass.getTemplatePath`, if it returns something other than `''` (a **complete** path — the base
   folder is not prepended);
2. the `aHtmlFile` given to `RegisterForm`, relative to `aBasePath`;
3. the convention `aBasePath + 'pages/' + <route> + '.html'`.

`TBaseForm.getTemplatePath` returns `''` by default. Therefore **two forms on the same route, registered with
neither `aHtmlFile` nor a `getTemplatePath` override, both load the same `pages/<route>.html`.** The variant
that needs different markup must declare its own template, in either of two equivalent ways:

```pascal
// A) at registration (no override needed) — usually the simplest
FPageManager.RegisterForm('models', TFormModelsMobile, 0, 0, 'pages/models-mobile.html');

// B) in the class
class function TFormModelsMobile.getTemplatePath(): String;
begin
  Result := 'pages/models-mobile.html';   // complete path
end;
```

With way B in an application that uses `aBasePath`, the override must include the folder itself
(it is not prepended); with way A the folder is added for you.

Without either, you get the responsive *logic* switch but both variants load identical HTML — a silent
mistake: it "works" (no error) but the mobile form renders the desktop markup, then fails to find the
elements its own layout expects. Always give at least one variant its own template. The other variant can
keep the default (it "owns" the natural `pages/<route>.html` name).

## Align the threshold with the framework's own breakpoint

`LayoutComponents.pas` uses `MOBILE_BREAKPOINT = 768` (side columns
auto-hide below it). Use the same 768 value for the desktop variant's
`MinWidth`, so the page layout and the side columns switch at the same
width instead of two different breakpoints fighting each other.

═══════════════════════════════════════════════════════════════════════
 WORKED EXAMPLE — a two-column page with a mobile master-detail variant
═══════════════════════════════════════════════════════════════════════

The recommended pattern for a two-column page:
- **Desktop variant**: list and detail side by side, both always visible.
- **Mobile variant** (the `0,0` default): one view at a time. Show the list
  full-width; on tap, hide the list and show the detail full-width with a
  "← back to list" button. **Reuse the same detail-panel helper class** in
  both variants — only the surrounding layout/logic differs.

### 1. Registration (in the TWebApplication descendant's RegisterRoutes)

```pascal
const
  cDesktopMinWidth = 768;  // == MOBILE_BREAKPOINT
begin
  // Mobile is the default (0,0) and has its own template; desktop takes over at >= 768px
  // and keeps the natural pages/models.html.
  FPageManager.RegisterForm('models', TFormModelsMobile, 0, 0, 'pages/models-mobile.html');
  FPageManager.RegisterForm('models', TFormModelsDesktop, cDesktopMinWidth, 0);
```

### 2. Desktop variant — keeps the default template (pages/models.html)

```pascal
type
  TFormModelsDesktop = class(TBaseForm)
  strict private
    FDetail  : TModelDetailPanel;   // the shared helper, reused as-is
    FListDiv : TJSHTMLDivElement;
  strict protected
    procedure BindUI; override;     // wires list + detail, both visible
  public
    destructor Destroy; override;   // frees FDetail (a helper you own)
  end;
  // No getTemplatePath override: falls back to pages/models.html.
```

### 3. Mobile variant — its own template (declared at registration above), one view at a time

```pascal
type
  TFormModelsMobile = class(TBaseForm)
  strict private
    FDetail     : TModelDetailPanel;   // SAME helper class, reused
    FListView   : TJSHTMLElement;       // the "list" view container
    FDetailView : TJSHTMLElement;       // the "detail" view container
    procedure showListView();
    procedure showDetailView();
    function  HandleItemClick(aEvent: TJSMouseEvent): Boolean;
    function  HandleBackClick(aSender: TUIElementWrapper; aEvent: TJSMouseEvent): Boolean;
  strict protected
    procedure BindUI; override;
  public
    destructor Destroy; override;
    // The template is declared at registration (aHtmlFile). Alternative: override
    // class function getTemplatePath(): String; returning 'pages/models-mobile.html'.
  end;

implementation

procedure TFormModelsMobile.showListView();
begin
  if FDetailView <> nil then FDetailView.classList.add('hidden');
  if FListView   <> nil then FListView.classList.remove('hidden');
end;

procedure TFormModelsMobile.showDetailView();
begin
  if FListView   <> nil then FListView.classList.add('hidden');
  if FDetailView <> nil then FDetailView.classList.remove('hidden');
end;

function TFormModelsMobile.HandleItemClick(aEvent: TJSMouseEvent): Boolean;
begin
  Result := True;
  // ... read the tapped id from the row, then:
  FDetail.setModel(theTappedId);
  Self.showDetailView();
end;

function TFormModelsMobile.HandleBackClick(aSender: TUIElementWrapper; aEvent: TJSMouseEvent): Boolean;
begin
  Result := True;
  Self.showListView();
end;
```

### 4. The two templates

`pages/models.html` (desktop, two columns side by side):
```html
<div class="models-page">
  <div id="models-list" class="models-sidebar"></div>
  <div id="models-detail" class="models-detail"></div>
</div>
```

`pages/models-mobile.html` (one view at a time; the mobile form shows/hides
these two blocks):
```html
<div class="models-mobile-page">
  <div id="list-view" class="models-mobile-view">
    <div id="models-list" class="models-list"></div>
  </div>
  <div id="detail-view" class="models-mobile-view hidden">
    <button id="back-btn" type="button">&#8592; Back to list</button>
    <div id="models-detail"></div>
  </div>
</div>
```

## One nuance to always state when building this pattern

Switching between the list view and the detail view on mobile is a plain
show/hide of a `hidden` CSS class **inside the form**, NOT a
`PageManager.NavigateTo`. It therefore does not touch browser history or
the route (which stays `models`). Consequence: the browser Back button
returns to the previous app page, not from detail-view to list-view. If
"Back closes the detail" is desired, it must be implemented explicitly via
history — call this out to the user rather than assuming it.
