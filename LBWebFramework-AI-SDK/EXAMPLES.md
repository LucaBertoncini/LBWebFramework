# Verified Usage Examples — LBWebFramework

Verified snippets for the most commonly requested subsystems. If a task
goes beyond what's shown here, say so explicitly rather than extending by
analogy — see `SYSTEM_PROMPT.md` rule 1.

---

## Example 0 — The application shell: what `index.html` actually does

**Read this before any other example, and reuse this explanation whenever
presenting a page example.** Every page (a `TBaseForm` registered with
`PageManager`) is only half the picture: it's loaded *into* a fixed HTML
shell that never changes.

```html
<div id="app-container">
  <div id="app-header"></div>
  <div id="left-column"></div>
  <div id="center-container"></div>
  <div id="right-column"></div>
  <div id="app-footer"></div>
</div>
```

| Region (`id`) | What lives there | Changes on navigation? |
|---|---|---|
| `app-header` | Header component | No — loaded once at startup |
| `left-column`/`right-column` | Optional side panels | No, by default |
| `center-container` | **The currently active page** | **Yes — the only region PageManager touches** |
| `app-footer` | Footer component | No |

`PageManager.NavigateTo('hello')` does exactly this: updates the URL hash,
pushes history, fetches `pages/hello.html` and replaces the entire contents
of `#center-container` with it (nothing outside is touched), then
instantiates the registered `TBaseForm` (e.g. `TFormHello`), which finds
its own elements and wires logic in `BindUI`.

**Why this matters**: presenting a page template without this context lets
a newcomer wrongly conclude the template *is* the whole page,
header/footer included. Always connect the two.

---

## Example 1 — A minimal page component

```pascal
unit Form.Hello;

interface

uses
  Web, JS, WebComponent;

type
  TFormHello = class(TBaseForm)
  strict private
    FTitle  : TUIElementWrapper;
    FButton : TUIElementWrapper;
    function OnButtonClick(aSender: TUIElementWrapper; aEvent: TJSMouseEvent): Boolean;
  strict protected
    procedure BindUI; override;
  end;

implementation

procedure TFormHello.BindUI;
begin
  FTitle := Self.getElementById('title');
  FButton := Self.getElementById('my-button');
  FButton.onclick := @Self.OnButtonClick;
end;

function TFormHello.OnButtonClick(aSender: TUIElementWrapper; aEvent: TJSMouseEvent): Boolean;
begin
  Result := True;
  FTitle.textContent := 'Clicked!';
end;

end.
```

Template `pages/hello.html` — **remember (Example 0): this fragment is not
the whole page**, only what gets injected into `#center-container`:

```html
<h2 id="title">Hello</h2>
<button id="my-button">Click me</button>
```

Registered: `FPageManager.RegisterForm('hello', TFormHello);`

---

## Example 2 — Communicating via the event bus

```pascal
// Component A: publishes
gv_EventsManager.RaiseEvent('user:updated', anUserJSONObject);

// Component B: subscribes, typically inside BindUI
procedure TFormProfile.BindUI;
begin
  gv_EventsManager.AddListener('user:updated', Self,
    procedure(Sender: JSValue)
    begin
      Self.RefreshDisplayedUser(TJSObject(Sender));
    end
  );
end;

destructor TFormProfile.Destroy;
begin
  // MANDATORY: otherwise the bus keeps a reference to a destroyed object
  gv_EventsManager.RemoveListenersFor(Self);
  inherited Destroy;
end;
```

`RaiseEvent` is synchronous — a slow handler delays the raiser. Exceptions
inside a handler are silently swallowed by design.

---

## Example 3 — A hierarchical tree with a context menu

`uLBTreeView` expects **nested** data. Convert flat backend data
client-side first.

```pascal
FTree := TLBjsTreeView.Create(ContainerDiv, True, True, False);
FTree.setData(NestedTreeData, 'id', 'name', 'children');
FTree.renderData();

FTree.setContextMenuCallback(
  function(anItem: TJSObject): TJSArray
  var
    _Entries : TJSArray;
  begin
    _Entries := TJSArray.new;
    if anItem = nil then
      _Entries.push(TLBTreeViewMenuItem.Create('New root item', @Self.CreateNewRoot))
    else begin
      _Entries.push(TLBTreeViewMenuItem.Create('Open details', @Self.OpenDetails));
      _Entries.push(TLBTreeViewMenuItem.Create('Delete', @Self.DeleteNode));
    end;
    Result := _Entries;
  end
);
```

No "node selected" click event exists (`stopImmediatePropagation` on
checkbox clicks) — use the context menu instead.

