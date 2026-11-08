# Golden Rules and Known Gotchas — LBWebFramework

A condensed reference of non-negotiable conventions and known traps.
Each entry states the rule, and — where it matters — *why*, so it can be
recognized in situations this list doesn't explicitly cover.

## The View is real HTML/CSS, by deliberate design — not a converted form

This is architectural, not a style preference, and it's worth stating
explicitly because there is a well-known alternative approach in the
Pascal/Delphi ecosystem that this framework deliberately does **not**
follow: some Pascal-based web frameworks let you design a classic
Lazarus/Delphi-style form (drag-and-drop components on a canvas) and then
convert or render that form's definition into HTML/CSS/JS at runtime or
build time. LBWebFramework does not do this. Every page's View is
**hand-written HTML and CSS**, full stop — the framework never generates
markup from a form designer, and never abstracts CSS behind a Pascal-side
styling API.

**Why this matters, and what it enables:**

- **Full access to real HTML/CSS capabilities.** A converted-form approach
  necessarily exposes only the subset of HTML/CSS the conversion layer was
  built to support. Hand-written HTML/CSS has no such ceiling: any layout
  technique, animation, responsive breakpoint, or accessibility attribute
  available in modern CSS is available here, with nothing standing between
  the developer and the platform.
- **A clean division of labor between roles.** Because the View is plain
  HTML/CSS and the Logic is plain Pascal, with `TWebComponent.getElementById`
  as the only bridge between them (see `TWebComponent`/`TUIElementWrapper`
  in `docs/FRAMEWORK_REFERENCE.md`, §2), **a designer who knows neither Pascal nor
  JavaScript can build and refine the View independently** — they only need
  to preserve the `id` attributes the Pascal component looks up.
- **What this means for you, concretely:** never suggest generating HTML
  from a Pascal-side form/component definition, and never suggest a
  templating abstraction that hides CSS behind Pascal properties. If a
  task seems to call for either, it's a sign the View/Logic boundary is
  being blurred — stop and re-read this section, and see `EXAMPLES.md` §0
  and §1 for what the boundary looks like in a working example.

## Callbacks: look at the type before choosing what to pass

The rule is about **the declared type of the callback**, not about the framework in general.

- **`... of object`** (an instance + a method address) accepts **only a real method**: `@Self.MyMethod` or
  `@_Instance.TheMethod`. A function declared inline inside another method (a "nested function") or an
  anonymous procedure is **not compatible with `of object`** — the compiler represents them differently and
  no modifier makes them interchangeable. In `Common/` these are:
  `TGetDataForIndexEvent`, `TGetRenderedItemsIndex` (`TInfiniteScroller`) and `TTabulatorDropHandler`.
- **`... reference to`** accepts a method, a nested function **and an anonymous procedure/function that
  captures local variables**. In `Common/` these are, among others: `TjsEventCallback` (`gv_EventsManager.AddListener`),
  `TUIElementClickEventHandler` (`wrapper.onclick`), `TOnValidatePageEvent`, `TOnPageLoadedEvent`, the
  `uLBTreeView` menu callbacks, the `uJSTabulator` formatter/click types, and the executor of `TJSPromise.New`.
  The examples in this SDK use anonymous procedures for these.

When a callback is `of object` and you need to carry a few local values (an id, a status, a note): do not
reach for a nested function. Create a small dedicated class, promote the values to fields, expose a real
method with the required signature and pass `@_Instance.TheMethod`. Give that helper a strictly local,
synchronous lifetime — create it immediately before the call that uses it and free it right after (a plain
`try/finally` is enough; no reference-counted interface is needed for an object that never leaves one method).
If the project's own convention is stricter than the language (e.g. "no closures anywhere"), follow the project.

## Memory and object lifecycle

The framework is deliberately built so that listeners and wrappers are
released for you. Knowing exactly what is automatic vs. what is your
responsibility avoids both leaks and double-frees. All items below are
verified against the real source (`WebComponent.pas`, `PageManager.pas`,
`LayoutComponents.pas`, `EventsManager.pas`).

**What the framework frees automatically — do NOT free these yourself:**

