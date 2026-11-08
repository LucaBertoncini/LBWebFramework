unit uLBWebUtils;
{$mode ObjFPC}
{$modeswitch externalclass}

interface

uses
  JS, Web;
  
type
  TJSGlobalThis = class external name 'globalThis'
    strict private
      FIndexedDB: TJSIDBFactory; external name 'indexedDB';
      FConsole: TJSConsole; external name 'console';
      FLocation: TJSLocation; external name 'location';
    public
      function fetch(resource: String; init: TJSObject): TJSPromise; overload; external name 'fetch';
      function fetch(resource: String): TJSResponse; async; overload; external name 'fetch';
      function fetch(resource: TJSObject; init: TJSObject): TJSPromise; overload; external name 'fetch';
      function fetch(resource: TJSObject): TJSPromise; overload; external name 'fetch';
      property Location: TJSLocation read FLocation;
      property IndexedDB: TJSIDBFactory read FIndexedDB;
      property Console: TJSConsole read FConsole;
  end;

  { TJSPOSTRequestAnswer }
  TJSPOSTRequestAnswer = class(TObject)
    NetworkErr : Boolean;
    NotExecuted : Boolean;
    // Corpo della risposta, gia' interpretato come JSON (solo per i 2xx).
    Answer : JSValue;
    // Corpo di una risposta HTTP di errore (4xx/5xx), se e' JSON valido: e'
    // li' che il server mette il messaggio d'errore. Answer non viene toccato.
    ErrorAnswer : JSValue;
    // Codice HTTP ricevuto; 0 se la richiesta non e' arrivata al server
    // (rete assente, richiesta non eseguita).
    HttpStatus : Integer;
    function ok(): Boolean;
    // True se il server ha risposto con un codice di errore (non e' un
    // problema di rete): distingue per esempio 401/403 da "offline".
    function HttpError(): Boolean;
  end;

  { TJSAsyncPOSTRequest }
  TJSAsyncPOSTRequest = class(TObject)
    strict private
      FURI : String;
    strict protected
      FData : TJSObject;
    public
      constructor Create; virtual;
      property URI: String write FURI;
      property Data: TJSObject write FData;
    published
      function execute: TJSPromise;
  end;

procedure FreeAndNilEx(var anObj: TObject);

// Escape HTML puro: neutralizza &, < e > (in questo ordine, cosi' & viene
// escapato una sola volta e mai dalle entita' introdotte dai due passi
// successivi). Non tocca gli a-capo: e' il mattone condiviso da TextToHTML
// (che aggiunge la conversione in <br/>) e da MarkdownLiteToHtml (che deve
// preservare i \n originali per la successiva suddivisione in righe) - vedi
// il commento di MarkdownLiteToHtml per il motivo per cui le due funzioni
// non possono condividere anche il passo di conversione degli a-capo.
function HtmlEncode(const aText: String): String;

// Escape HTML completo per testo semplice destinato a .innerHTML: applica
// HtmlEncode e converte gli a-capo (CRLF/LF/CR, tutte e tre le varianti) in
// <br/>. E' la funzione di riferimento del progetto per rendere sicuro un
// testo proveniente dall'utente prima di comporlo in un frammento HTML
// costruito a mano - va preferita a una qualunque funzione di escape locale
// o duplicata in una singola unit.
function TextToHTML(const aText: String): String;

function loadResource(anURL, aType: String; anId: String = ''): TJSPromise;
function isCSSLoaded(href: String): Boolean;
function getWSProtocol(): String;
function convertToIsoDate(const aDate: String): String;  // formato atteso dd/mm/yyyy  => yyyy-mm-dd

