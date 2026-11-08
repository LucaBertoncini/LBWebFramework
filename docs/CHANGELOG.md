# Changelog — LBWebFramework (Common)

Qui vanno le variazioni di comportamento. Le note storiche ("AGGIORNAMENTO", "BUGFIX", "NUOVO") presenti nei commenti
dei sorgenti restano dove sono finché non vengono riscritte; i cambiamenti nuovi si registrano qui.

## Documentazione
* Tutta la documentazione sta in `docs/`: `FRAMEWORK_REFERENCE.md`, `GETTING_STARTED.md`, `CHANGELOG.md` e il manuale (`Pas2JS_SPA_Framework_Docs.docx` in italiano, `…_EN.docx` e `…_EN.pdf` in inglese, versione 1.1). I tre file del manuale prima stavano in `Common/WebApplication/`.
* Manuale 1.1: descrizione di `Create`/`BindUI`, firme di `loadNeededCSS`, `RegisterForm`, `TWebApplication.Create`, `ShowMessage`, scelta del template e regole dell'InfiniteScroller allineate al codice; nuovo capitolo 7 sugli altri moduli.

## Lotto 2 — correzioni e pulizia

Nessuna firma pubblica esistente è stata modificata o rimossa; le aggiunte sono tutte in coda o nuove.

### Correzioni
| Unit | Correzione |
|---|---|
| `uLBWebUtils` | `TJSPOSTRequestAnswer`: nuovi campi `HttpStatus`, `ErrorAnswer` e `HttpError()`; `Answer` e `ok()` invariati. |
| `uLBWebUtils` | `loadResource`: promessa condivisa per URL, nessun `<link>` doppio, un fallimento non resta in cache. `isCSSLoaded`: `False` per un foglio ancora in download. |
| `uLBWebUtils` | `HtmlEncode` neutralizza anche l'apice singolo. |
| `PageManager` | rotta iniziale non registrata → prima rotta; richieste del browser durante una navigazione non più perse; hash aggiornato quando `OnValidatePage` reindirizza; nessuna voce di cronologia duplicata navigando alla rotta corrente. |
| `WebComponent` | `TUIElementWrapper` non memorizza più un elemento non trovato; ricerca con `[id="…"]`; il distruttore non interroga il DOM per wrapper mai risolti. |
| `LayoutComponents` | `Hide` dell'applicazione non è più annullato dal ridimensionamento della finestra. |
| `WebApplication` | wake lock: listener rimovibile (riferimento conservato), riacquisizione solo a pagina visibile e solo se il lock era stato richiesto, errori gestiti. |
| `EventsManager` | le eccezioni nei listener vengono scritte in console. |
| `WSManager` | `DataFieldName` impostabile; `sendMessage` solo a connessione aperta; `Close` emette `ws.disconnected`; messaggi senza campo evento scartati. |
| `indexeddbhelper` | `GetRecord` non resta più in attesa se l'apertura fallisce; `StoreRecord`/`DeleteRecord`/`DeleteOldRecords` attendono la transazione; apertura condivisa fra chiamate concorrenti. **Cambio di tipo:** `GetRecord` è ora `function …: JSValue; async` (prima restituiva `TJSPromise`): l'uso con `AWait` è identico, chi usava `.then` sul risultato va rivisto. |
| `TemplateEngine` | dentro un tag `{{campo}}` non converte più gli a-capo in `<br/>`. |
| `uLBTreeView` | nuova property `LabelsAreHtml` (default True = comportamento storico); con `False` etichette e voci di menu sono escapate. |
| `uJSTabulator` | modalità albero: `style` chiuso correttamente senza FontAwesome, id passati agli handler inline come stringhe protette; nuova opzione `TTreeDataOptions.DescriptionIsHtml` (default True = comportamento storico). |
| `leastrecentlyusedcache` | O(1); `Remove`, `Clear`, `Count`; capacità minima 1. |

### Aggiunte
* `TemplateEngine/uLBTemplateLoader.pas`: `LoadTemplate`, `LoadTemplateSections`, `SplitTemplateSections`, `ClearTemplateCache`.

### Pulizia
* Rimossi i riferimenti a DMA e a `uIdroWorld_Dom_Utils` da commenti, CSS e documentazione; `<title>` di `index.html` neutro.

### Cambiamenti di comportamento da conoscere
Le opzioni nuove sono tutte a default storico. Le correzioni qui sotto cambiano invece un comportamento, anche se solo nei casi che prima non funzionavano bene:
1. `Hide` su una colonna laterale è definitivo fino a `Show`: il ridimensionamento non la rimostra più su desktop.
2. `TIndexedDBHelper.GetRecord` è `function …: JSValue; async`: con `AWait` si usa come prima, chi chiamava `.then` sul risultato va rivisto.
3. `HtmlEncode` neutralizza anche l'apice singolo; `{{campo}}` dentro un attributo non converte più gli a-capo in `<br/>`.
4. `loadResource`/`isCSSLoaded`: lo stesso CSS non viene più aggiunto due volte; un foglio ancora in download risulta "non caricato".
5. `PageManager`: rotta iniziale non registrata → prima rotta; richieste del browser durante una navigazione eseguite dopo; hash allineato quando `OnValidatePage` reindirizza; nessuna voce di cronologia duplicata.
6. `WSManager`: `Close` emette `ws.disconnected`; `sendMessage` restituisce `False` a connessione non aperta.
7. `EventsManager`: le eccezioni dei listener sono scritte in console.