- **`BindUI` is NOT called by the constructor.** `TPageManager.LoadPage` calls it for pages and `LoadContent`
  calls it after injecting markup. Any other component whose markup is already in the page must call `BindUI`
  itself right after `Create`; if it doesn't, nothing is bound and nothing reports an error.
- **`TUIElementWrapper` instances obtained via `getElementById`.**
  `TWebComponent` caches every wrapper you request in an internal map and
  frees them all in `DestroyElements` on destruction. Its own `Destroy`
  also clears its `onclick`/`onchange` first, so you never manually detach
  a click handler set through a wrapper.
- **The previous page's form, on navigation.** `TPageManager.ClearCurrentForm`
  keeps exactly ONE form alive at a time: navigating away frees the old
  form (and empties `#center-container`) before creating the next. So a
  page's `Destroy` is genuinely called on navigation — put your cleanup
  there and trust it runs.
- **`TSideColumnComponent`'s resize listener.** It registers a `resize`
  listener in its constructor and removes it explicitly in its destructor
  (to avoid a dangling reference firing on a freed object). Side columns
  also auto-hide below `MOBILE_BREAKPOINT` (768) and re-show above it, but
  only if they already have content loaded. A column you hid with `Hide`
  stays hidden until you call `Show` (a window resize does not bring it back).

**What IS your responsibility:**

- **Helper objects you create yourself** (an `InfiniteScroller`, a
  detail-panel helper, a barcode scanner, a small transactional-work
  object) are NOT owned by the framework: free them in your form's
  `Destroy` with `FreeAndNil`.
- **`gv_EventsManager` subscriptions.** Every component that called
  `AddListener` MUST call `gv_EventsManager.RemoveListenersFor(Self)` in
  its own destructor. Otherwise the bus keeps a reference to a destroyed
  object, and the next `RaiseEvent` invokes a callback on freed memory.
- **Native browser listeners you attach by hand** (a `resize`, `scroll`,
  `keydown` on a raw DOM element, or a hand-built XHR) — store the
  reference and remove it explicitly in the destructor, *before* any other
  cleanup step. The wrapper-level cleanup does not cover these.
- When replacing a component that owns native listeners or timers (e.g. a
  new `TInfiniteScroller` instance replacing an old one), always free the
  old instance first — a stale listener on an orphaned object keeps firing
  silently.

**Two `EventsManager` guarantees worth relying on (verified):**

- `RaiseEvent` iterates a **snapshot copy** of the listener list, so a
  handler may safely unsubscribe itself (or others) during dispatch
  without corrupting the loop.
- `RaiseEvent` is synchronous — a slow handler delays whoever raised the
  event. Exceptions thrown inside a handler never reach the raiser, so one
  faulty handler never blocks the others (they are written to the browser
  console with `console.error`). Corollary: never rely on an
  exception propagating out of a raised event — it won't.

## Asynchronous code

- The `async` modifier appears **only in the interface declaration**,
  never repeated in the implementation.
- `AWait`/`Await` **waits for a promise** — and a call to a routine declared `async`
  is one. The framework itself does this (`AWait(Self.InitializeHeader)`,
  `AWait(Boolean, _FormClass.loadNeededCSS(...))`, `AWait(Boolean, Self.LoadTemplate())`).
  `AWait(Type, ...)` also unwraps the result of a function (`execute()`, `fetch()`,
  `loadResource()`, an `async` function).
- Calling an `async` routine **without** `AWait` starts it and does not wait for it
  (fire and forget). That is the right call from a non-async event handler
  (`Self.DoLoginAsync(...)` in `EXAMPLES.md` §5), and the wrong one when the next
  line needs the result.
- `AWait` can only be used inside a routine that is itself `async`.

## Backend communication

- Any request-building base class in this framework resolves its promise
  **always**, and rejects **never** — even on network failure or timeout.
  The caller checks the outcome via an `.ok`-style property, without
  needing a `try/except` around network errors. With `TJSAsyncPOSTRequest`
  `.ok` is true only for a 2xx answer with valid JSON. For an HTTP error the
  answer also carries `HttpStatus` and, if the body is JSON, the server's
  message in `ErrorAnswer`; `HttpStatus = 0` means the request never
  reached the server. Use this to tell "session expired" (401) from "offline". If you build a new REST
  client on top of this framework, follow the same contract: resolve
  always, let the caller decide what a failure means.