{ MarkdownLiteToHtml
  Utilita' generica (nessuna dipendenza da alcun progetto specifico):
  converte un sottoinsieme minimo e deliberato di Markdown in HTML -
  grassetto (**testo**, o ***testo*** insieme al corsivo), corsivo
  (*testo*), titoli (da "# " a "###### "), elenchi puntati (righe che
  iniziano con "- " o "* "), paragrafi separati da riga vuota. Non e' un
  parser Markdown completo (niente tabelle, link, codice inline/a
  blocco, citazioni): un parser completo sarebbe uno sforzo
  sproporzionato per il caso d'uso che ha motivato questa funzione (la
  risposta in linguaggio naturale di un modello AI), e introdurrebbe
  superficie inutile per bug su un testo tipicamente non fidato
  (proveniente da un servizio esterno).
  SICUREZZA: questa funzione applica HtmlEncode all'intero testo grezzo
  ricevuto, in Pascal, prima di qualunque riconoscimento Markdown - il
  chiamante non deve (e non dovrebbe) escapare il testo una seconda volta
  a monte: aRawText e' il testo originale, non ancora reso sicuro. Ogni
  carattere pericoloso (<, >, &) e' quindi gia' neutralizzato in entita'
  HTML quando le regole Markdown iniziano a operare, il che significa che
  nessuna sostituzione puo' mai reintrodurre markup eseguibile dal testo
  originale (verificato esplicitamente: un testo che contenesse
  letteralmente "<script>...</script>" scritto nel testo originale viene
  mostrato come testo innocuo tra parentesi angolari, mai interpretato
  dal browser). Il valore restituito e' quindi sicuro da assegnare
  direttamente a .innerHTML.
  NON usa TextToHTML per questo escape iniziale, pur trattandosi dello
  stesso identico problema: TextToHTML converte anche gli a-capo in
  <br/>, mentre questa funzione deve preservare i \n originali fino al
  passo successivo, che li usa per suddividere il testo in righe (var
  lines = escaped.split('\n') nel blocco asm sotto) - la suddivisione
  riga per riga e' cio' che permette di riconoscere titoli/elenchi/
  paragrafi separatamente. Le due funzioni condividono percio' solo il
  passo di escape vero e proprio (HtmlEncode), mai il passo successivo di
  conversione degli a-capo.
  IMPLEMENTATA IN JAVASCRIPT NATIVO (blocco asm) per la parte di
  riconoscimento Markdown, non in Pascal puro - scelta deliberata:
    - Il riconoscimento dei marcatori Markdown si presta naturalmente
      alle espressioni regolari, che il motore JavaScript del browser
      esegue in modo nativo e ottimizzato - una scansione manuale
      carattere per carattere in Pascal risulterebbe sia meno concisa
      sia, nel caso di ***testo*** (grassetto+corsivo combinati),
      soggetta a un bug di annidamento dei tag che una versione basata
      su espressioni regolari, opportunamente ordinata (il caso a tre
      asterischi gestito esplicitamente prima dei casi a due/uno),
      risolve direttamente.
    - RegExpr (l'unit Free Pascal nativa per le espressioni regolari) non
      e' usata: la pagina ufficiale del wiki Pas2JS, che elenca le unit
      RTL disponibili per la compilazione verso il browser, non la
      include - e' un'unit nativa per la compilazione a codice macchina,
      la cui disponibilita' in Pas2JS non e' garantita. Le espressioni
      regolari JavaScript native (RegExp, tramite String.replace nel
      blocco asm sotto) sono invece garantite disponibili in qualunque
      browser, essendo parte del linguaggio stesso su cui Pas2JS compila.
    - Ogni singola regola (titoli, elenco, grassetto+corsivo insieme,
      grassetto, corsivo) e' stata verificata con Node.js prima di essere
      trascritta qui.
  L'ORDINE DELLE TRE SOSTITUZIONI INLINE E' SIGNIFICATIVO: prima
  ***testo*** (grassetto+corsivo insieme), poi **testo** (solo
  grassetto), poi *testo* (solo corsivo) - processare prima il caso a tre
  asterischi evita che le sostituzioni di grassetto e corsivo, eseguite
  in sequenza sullo stesso testo, producano tag HTML annidati in modo
  scorretto per quel caso specifico (es. <strong><em>testo</strong></em>
  invece di <strong><em>testo</em></strong>). }
function MarkdownLiteToHtml(const aRawText: String): String;
var
  globalThis: TJSGlobalThis; external name 'globalThis';

implementation

uses
  strutils, SysUtils;

