# LBWebFramework — Riferimento

Riferimento delle unit di `Common/`, **scritto leggendo i sorgenti** (firme copiate dal codice, non
ricostruite). Completa il manuale discorsivo (`Pas2JS_SPA_Framework_Docs*.docx/.pdf`, nella stessa cartella) con tutte le unit e le firme complete.

Se questo documento e il codice non concordano, **vale il codice**: segnalalo.

## Indice

1. [Il guscio dell'applicazione](#1-il-guscio-dellapplicazione)
2. [WebComponent: TWebComponent, TUIElementWrapper, TBaseForm](#2-webcomponent)
3. [PageManager: rotte e navigazione](#3-pagemanager)
4. [WebApplication](#4-webapplication)
5. [LayoutComponents](#5-layoutcomponents)
6. [EventsManager](#6-eventsmanager)
7. [uLBWebUtils](#7-ulbwebutils)
8. [TemplateEngine e uLBTemplateLoader](#8-templateengine-e-ulbtemplateloader)
9. [InfiniteScroller](#9-infinitescroller)
10. [Dialogs](#10-dialogs)
11. [uLBTreeView](#11-ulbtreeview)
12. [uJSTabulator](#12-ujstabulator)
13. [WSManager](#13-wsmanager)
14. [IndexedDBHelper, LeastRecentlyUsedCache, uJSBasePOSTRequest](#14-unit-di-supporto)
15. [CSS e temi](#15-css-e-temi)
16. [Convenzioni di scrittura](#16-convenzioni-di-scrittura)

---

## 1. Il guscio dell'applicazione

`Common/WebApplication/html/index.html` è l'unico documento HTML dell'applicazione. Contiene il guscio fisso:

```html
<div id="app-container">
  <header id="app-header"></header>
  <main id="main-content">
    <aside id="left-column" class="hidden"></aside>
    <div id="center-container"></div>
    <aside id="right-column" class="hidden"></aside>
  </main>
  <footer id="app-footer" class="hidden"></footer>
</div>
<script>rtl.run();</script>
```

| Regione | Contenuto | Cambia con la navigazione? |
|---|---|---|
| `#app-header`, `#app-footer` | componenti header/footer | no |
| `#left-column`, `#right-column` | colonne laterali opzionali (partono `hidden`) | no |
| `#center-container` | **la pagina corrente** | **sì: è l'unica regione toccata da PageManager** |

Da adattare nella copia del progetto: `<title>`, il `<script src="">` (deve puntare al JS compilato da
pas2js), i fogli di stile e il font esterno di `--font-title`.

## 2. WebComponent

`WebApplication/WebComponent.pas`

### TWebComponent

Base di ogni componente legato a un elemento radice del DOM.

| Membro | Firma / tipo | Note |
|---|---|---|
| `Create` | `constructor Create(aRootElement: TJSHTMLElement); virtual; reintroduce` | **Non chiama `BindUI`.** |
| `BindUI` | `procedure BindUI; virtual` (public) | Va sovrascritta per legare elementi ed eventi. La chiama `TPageManager.LoadPage` dopo `Create` (per i `TBaseForm`) e `LoadContent` dopo l'iniezione del markup. Per un componente il cui markup è già nella pagina e che non usa `LoadContent`, **va chiamata esplicitamente subito dopo `Create`**: se manca, il componente non lega nulla e non dà alcun errore. |
| `getElementById` | `function getElementById(const anId: String): TUIElementWrapper` | Cerca **dentro `RootElement`**, non nel documento. Un wrapper per id, in cache. |
| `LoadContent` | `function LoadContent(const aTemplatePath: String): Boolean; async; virtual` | fetch → iniezione in `RootElement` → invalida la cache dei wrapper → `BindUI`. `True` se riuscita. |
| `RootElement` | `property RootElement: TJSHTMLElement` (read) | |
| `HasContent` | `property HasContent: Boolean` (read) | `True` dopo un `LoadContent` riuscito. |
| campi protetti | `FRootElement`, `FHasContent` | |

Il distruttore libera tutti i wrapper.

### TUIElementWrapper

Involucro di un elemento, con ricerca **pigra**. La ricerca usa `[id="..."]` dentro la radice del proprietario.
Un elemento non trovato non viene memorizzato: la chiamata successiva ricerca di nuovo (utile per
elementi creati dopo la prima lettura). Un elemento trovato resta in cache: se lo sostituisci con
`innerHTML`, richiedi un nuovo wrapper (o rilancia `LoadContent`).

| Membro | Note |
|---|---|
| `value: String` (read/write) | input, select, textarea in modo uniforme |
| `innerHTML: String` (read/write) | |
| `checked: Boolean` (read/write) | solo per `<input>` |
| `disabled: Boolean` (**solo write**) | |
| `textContent: String` (**solo write**) | testo semplice, senza markup |
| `onclick: TUIElementClickEventHandler` (**solo write**) | `reference to function(aSender: TUIElementWrapper; aEvent: TJSMouseEvent): boolean; safecall`. Assegnare `nil` lo rimuove. Se l'elemento non esiste ancora l'assegnazione è ignorata. |
| `onchange: TJSEventHandler` (solo write) | |
| `Attrib[aName]: JSValue` | dizionario di valori liberi legato al wrapper (non è un attributo HTML) |
| `ElementAttribute[aName]: String` | attributo HTML dell'elemento |
| `AsButton`, `AsInput`, `AsSelect`, `AsDiv` | cast tipizzati dell'elemento |
| `Clear()`, `setFocus()` | |
| `addClass`, `removeClass`, `containsClass` | |
| `appendChild(aChild: TJSNode): TJSNode` | |
| `getFile(): TJSHTMLFile` | primo file di un `<input type=file>` |
| `GetElement`, `querySelector`, `querySelectorAll` | accesso diretto al DOM |

Il distruttore sgancia `onclick`/`onchange`.

### TBaseForm (pagina di rotta)

```pascal
class function getTemplatePath(): String; virtual;                         // '' di default
class function loadNeededCSS(const aBasePath: String): Boolean; async; virtual;   // True di default
property BasePath: String read FBasePath write FBasePath;
```

* `getTemplatePath` — se restituisce un percorso non vuoto, **vince su tutto** ed è un percorso completo
  (la cartella radice non viene anteposta).
* `loadNeededCSS(aBasePath)` — l'override compone i percorsi dei propri fogli a partire da `aBasePath`
  (`'wms/'`, `'cmms/'` oppure `''`). **La firma ha il parametro**: un override senza parametro non
  corrisponde al metodo virtuale.
* `BasePath` — la stessa cartella, disponibile all'istanza (per template ausiliari). Assegnata prima di `BindUI`.

`TBaseFormClass = class of TBaseForm`.

## 3. PageManager

`WebApplication/PageManager.pas`

```pascal
procedure RegisterForm(aRoute: string; aFormClass: TBaseFormClass;
                       aMinWidth: NativeInt = 0; aMinHeight: NativeInt = 0;
                       const aHtmlFile: String = ''; const aBasePath: String = '');
procedure NavigateTo(aRoute: string);
procedure StartRouting;
procedure Back();
property CurrentForm: TBaseForm read;
property OnValidatePage: TOnValidatePageEvent write;   // reference to function(aPage: String): String; safecall
property OnPageLoaded:   TOnPageLoadedEvent  write;    // reference to procedure(aRoute: String); safecall
```

Costanti: `cPageManager_PagesFolder = 'pages/'`, `cPageManager_TemplateExt = '.html'`.

**Rotte.** Una rotta è una stringa libera (l'hash dell'indirizzo, senza `#`). La **prima** registrata è la pagina
di avvio. La stessa rotta può essere registrata più volte con soglie diverse (§ varianti).

**Scelta del template**, in ordine di precedenza:
1. `getTemplatePath` della classe, se non vuoto (percorso completo);
2. `aHtmlFile` della registrazione, relativo alla cartella radice (`aBasePath`);
3. `aBasePath + 'pages/' + rotta + '.html'`.

`aBasePath` riceve la barra finale se manca (`'wms'` ≡ `'wms/'`).

**Sequenza di `LoadPage`** (unico punto di passaggio di ogni navigazione): `OnValidatePage` può trasformare la rotta →
scelta della registrazione → `loadNeededCSS(BasePath)` → fetch del template → **solo se riuscito**: libera la pagina
precedente, inietta il markup, crea l'istanza, assegna `BasePath`, `BindUI` → cronologia → `OnPageLoaded(rotta effettiva)`.
Se il template non si trova resta a schermo la pagina precedente. L'esito di `loadNeededCSS` non viene verificato.

**Varianti per dimensione schermo.** Fra le registrazioni di una rotta: quella con minimi `0,0` è il predefinito; le altre
sono candidate se `window.innerWidth/innerHeight` soddisfano **entrambi** i minimi; vince la `MinWidth` più alta.
Valutato a ogni navigazione.

**Una navigazione per volta.** Mentre un caricamento è in corso, `NavigateTo` viene **ignorato** (non accodato).
Una richiesta del browser (indietro/avanti) arrivata nel frattempo viene ricordata (solo l'ultima) ed
eseguita al termine, perché la cronologia è già cambiata.

**Comportamenti della cronologia :**
* indirizzo di apertura con rotta non registrata → ripiego sulla prima rotta;
* navigare alla rotta già presente nell'hash sostituisce la voce invece di aggiungerne una uguale;
* se `OnValidatePage` trasforma una richiesta del browser (es. pagina riservata → `login`), l'hash viene
  aggiornato alla pagina realmente mostrata.

Non esistono parametri di rotta: la rotta intera è confrontata con le registrazioni (`detail?id=3` non corrisponde a `detail`).

## 4. WebApplication

`WebApplication/WebApplication.pas`

```pascal
constructor Create(aHeaderClass, aFooterClass, aLeftColumnClass, aRightColumnClass: TLayoutComponentClass); virtual; reintroduce;
procedure Run; async;                         // InitializeLayout → RegisterRoutes → StartRouting
procedure RegisterRoutes(); virtual; abstract; // protected: da implementare
procedure InitializeHeader/Footer/LeftColumn/RightColumn; virtual; async;   // protected, vuote
procedure InitializeLayout; virtual; async;
function  RequestWakeLock(): boolean; async;
procedure ReleaseWakeLock(); async;
procedure SetupWakeLockAutoRenew();
property  PageManager: TPageManager read;
var gv_WebApplication: TWebApplication;       // impostata dal costruttore
```

Le quattro classi sono `nil` → si usa la classe base. Gli elementi cercati nel DOM sono `app-header`, `app-footer`,
`left-column`, `right-column`, `center-container`.

**Wake lock :** `SetupWakeLockAutoRenew` registra un solo listener su `visibilitychange`; il lock viene
riacquisito solo quando la pagina torna **visibile** e solo se l'applicazione lo aveva ottenuto (`RequestWakeLock`) e non
rilasciato. Il listener è rimosso dal distruttore.

## 5. LayoutComponents

`WebApplication/LayoutComponents.pas`. `TLayoutComponent` (marcatore, deriva da `TWebComponent`),
`THeaderComponent`, `TFooterComponent`, `TSideColumnComponent`.

`TSideColumnComponent`: `Show`, `Hide`, `Toggle`, `IsVisible`. Parte nascosta. `Show` richiede `HasContent` (cioè un
`LoadContent` riuscito). Sotto `MOBILE_BREAKPOINT = 768` px si nasconde da sola al ridimensionamento; sopra si rimostra se
ha contenuto. Ogni cambio di stato emette l'evento `layout:column-toggled` (payload: l'elemento radice).

`Hide` chiamato dal codice applicativo è *definitivo* finché non si richiama `Show`: il ridimensionamento
della finestra non rimostra più una colonna nascosta di proposito. Il nascondimento automatico sotto 768 px non ha questo effetto.

## 6. EventsManager

`EventsManager.pas`. Istanza globale `gv_EventsManager: TjsEventsManager` (creata all'avvio).

```pascal
TjsEventCallback = reference to procedure(Sender: JSValue);
procedure AddEvent(const EventName: String);                       // facoltativo
procedure AddListener(const EventName: String; Owner: JSValue; Callback: TjsEventCallback);
procedure RemoveListenersFor(const Owner: JSValue);
procedure RaiseEvent(const EventName: String; Sender: JSValue);    // "Sender" è il PAYLOAD
function  HasEvent(const EventName: String): Boolean;
```

* `Callback` è un tipo `reference to`: **accetta procedure anonime** che catturano variabili locali.
* `RaiseEvent` è sincrono e lavora su una copia dell'elenco (un handler può annullare iscrizioni durante l'invio).
* Un'eccezione in un listener non ferma gli altri. viene scritta in console (`console.error`) invece di essere persa.
* **Chi chiama `AddListener` deve chiamare `RemoveListenersFor(Self)` nel proprio distruttore.**

## 7. uLBWebUtils

`uLBWebUtils.pas`

| Elemento | Note |
|---|---|
| `TJSAsyncPOSTRequest` | `Create` (virtual; URI predefinito `'/'`), `URI` (write), `Data: TJSObject` (write; nelle classi derivate si riempie `FData`), `execute: TJSPromise`. POST JSON via XMLHttpRequest. **Risolve sempre, non rifiuta mai.** |
| `TJSPOSTRequestAnswer` | `NetworkErr`, `NotExecuted`, `Answer: JSValue` (solo per i 2xx), `ok()`, `HttpStatus: Integer` (0 se non è arrivata al server), `HttpError()` (`HttpStatus >= 400`), `ErrorAnswer: JSValue` (corpo JSON di una risposta di errore, se c'è). |
| esito | `ok()` è vero per i soli 2xx con JSON valido. Per un errore HTTP `Answer` resta vuoto e il corpo JSON dell'errore è in `ErrorAnswer`, il codice in `HttpStatus`: si distingue così "sessione scaduta" (401) da "rete assente" (`HttpStatus = 0`). |
| `loadResource(anURL, aType: String; anId: String = ''): TJSPromise` | `aType` = `'css'` o `'js'`; promessa con `True/False`. Stesso URL → stessa promessa, mai due `<link>`; chi arriva a download in corso attende lo stesso esito; un fallimento non resta in cache. |
| `isCSSLoaded(href): Boolean` | confronto con URL assoluti. `False` per un foglio ancora in download. |
| `HtmlEncode(aText)` | `& < > " '`. include l'apice singolo. |
| `TextToHTML(aText)` | `HtmlEncode` + a-capo → `<br/>`. Da usare per testo utente destinato a `innerHTML`. |
| `MarkdownLiteToHtml(aRawText)` | titoli, elenchi `-`/`*`, grassetto/corsivo, paragrafi. Esegue già l'escape: non escapare prima. Niente link, codice, tabelle. |
| `getWSProtocol()` | `'wss:'` o `'ws:'` secondo la pagina |
| `convertToIsoDate(aDate)` | `dd/mm/yyyy` → `yyyy-mm-dd`, `''` se non valida |
| `FreeAndNilEx(var anObj: TObject)` | libera ignorando eccezioni |
| `globalThis: TJSGlobalThis` | accesso a `fetch`, `Location`, `IndexedDB`, `Console` |

## 8. TemplateEngine e uLBTemplateLoader

`TemplateEngine/TemplateEngine.pas`

```pascal
function RenderTemplate(const aTemplate: string; const aData: TJSObject): string;
function RenderTemplateWithPartials(const aTemplate: string; const aData: TJSObject; const aPartials: TJSObject): string;
```

Sintassi: `{{campo}}`, `{{a.b}}`, `{{{campo}}}` (senza escape), `{{this}}`, `{{../campo}}`,
`{{#each lista}}…{{else}}…{{/each}}`, `{{#if c}}…{{else}}…{{/if}}`, `{{#unless c}}…{{/unless}}`, `{{> nome}}`.
Falso: assente, `null`, `false`, `0`, `''`, array vuoto. Profondità massima 32.
Guida completa con esempi: `Common/TemplateEngine/TemplateEngine.md`.

Escape: `{{campo}}` usa `TextToHTML`; dentro un tag (valore di attributo) usa `HtmlEncode`, senza `<br/>`.

`TemplateEngine/uLBTemplateLoader.pas` 

```pascal
function LoadTemplate(const aPath: String): String; async;             // testo, con cache; '' se fallisce
function LoadTemplateSections(const aPath: String): TJSObject; async;  // file con più modelli <!-- @nome -->
function SplitTemplateSections(const aText: String): TJSObject;
procedure ClearTemplateCache;
```

Un modello con segnaposto dentro i tag va letto come **testo** e reso prima di toccare il DOM.

## 9. InfiniteScroller

`InfiniteScroller.pas`

```pascal
TGetDataForIndexEvent  = function(const aIndex: Integer): TJSObject of object;      // METODO di un oggetto
TGetRenderedItemsIndex = procedure(aStartIndex, anEndIndex: Integer) of object;     // METODO di un oggetto
constructor Create(aContainer: TJSHTMLElement; const anItemTemplate, anItemTemplatePath: string);
procedure LoadData(aTotalCount: Integer; aOnGetData: TGetDataForIndexEvent);
procedure LoadNextChunk(); async;
procedure Clear;
procedure setTotalItemsCount(aValue: Integer);
property ItemTemplate: String write;  property ItemsPerChunk: Integer write;  // predefinito 20
property OnChunkRendered: TGetRenderedItemsIndex write;
```

* Template inline **oppure** da file (se l'inline è vuoto si usa il percorso). Reso con `RenderTemplate` per ogni elemento.
* **La radice del modello deve poter essere figlia di un `<div>`**: `<tr>`, `<td>`, `<th>`, `<li>`, `<option>` vengono scartati dal parser e l'elemento non compare (il componente lo segnala in console).
* Carica il chunk successivo vicino al fondo (soglia 300 px). Se il primo chunk non riempie il contenitore, continua da solo.
* Gli handler sono **metodi** (`of object`): le procedure anonime non sono ammesse.
* `Clear` svuota e azzera lo stato; il listener di scroll resta (si toglie con `Destroy`).

## 10. Dialogs

`WebApplication/Dialogs.pas`

```pascal
TMessageType = (mtInformation, mtWarning, mtError, mtConfirm);
procedure ShowMessage(const aTitle, aMessage: String; aMsgType: TMessageType = mtInformation);
```

Modale non bloccante, con un solo pulsante OK, `z-index` 10000 (sopra qualunque altro modale). Titolo **e** messaggio
sono obbligatori. Stile in `css/modalDialog.css`. Non esiste una finestra di conferma Sì/No.
`Dialogs_old.pas` è una copia precedente di `Dialogs.pas` (senza lo `z-index`): non usarla in codice nuovo.

## 11. uLBTreeView

`LBTreeView/uLBTreeView.pas` (+ `LBTreeView.css`)

```pascal
constructor Create(anOwner: TJSHTMLElement; isChecked: Boolean; isSingleSelect: Boolean = False; isCheckOnlyLeaf: Boolean = False);
procedure setData(aData: TJSArray; anIdProperty, aViewedProperty, aChildrenProperty: String);   // dati ANNIDATI
procedure renderData();
procedure select(anIdList: TJSArray);
procedure setChecked(anItemIdx: Integer; isChecked: Boolean);   procedure uncheckItems();
function  getExpandedIds: TJSArray;   procedure setExpandedIds(anIds: TJSArray);   function findItemElement(const anId: String): TJSHTMLElement;
procedure setContextMenuCallback(aCallback: TLBTreeViewMenuCallback);
property Item[Idx]; CheckedItems; CheckedElems; CheckedList (write); SingleSelect; CheckOnlyLeaf;
property WrapLongLabels; OnlyCaretToggles; ChevronCaret;   // opzioni, False di default
property LabelsAreHtml;                                    // True di default
```

* `TLBTreeViewMenuCallback = reference to function(aItem: TJSObject): TJSArray` — restituisce le voci;
  `TLBTreeViewMenuItem.Create(aCaption, aCallback)` con `TLBTreeViewMenuItemCallback = reference to procedure(aItem: TJSObject)`;
  opzioni `IconClass`, `Group`, `Danger`. Callback `reference to`: anche procedure anonime.
* Nessun evento "nodo selezionato" da un click semplice (il click sulla checkbox ferma la propagazione): si usa il menu contestuale o `CheckedItems`.
* Dati piatti con `parent_id` vanno convertiti in annidati prima di `setData`.
* `LabelsAreHtml` (default **True**): le etichette dei nodi e il testo delle voci di menu sono inseriti come HTML, senza escape. Impostandola a `False` diventano **testo** (`HtmlEncode`): da usare quando i nomi arrivano dagli utenti.
* Classi derivate possono sovrascrivere `insertArray` e `renderWrapper` (protetti).

## 12. uJSTabulator

`uJSTabulator.pas` è un involucro Pascal della libreria JavaScript **Tabulator**, che il progetto deve caricare
per conto proprio (non è inclusa in `Common/`).

* `TTabulator.Create(aPanel: TJSHTMLDivElement)`, `setData`, `setDataIndex`, `addColumnHeader(TTabulatorHeader)`, `Draw`, `redraw`,
  `addRow`, `updateValue`, `updateRowValues`, `getRowByUniqueIndex`, `getRowDataBy…`, menu di riga (`addFixedRowMenuItem`, `setDynamicRowMenu`),
  albero (`UseTreeData(aData, TTreeDataOptions)` → `TTreeDataDefaultHeaders`), trascinamento tra tabelle (`EnableDrag`, `EnableDrop`, `OnDrop`), `OnCellClick`, `RowCount`, `innerTable`.
* `TTabulatorHeader`: `setTitle`, `setField`, `setFormatter`, `setMutator`, `setSortable`, `setMinWidth`, `setMaxWidth`, `setWidthGrow`, `setInputFilter`, `setOnClick`, …
* Callback `reference to`: procedure anonime ammesse. Fa eccezione `TTabulatorDropHandler` (`of Object`).
* La modalità albero registra la tabella in `window.__tabulators[<id del pannello>]`: **il pannello deve avere un `id`**.
* Modalità albero: `TTreeDataOptions.DescriptionIsHtml` (default **True**) inserisce la descrizione come HTML; con `False` è testo (`HtmlEncode`). Gli id passati agli handler inline sono sempre argomenti stringa protetti.

## 13. WSManager

`WSManager.pas`. `TWSManager.Create(const aURL: String)` (usare `getWSProtocol()` per costruire l'URL), `Open`, `Close`,
`sendMessage(aMsg: TJSObject): Boolean`, `State`, `EventFieldName` (write, predefinito `'event'`), `OnStateChange` (write).
`DataFieldName` (write).

Ogni messaggio JSON ricevuto diventa un evento sul bus (`gv_EventsManager.RaiseEvent(<valore del campo evento>, <messaggio o campo dati>)`).
Riconnessione automatica con ritardo 2 s → 30 s. Eventi: `cWS_Connected = 'ws.connected'`, `cWS_Disconnected = 'ws.disconnected'`.
`sendMessage` invia solo a connessione aperta (`False` altrimenti); `Close` emette `ws.disconnected`; un messaggio senza campo evento è scartato.

## 14. Unit di supporto

* **IndexedDBHelper** — `TIndexedDBHelper.Create(aDBName, aDBVersion, aStoreName)`; record `{id, data, timestamp}`.
  `GetRecord(aId)` (restituisce il record intero o `undefined`), `StoreRecord(aId, aData)`, `DeleteRecord(aId)`, `DeleteOldRecords(aMaxAgeInMs)`.
  tutte si attendono con `AWait`, terminano a transazione completata e propagano gli errori; l'apertura del database è condivisa fra chiamate concorrenti.
* **LeastRecentlyUsedCache** — `TLRUCache.Create(ACapacity)`, `Put`, `Get`, `Has`; `Remove`, `Clear`, `Count`; tutte O(1).
* **uJSBasePOSTRequest** — `TJSBasePOSTRequest`, versione storica basata su jQuery (`libjquery`) con callback `OnSuccess`/`OnError`. Per codice nuovo usare `TJSAsyncPOSTRequest`.

## 15. CSS e temi

Tutto si basa su variabili CSS in `:root` (`basicAppStyle.css`); il tema attivo è l'attributo `site-style` di `<html>`
(`light`, `dark`, `dany`: `additionalStyles.css`). Variabili principali: `--color-primary(-hover)`, `--header-bg`, `--footer-bg`,
`--form-bg`, `--form-border`, `--modal-bg`, `--modal-text`, `--scrollbar-thumb(-hover)`, `--font-main`, `--font-title`.
File: `basicAppStyle.css` (variabili, reset), `additionalStyles.css` (temi), `appLayout.css` (layout a colonne), `scrollbar.css`,
`forms.css`, `modalDialog.css`. Cambio tema a runtime: `document.documentElement.setAttribute('site-style', 'dark')`.

## 16. Convenzioni di scrittura

* `F` per i campi, `a`/`an` per i parametri, `_` per le variabili locali.
* `async` compare **solo nella dichiarazione dell'interfaccia**, mai nell'implementazione.
* `AWait` attende una promessa, e la chiamata di una routine `async` lo è (il framework stesso scrive `AWait(Self.InitializeHeader)`); `AWait(Tipo, …)` restituisce anche il risultato. Chiamare una routine `async` senza `AWait` la avvia senza attenderla (corretto da un gestore di evento non `async`). `AWait` si usa solo dentro una routine `async`.
* Un callback dichiarato `of object` accetta solo un metodo di un oggetto (`@Self.Metodo`), mai una funzione annidata. Un callback `reference to` accetta anche procedure anonime e funzioni annidate. Per sapere quale è, guardare la dichiarazione del tipo.
* Mai `innerHTML` con testo non fidato senza `TextToHTML`/`HtmlEncode` o senza un modello che lo escapi.
