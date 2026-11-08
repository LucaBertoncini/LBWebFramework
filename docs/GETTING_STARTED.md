# Primi passi — una pagina "Hello" in 15 minuti

Obiettivo: un'applicazione con una pagina `hello` e un pulsante che cambia un titolo.
Le firme usate sono quelle di `Common/` (vedi `FRAMEWORK_REFERENCE.md`). Gli esempi non sono stati compilati qui:
se il compilatore dissente, vale il compilatore.

## 0. Come ragiona il framework (in 5 righe)

1. Esiste **un solo documento HTML**, `index.html`, con un guscio fisso (header, colonne, `#center-container`, footer).
2. Una **pagina** è un frammento HTML (`pages/<rotta>.html`) + una classe Pascal che deriva da `TBaseForm`.
3. Navigare significa **sostituire il contenuto di `#center-container`** e creare la classe della pagina; l'indirizzo cambia solo dopo il `#`.
4. La classe trova i propri elementi **per `id`** con `getElementById` e ci attacca gli eventi in `BindUI`.
5. HTML e CSS sono scritti a mano: il Pascal non genera markup complesso.

## 1. Struttura delle cartelle

```
html/
  index.html          (da Common/WebApplication/html/index.html)
  css/                (da Common/WebApplication/css/)
  pages/
    hello.html
```

In `index.html` correggi `<title>` e fai puntare `<script src="...">` al JavaScript prodotto da pas2js
(oggi è vuoto: la pagina non parte finché non lo imposti).

## 2. La pagina: `pages/hello.html`

È solo il **frammento** che finirà in `#center-container`, non una pagina completa:

```html
<h2 id="title">Hello</h2>
<button id="my-button">Clicca</button>
```

## 3. La classe: `Form.Hello.pas`

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
  public
    procedure BindUI; override;
  end;

implementation

procedure TFormHello.BindUI;
begin
  FTitle  := Self.getElementById('title');
  FButton := Self.getElementById('my-button');
  FButton.onclick := @Self.OnButtonClick;
end;

function TFormHello.OnButtonClick(aSender: TUIElementWrapper; aEvent: TJSMouseEvent): Boolean;
begin
  Result := True;
  FTitle.textContent := 'Cliccato!';
end;

end.
```

Non devi liberare i wrapper né sganciare `onclick`: lo fa il framework alla distruzione della pagina.

## 4. L'applicazione: `MyApp.pas` (programma principale)

```pascal
program MyApp;

{$mode objfpc}

uses
  Web, WebApplication, LayoutComponents, Form.Hello;

type
  TMyApp = class(TWebApplication)
  protected
    procedure RegisterRoutes(); override;
  end;

procedure TMyApp.RegisterRoutes();
begin
  // La PRIMA rotta registrata è la pagina di avvio.
  FPageManager.RegisterForm('hello', TFormHello);
end;

var
  App : TMyApp;

begin
  App := TMyApp.Create(nil, nil, nil, nil);   // nil = componenti di base per header/footer/colonne
  App.Run;
end.
```

`Run` carica il layout, chiama `RegisterRoutes` e avvia la navigazione. Aprendo `index.html` compare la pagina `hello`.

## 5. Le cose che servono subito dopo

| Voglio… | Come |
|---|---|
| andare a un'altra pagina | `gv_WebApplication.PageManager.NavigateTo('altra')` (+ `RegisterForm('altra', TFormAltra)`) |
| bloccare le pagine ai non autenticati | `FPageManager.OnValidatePage := ...` (restituisce la rotta da mostrare) — `FRAMEWORK_REFERENCE.md` §3 |
| un foglio di stile per la pagina | override di `class function loadNeededCSS(const aBasePath: String): Boolean; async;` |
| far dialogare due componenti | `gv_EventsManager.AddListener` / `RaiseEvent`; **nel distruttore** `RemoveListenersFor(Self)` |
| una lista lunga | `TInfiniteScroller` + un modello di riga (radice `<div>`) — §9 |
| rendere HTML da dati | `TemplateEngine.RenderTemplate` + `LoadTemplate` — §8 |
| un messaggio all'utente | `ShowMessage('Titolo', 'Testo', mtInformation)` |
| chiamare il server | `TJSAsyncPOSTRequest`: si attende con `AWait`, si controlla `.ok` (mai `try/except` sulla rete) |
| pagine diverse per mobile e desktop | `RegisterForm('r', TFormMobile)` + `RegisterForm('r', TFormDesktop, 768, 0, 'pages/r-desktop.html')` |
| più applicativi sullo stesso server | ultimo parametro `aBasePath` di `RegisterForm` ('wms/'), vedi sotto |

### Più applicativi sullo stesso server

```pascal
FPageManager.RegisterForm('assets', TFormAssets, 0, 0, '', 'cmms/');   // pagine in cmms/pages/assets.html
```

La pagina riceve la cartella in `BasePath` e in `loadNeededCSS(aBasePath)`:

```pascal
class function TFormAssets.loadNeededCSS(const aBasePath: String): Boolean;
begin
  if not isCSSLoaded(aBasePath + 'css/assets.css') then
    AWait(Boolean, loadResource(aBasePath + 'css/assets.css', 'css'));
  Result := True;
end;
```

(`uLBWebUtils` per `isCSSLoaded`/`loadResource`. Qui `AWait` è corretto: `loadResource` restituisce una promessa grezza.)

## 6. Gli errori più comuni

1. **Pagina muta, nessun errore** — `BindUI` non è stata chiamata o sovrascritta (un componente fuori da `TPageManager`/`LoadContent` la richiede esplicita), oppure un `id` nell'HTML non corrisponde a quello cercato.
2. **Il template non compare** — percorso sbagliato: guarda in console l'avviso `Could not load template … (percorso: …)`.
3. **Crash dopo un cambio pagina** — un `AddListener` senza `RemoveListenersFor(Self)` nel distruttore.
4. **Lista vuota con dati giusti** — la radice del modello riga è un `<tr>`/`<li>`: usa un `<div>`.
5. **Testo utente trattato come HTML** — non assegnare mai testo non fidato a `innerHTML`: usa `textContent`, `TextToHTML` o un modello (`{{campo}}` fa l'escape).
6. **Override di callback con funzione annidata** — dove il tipo è `of object` (InfiniteScroller, drop di Tabulator) serve un metodo vero; dove è `reference to` (EventsManager, `onclick`, menu) va bene anche una procedura anonima.
7. **`NavigateTo` che "non fa nulla"** — è stato chiamato mentre un'altra navigazione era in corso: le richieste esplicite sono ignorate, non accodate.

Poi: `FRAMEWORK_REFERENCE.md` per ogni modulo, `LBWebFramework-AI-SDK/EXAMPLES.md` per esempi più lunghi.