function getWSProtocol(): String;
begin
  if LowerCase(window.location.protocol) = 'https:' then
    Result := 'wss:'
  else
    Result := 'ws:';
end;

function convertToIsoDate(const aDate: String): String;
var
  _sep : String;
  _Items : TStringArray;
  _Day : Integer;
  _Month : Integer;
  _Year : Integer;
begin
  Result := '';
  if Length(aDate) = 10 then
  begin
    _sep := aDate[3];
    if _sep = aDate[6] then
    begin
      _Items := aDate.Split(_sep);
      _Day := StrToIntDef(_Items[0], 0);
      _Month := StrToIntDef(_Items[1], 0);
      _Year := StrToIntDef(_Items[2], 0);
      if ((_Day > 0) and (_Day <= 31)) and
         ((_Month > 0) and (_Month <= 12)) and
         (_Year > 0) then
      begin
        Result := _Items[2] + '-' + _Items[1] + '-' + _Items[0];
      end;
    end;
  end;
end;

function isCSSLoaded(href: String): Boolean;
{
  Il foglio di stile viene cercato fra i tag <link rel="stylesheet"> del
  documento, NON in document.styleSheets, per due motivi:
    1. document.styleSheets restituisce in .href sempre l'URL ASSOLUTO
       (es. http://host/css/login.css), mentre i chiamanti passano un URL
       relativo (es. 'css/login.css'): il confronto diretto non poteva mai
       riuscire e ogni apertura di pagina riaggiungeva lo stesso <link>.
       Qui entrambi i lati vengono risolti rispetto a document.baseURI
       prima del confronto, quindi vale qualunque forma dell'URL ricevuto.
    2. un foglio compare in document.styleSheets solo dopo che il browser
       lo ha scaricato, mentre il <link> esiste nel documento subito dopo
       appendChild (vedi loadResource).
  Restituisce True SOLO per un foglio gia' CARICATO (o presente nell'HTML
  statico). Un foglio il cui <link> esiste ma e' ancora in download da
  loadResource risulta False: chi poi chiama loadResource riceve la STESSA
  promessa in corso e la attende, invece di mostrare la pagina priva di
  stile credendo il foglio disponibile.
}
begin
  Result := False;
  asm
    var wanted = new URL(href, document.baseURI).href;
    var links = document.querySelectorAll('link[rel="stylesheet"]');
    for (var i = 0; i < links.length; i++) {
      if (links[i].href === wanted) {
        Result = !links[i].hasAttribute('data-lb-pending');
        break;
      }
    }
  end;
end;

function loadResource(anURL, aType: String; anId: String = ''): TJSPromise;
{
  Carica un foglio di stile ('css') o uno script ('js') e restituisce una
  promessa che si risolve con True/False. Richieste ripetute dello stesso
  URL condividono la stessa promessa: il file non viene mai aggiunto due
  volte, e chi arriva mentre e' ancora in download aspetta lo stesso esito.
  Un caricamento fallito non resta in cache: la richiesta successiva riprova.
}
begin
  asm
    var cache = (globalThis.__lbResourceCache = globalThis.__lbResourceCache || {});
    var key = aType + '|' + new URL(anURL, document.baseURI).href;
    if (cache[key]) {
      Result = cache[key];
    } else {
      Result = new Promise(function(resolve) {
        try {
          let element;
          if (aType === 'css') {
            // gia' presente nell'HTML statico o aggiunto da un'altra via?
            var wanted = new URL(anURL, document.baseURI).href;
            var existing = document.querySelectorAll('link[rel="stylesheet"]');
            for (var i = 0; i < existing.length; i++) {
              if (existing[i].href === wanted && !existing[i].hasAttribute('data-lb-pending')) {
                resolve(true);
                return;
              }
            }
            element = document.createElement('link');
            element.rel = 'stylesheet';
            element.href = anURL;
            element.setAttribute('data-lb-pending', '1');
            if (anId) element.id = anId;
            document.head.appendChild(element);
          } else if (aType === 'js') {
            element = document.createElement('script');
            element.src = anURL;
            document.body.appendChild(element);
          } else {
            resolve(false); // tipo non supportato
            return;
          }
          element.onload = function() { element.removeAttribute('data-lb-pending'); resolve(true); };
          element.onerror = function() {
            element.removeAttribute('data-lb-pending');
            delete cache[key];
            if (element.parentNode) element.parentNode.removeChild(element);
            resolve(false);
          };
        } catch (e) {
          console.error('Error loading ' + anURL + ': ', e);
          delete cache[key];
          resolve(false);
        }
      });
      cache[key] = Result;
    }
  end;