- If a project's backend exposes **path-based REST endpoints** (distinct
  resources at distinct URIs, HTTP verbs used semantically), the
  framework's default request base class — built for a single-endpoint,
  action-in-body RPC style — is very likely **not** the right tool as-is.
  Check whether the project has its own REST client wrapper before
  assuming the default one applies.

## The tree component (`uLBTreeView`)

- **There is no "node selected" event triggered by a plain click.** The
  checkbox click handler internally calls `Event.stopImmediatePropagation`,
  which prevents any other listener — even on ancestor elements — from
  reacting to that click. If a task requires reacting to a node being
  chosen (e.g. to open a detail panel), the correct approach, without
  modifying the shared component, is to use the **context menu**
  (right-click) — a separate, fully supported event path — or to read the
  selection state (`CheckedItems`) after the checkbox event has already
  fired, if selection alone is a sufficient signal.
- Flat data from a backend (e.g. rows with a `parent_id` reference,
  typical of an `ltree`-style hierarchy query) must be converted into a
  **nested** structure client-side before being handed to `setData`. The
  component always expects a nested `children` property, never a flat
  list with parent references.
- Node labels and context-menu captions are inserted as **HTML** by default
  (`LabelsAreHtml = True`). When they can contain text that comes from users,
  set `LabelsAreHtml := False` so they are escaped. The same applies to the
  tree mode of `uJSTabulator` (`TTreeDataOptions.DescriptionIsHtml`).

## Templates and untrusted text

- `{{campo}}` escapes (`TextToHTML`; inside an attribute, `HtmlEncode`). Pass **raw** values: pre-escaping
  gives double encoding. `{{{campo}}}` does not escape: only for HTML the application itself produced.
- Never assign user/server text to `innerHTML` directly; use `textContent`, `TextToHTML`, or a template.
- A template with placeholders inside tags (`data-id="{{id}}"`) must be read as **text** (`LoadTemplate`,
  or `fetch` + `.text()`) and rendered before touching the DOM, never injected raw.
- A row template for `TInfiniteScroller` must have a root the browser accepts inside a `<div>`
  (not `<tr>`, `<td>`, `<th>`, `<li>`, `<option>`).

## Several applications on one server

`RegisterForm(aRoute, aClass, aMinWidth, aMinHeight, aHtmlFile, aBasePath)`: `aBasePath` (`'wms/'`) is the
application's root folder; the template is `aBasePath + aHtmlFile` (or `aBasePath + 'pages/<route>.html'`).
The page receives the folder in `class function loadNeededCSS(const aBasePath: String)` and in the instance
property `BasePath`. **The override must have the `aBasePath` parameter** — `loadNeededCSS()` without it does
not match the virtual method. Never keep a global "current folder" in the application: bind the folder to the
registration, as the framework does.

## Components with known incomplete implementations

Components that wrap hardware or an external JS library (barcode scanning
is the usual example — it is **not** part of the `Common/` folder in this
package) may have a core method body commented out or an interface that is
stable while the integration is unfinished. **Do not assume such a
component is production-ready without opening its source file first** and
checking for exactly this kind of gap. In this package, `uJSTabulator`
additionally needs the Tabulator JavaScript library loaded by the project.

## Style and naming

- Private fields: `F` prefix. Parameters: `a` prefix. Local variables: `_`
  prefix. This is inherited from Delphi/FPC convention and is followed
  consistently — deviating from it in new code makes it visibly
  inconsistent with the rest of the codebase, which is itself a signal
  worth avoiding.
- View (HTML templates) and logic (Pascal components) are strictly
  separated: HTML never contains application logic, and Pascal code never
  generates complex inline markup, with the narrow exception of components
  that build DOM dynamically by design (e.g. modal dialog helpers).

## Responsive pages span more than one form

When a route needs different layouts per screen size, it is registered
with more than one form (one per device class), not solved with CSS alone.
That is a topic of its own — see `RESPONSIVE_FORMS.md`. The lifecycle
rules above still apply to each variant.

## The one rule that overrides all the others

If a situation isn't covered by any entry above, and the available
documentation doesn't resolve it either: **do not proceed on a plausible
guess.** State what's missing and ask. See `SYSTEM_PROMPT.md`, rule 1.