---

## Example 4 — Calling a backend endpoint

The framework's base request class (`TJSAsyncPOSTRequest`, in
`uLBWebUtils`) is built for a **single fixed endpoint**, with the specific
operation encoded inside the JSON body — a pattern sometimes called
RPC-over-HTTP. It always resolves, never rejects, so the caller checks
`.ok` rather than wrapping the call in `try/except`.

```pascal
type
  TMyRequest = class(TJSAsyncPOSTRequest)
  strict private
    procedure set_UserId(AValue: Integer);
  public
    constructor Create; override;
    property UserId: Integer write set_UserId;
  end;

constructor TMyRequest.Create;
begin
  inherited Create;
  FData := TJSObject.new;
  FData['request_type'] := 'get_user_profile'; // the operation, encoded in the body
end;

procedure TMyRequest.set_UserId(AValue: Integer);
begin
  FData['user_id'] := AValue;
end;

// Usage:
_Req := TMyRequest.Create;
_Req.UserId := 42;
_Ans := AWait(TJSPOSTRequestAnswer, _Req.execute());
if _Ans.ok then
  _Profile := TJSObject(_Ans.Answer)
else if _Ans.HttpStatus = 401 then
  gv_WebApplication.PageManager.NavigateTo('login')          // session expired
else if _Ans.HttpError and hasValue(_Ans.ErrorAnswer) then
  ShowMessage('Error', String(TJSObject(_Ans.ErrorAnswer)['error']), mtError)   // the server's own message (field name is the project's)
else
  ShowMessage('Error', 'Could not load the profile.', mtError);
```

`HttpStatus` is the HTTP code (0 = the request never reached the server, i.e. offline); `ErrorAnswer` holds the
JSON body of an error answer, if any. `Answer` is filled only for 2xx answers.

### If your project's backend is path-based REST instead

Some projects built on this framework expose REST APIs with distinct
resources at distinct paths (`GET /api/users/42`, `PUT /api/users/42`,
etc.) rather than a single RPC endpoint. In that case, `TJSAsyncPOSTRequest`
as shown above is **not** the right base class as-is — check whether the
project already has its own REST client wrapper (built to support multiple
HTTP verbs and arbitrary paths) before reusing this pattern. See
`GOLDEN_RULES.md`, backend communication section.

---

## Example 5 — A login form calling a backend session endpoint

The matching backend session endpoint is documented in the backend SDK, which is not part of this package.

```pascal
unit Form.Login;

interface

uses
  Web, JS, WebComponent, uLBWebUtils;

type
  TLoginRequest = class(TJSAsyncPOSTRequest)
  strict private
    procedure set_Username(AValue: String);
    procedure set_Password(AValue: String);
  public
    constructor Create; override;
    property Username: String write set_Username;
    property Password: String write set_Password;
  end;

  TFormLogin = class(TBaseForm)
  strict private
    FUsernameInput, FPasswordInput, FLoginButton, FErrorLabel : TUIElementWrapper;
    procedure DoLoginAsync(const aUsername, aPassword: String); async;
    function OnLoginClick(aSender: TUIElementWrapper; aEvent: TJSMouseEvent): Boolean;
  strict protected
    procedure BindUI; override;
  end;

implementation

constructor TLoginRequest.Create;
begin
  inherited Create;
  FData := TJSObject.new;
  FData['request_type'] := 'login';
end;

procedure TLoginRequest.set_Username(AValue: String);
begin
  FData['username'] := AValue;
end;

procedure TLoginRequest.set_Password(AValue: String);
begin
  FData['password'] := AValue;
end;

procedure TFormLogin.BindUI;
begin
  FUsernameInput := Self.getElementById('username');
  FPasswordInput := Self.getElementById('password');
  FLoginButton := Self.getElementById('login-button');
  FErrorLabel := Self.getElementById('login-error');
  FLoginButton.onclick := @Self.OnLoginClick;
end;

function TFormLogin.OnLoginClick(aSender: TUIElementWrapper; aEvent: TJSMouseEvent): Boolean;
begin
  Result := True;
  FErrorLabel.textContent := '';
  Self.DoLoginAsync(FUsernameInput.value, FPasswordInput.value);
end;

procedure TFormLogin.DoLoginAsync(const aUsername, aPassword: String);
var
  _Req : TLoginRequest;
  _Ans : TJSPOSTRequestAnswer;
begin
  _Req := TLoginRequest.Create;
  _Req.Username := aUsername;
  _Req.Password := aPassword;
  _Ans := AWait(TJSPOSTRequestAnswer, _Req.execute());
  if _Ans.ok then
    gv_WebApplication.PageManager.NavigateTo('home')
  else if _Ans.HttpStatus = 401 then
    FErrorLabel.textContent := 'Login failed. Check your credentials.'
  else
    FErrorLabel.textContent := 'Service not available. Try again later.';
end;

end.
```