end;

function HtmlEncode(const aText: String): String;
begin
  Result := ReplaceStr(aText, '&', '&amp;');
  Result := ReplaceStr(Result, '<', '&lt;');
  Result := ReplaceStr(Result, '>', '&gt;');
  Result := ReplaceStr(Result, '"', '&quot;');
  // L'apice singolo va neutralizzato per i valori inseriti in attributi
  // delimitati da apici singoli (title='...'). Dentro innerHTML e' innocuo.
  Result := ReplaceStr(Result, '''', '&#39;');
end;

function TextToHTML(const aText: String): String;
begin
  Result := HtmlEncode(aText);
  Result := ReplaceStr(Result, #13#10, '<br/>');
  Result := ReplaceStr(Result, #10, '<br/>');
  Result := ReplaceStr(Result, #13, '<br/>');
end;

function MarkdownLiteToHtml(const aRawText: String): String;
{
  Vedi il commento esteso nella dichiarazione (sezione interface) per
  l'analisi completa: perche' l'escape iniziale usa HtmlEncode e non
  TextToHTML, perche' il riconoscimento Markdown e' implementato in
  JavaScript nativo invece che in Pascal puro, perche' RegExpr non e'
  usata, e perche' l'ordine delle tre sostituzioni inline (***testo***
  prima, poi **testo**, poi *testo*) e' cio' che evita un bug di
  annidamento dei tag.
  Ogni singola regola JavaScript scritta nel blocco asm sottostante e'
  stata verificata con Node.js, al di fuori di questo ambiente Pas2JS,
  prima di essere trascritta qui.
}
var
  _Escaped : String;
begin
  // Escape eseguito qui, in Pascal, PRIMA di entrare nel blocco asm: vedi
  // la nota estesa sopra sul perche' HtmlEncode (non TextToHTML) e' la
  // funzione corretta da usare in questo punto - deve lasciare intatti i
  // \n originali, che il blocco asm sotto usa per suddividere il testo
  // in righe.
  _Escaped := HtmlEncode(aRawText);
  asm
    // Formattazione inline (grassetto/corsivo), applicata dopo che una
    // riga e' gia' stata riconosciuta come titolo/voce di elenco/
    // paragrafo (vedi sotto) - opera quindi sempre su un frammento di
    // testo gia' escapato da HtmlEncode, mai sul testo grezzo originale.
    function inlineFormat(text) {
      // Ordine significativo - vedi la nota estesa in interface: il caso
      // combinato (tre asterischi, grassetto+corsivo insieme) deve
      // essere gestito esplicitamente prima dei casi singoli, altrimenti
      // le due sostituzioni successive (grassetto, poi corsivo)
      // producono tag annidati in modo scorretto per questo caso
      // specifico.
      text = text.replace(/\*\*\*(.+?)\*\*\*/g, '<strong><em>$1</em></strong>');
      text = text.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
      text = text.replace(/\*(.+?)\*/g, '<em>$1</em>');
      return text;
    }
    var lines = _Escaped.split('\n');
    var outLines = [];
    var inList = false;
    for (var i = 0; i < lines.length; i++) {
      var stripped = lines[i].trim();
      // Titolo: "# " fino a "###### " (livello massimo 6, coerente col
      // limite gia' verificato altrove nel progetto per l'estrazione
      // Markdown/DOCX strutturata).
      var headingMatch = stripped.match(/^(#{1,6})\s+(.*)$/);
      if (headingMatch) {
        if (inList) { outLines.push('</ul>'); inList = false; }
        var level = headingMatch[1].length;
        outLines.push('<h' + level + '>' + inlineFormat(headingMatch[2]) + '</h' + level + '>');
        continue;
      }
      // Elenco puntato: righe che iniziano con "- " o "* ".
      var listMatch = stripped.match(/^[-*]\s+(.*)$/);
      if (listMatch) {
        if (!inList) { outLines.push('<ul>'); inList = true; }
        outLines.push('<li>' + inlineFormat(listMatch[1]) + '</li>');
        continue;
      }
      if (inList) { outLines.push('</ul>'); inList = false; }
      if (stripped === '') {
        outLines.push('');
      } else {
        outLines.push('<p>' + inlineFormat(stripped) + '</p>');
      }
    }
    if (inList) outLines.push('</ul>');
    Result = outLines.join('\n');
  end;
end;

procedure FreeAndNilEx(var anObj: TObject);
begin
  if anObj <> nil then
  begin
    try
      anObj.Free;
    except
    end;
    anObj := nil;
  end;
end;

{ TJSPOSTRequestAnswer }
function TJSPOSTRequestAnswer.ok(): Boolean;
begin
  Result := (not NetworkErr) and (not NotExecuted);
end;

function TJSPOSTRequestAnswer.HttpError(): Boolean;
begin
  Result := (HttpStatus >= 400);
end;

{ TJSAsyncPOSTRequest }
constructor TJSAsyncPOSTRequest.Create;
begin
  inherited Create;
  FData := nil;
  FURI := '/';
end;

function TJSAsyncPOSTRequest.execute(): TJSPromise;
var
  _uriObj      : TJSURL;
  _absoluteURI : string;
  _Answer      : TJSPOSTRequestAnswer;
  _body        : string;
begin
  // 1) Prepara l'oggetto di risposta
  _Answer := TJSPOSTRequestAnswer.Create;
  _Answer.NetworkErr   := False;
  _Answer.NotExecuted  := True;
  _Answer.HttpStatus   := 0;
  // 2) Early-exit se manca URI o dati
  if (FData = nil) or (not hasValue(FURI)) or (FURI = '') then
  begin
    Result := TJSPromise.New(
      procedure(resolve, reject: TJSPromiseResolver)
      begin
        resolve(_Answer);
      end
    );
  end
  else begin
    // 3) Segno che la richiesta verra' eseguita
    _Answer.NotExecuted := False;
    _uriObj      := TJSURL.new(FURI, globalThis.Location.origin);
    _absoluteURI := _uriObj.href;
    _body        := TJSJSON.stringify(FData);
    // 4) Costruisco e restituisco la promise via XMLHttpRequest
    Result := TJSPromise.New(
      procedure(resolve, reject: TJSPromiseResolver)
      var
        xhr: TJSXMLHttpRequest;
      begin
        xhr := TJSXMLHttpRequest.new;
        xhr.open('POST', _absoluteURI, True);
        xhr.setRequestHeader('Content-Type', 'application/json');
        xhr.onload := function(aEvent : TJSProgressEvent): Boolean // procedure(evt: TJSEvent)
        begin
          _Answer.HttpStatus := xhr.status;
          // Successo HTTP?
          if (xhr.status >= 200) and (xhr.status < 300) then
          begin
            try
              _Answer.Answer := TJSJSON.parse(xhr.responseText);
            except
              _Answer.NetworkErr := True;
            end;
          end
          else
          begin
            // ok() e Answer restano come prima; il corpo dell'errore (di norma
            // JSON con il messaggio del server) va in ErrorAnswer.
            _Answer.NetworkErr := True;
            try
              if xhr.responseText <> '' then
                _Answer.ErrorAnswer := TJSJSON.parse(xhr.responseText);
            except
              // corpo non JSON (es. pagina d'errore del proxy): resta nil
            end;
          end;
          resolve(_Answer);
          Result := True;
        end;
        xhr.onerror := function(aEvent : TJSProgressEvent) : Boolean
        begin
          _Answer.NetworkErr := True;
          resolve(_Answer);
          Result := True;
        end;
        // INVIO payload JSON con Content-Length calcolato da XHR
        xhr.send(_body);
      end
    );
  end;
end;

end.