Template `pages/login.html` — only the fragment injected into
`#center-container` (see Example 0):

```html
<input type="text" id="username" placeholder="Username">
<input type="password" id="password" placeholder="Password">
<button id="login-button">Log in</button>
<div id="login-error"></div>
```

**Not verified, don't assume**: if frontend/backend are on different
origins during development, cookie-based sessions may need `withCredentials`
explicitly enabled. Check the base request class's real code, or test
against the backend, before relying on cross-origin cookie behavior either
way.

---

## Related topics with their own document

- **A page that must look different per screen size** (mobile vs desktop
  layout): registering more than one form per route, with size thresholds
  and a per-variant HTML template. Full explanation and a worked example
  in `RESPONSIVE_FORMS.md`.

## Example 6 — Several applications on one server (`aBasePath`)

```
html/
  index.html
  pages/login.html            common pages
  css/
  app1/pages/items.html      one application
  app1/css/items.css
```

```pascal
// RegisterRoutes: the last parameter is the application's root folder ('app1' and 'app1/' are equivalent)
FPageManager.RegisterForm('login',  TFormLogin);                              // common: root folder ''
FPageManager.RegisterForm('items', TFormItems, 0, 0, '', 'app1/');          // app1/pages/items.html
FPageManager.RegisterForm('report', TFormReport, 0, 0, 'pages/rep.html', 'app1/');   // app1/pages/rep.html
```

```pascal
type
  TFormItems = class(TBaseForm)
  public
    class function loadNeededCSS(const aBasePath: String): Boolean; override;   // NOTE the parameter
    procedure BindUI; override;
  end;

class function TFormItems.loadNeededCSS(const aBasePath: String): Boolean;
begin
  // aBasePath = 'app1/': the stylesheet follows the application folder if it is renamed
  if not isCSSLoaded(aBasePath + 'css/items.css') then
    AWait(Boolean, loadResource(aBasePath + 'css/items.css', 'css'));
  Result := True;
end;

procedure TFormItems.BindUI;
begin
  // Self.BasePath = 'app1/' is already assigned here: use it for auxiliary templates
  // _RowTemplate := Self.BasePath + 'pages/asset-row.html';
end;
```

(`async` is not repeated in the implementation. `uLBWebUtils` provides `isCSSLoaded`/`loadResource`; the latter returns
a raw promise, hence `AWait`.)

---

## Example 7 — Rendering data with a template, and a long list

```pascal
uses TemplateEngine, uLBTemplateLoader, InfiniteScroller;

// A) render a block once: read the template as TEXT, render, then touch the DOM
procedure TFormUsers.ShowUsers(aUsers: TJSArray);
var
  _Tpl  : String;
  _Data : TJSObject;
begin
  _Tpl := AWait(String, LoadTemplate(Self.BasePath + 'pages/user-row.html'));   // cached
  _Data := TJSObject.new;
  _Data.Properties['users'] := aUsers;                  // raw values: {{name}} escapes
  FList.innerHTML := RenderTemplate(_Tpl, _Data);
end;
```

`pages/user-row.html` (placeholders may sit inside tags because the file is read as text, never injected raw):

```html
{{#each users}}
<div class="user" data-id="{{id}}" title="{{name}}">{{name}} {{#if admin}}<b>admin</b>{{/if}}</div>
{{else}}
<p>No users.</p>
{{/each}}
```

```pascal
// B) long list: the row template root must be a <div> (not <tr>/<li>); the data callback is a METHOD (of object)
FScroller := TInfiniteScroller.Create(ListContainer, '', Self.BasePath + 'pages/user-item.html');
FScroller.ItemsPerChunk := 25;
FScroller.LoadData(FItems.length, @Self.GetItemData);

function TFormUsers.GetItemData(const aIndex: Integer): TJSObject;
begin
  Result := TJSObject(FItems[aIndex]);
end;

destructor TFormUsers.Destroy;
begin
  FreeAndNil(FScroller);          // the scroller is yours, not the framework's
  inherited Destroy;
end;
```

---

## What these examples intentionally leave out

Modal dialogs (`ShowMessage(aTitle, aMessage, [aMsgType])` — title and message are
both required), advanced data grids (`uJSTabulator`), WebSocket and IndexedDB.
Consult `INDEX.md` for these.
