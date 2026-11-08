unit InfiniteScroller;

{
  Componente condiviso: rende una lista di elementi a "blocchi" (chunk),
  caricando il chunk successivo quando l'utente scorre vicino al fondo
  del contenitore (vedi HandleScroll).

  BUGFIX (QUESTO AGGIORNAMENTO): PRIMO/UNICO CHUNK CHE NON RIEMPIE IL
  CONTENITORE - NESSUN ULTERIORE CHUNK VIENE MAI CARICATO
  ----------------------------------------------------------------------
  Segnalato con uno screenshot concreto (una pagina di ricerca): una
  ricerca restituiva 14 elementi, ma solo i primi 5 (un chunk,
  ItemsPerChunk=5) venivano mostrati - i restanti 9 restavano in memoria
  (il chiamante li ha gia' tutti, passati a LoadData/OnGetData) ma mai
  inseriti nel DOM.

  CAUSA REALE, verificata contro questo stesso file prima della
  correzione: RenderNextChunk viene invocata dall'esterno in due soli
  casi - (1) una volta sola da LoadData, per il primissimo chunk; (2) da
  HandleScroll, quando l'evento 'scroll' del CONTENITORE (non della
  finestra) si verifica vicino al fondo. Se il contenuto del primo
  (unico) chunk renderizzato NON supera l'altezza visibile del
  contenitore (es. .search-results, max-height:65vh;
  overflow-y:auto - un'altezza pensata apposta per generare uno scroll
  interno quando il contenuto e' sufficiente), il contenitore non ha
  ALCUNA barra di scorrimento: l'evento 'scroll' su di esso non si
  verifica mai, quindi HandleScroll non scatta mai, quindi nessun
  ulteriore chunk viene mai richiesto - anche se FOnGetData avrebbe
  potuto fornirne altri.

  Il difetto NON e' specifico di una pagina: lo stesso schema (un solo
  chunk iniziale via LoadData, tutti i chunk successivi affidati allo
  scroll dell'utente O a una notifica ESPLICITA e indipendente di
  "sono arrivati altri dati dalla rete" - il chiamante invoca
  LoadNextChunk quando una NUOVA pagina di risultati arriva dal server)
  puo' presentarsi in qualunque applicazione: dove esiste quella notifica
  esplicita funziona nella pratica
  solo perche' l'arrivo di una nuova pagina di rete e' un evento reale e
  distinto che giustifica una richiesta esplicita di continuazione - ma
  il PRIMISSIMO chunk (RefreshItems/LoadData) ha la stessa esposizione al
  difetto, se il primo blocco di risultati gia' noti non basta a
  riempire il contenitore.

  RISOLUZIONE, "solo quando necessario" (non un ciclo cieco fino alla
  fine dei dati)
  ----------------------------------------------------------------------
  Dopo aver renderizzato un chunk, RenderNextChunk verifica se il
  contenitore e' ancora "non scrollabile" (FContainer.scrollHeight <=
  FContainer.clientHeight - vera SOLO quando il contenuto attuale non
  basta a generare uno scroll reale, una lettura che il browser calcola
  correttamente anche subito dopo un appendChild sincrono, forzando il
  reflow necessario) E se restano altri elementi da mostrare
  (FRenderedItemCount < FTotalItemCount): se entrambe le condizioni sono
  vere, richiama SUBITO un altro chunk. La ricorsione si ferma da sola,
  senza alcun contatore o guardia aggiuntiva, non appena SI VERIFICA
  UNA delle due condizioni seguenti:

    - il contenitore comincia davvero a traboccare (scrollHeight supera
      clientHeight) - da quel momento in poi e' il normale HandleScroll,
      guidato dall'utente, a occuparsi della continuazione, esattamente
      come prima di questa correzione;
    - tutti gli elementi noti sono stati renderizzati
      (FRenderedItemCount = FTotalItemCount).

  Questo e' deliberatamente DIVERSO da un ciclo che renderizza sempre
  tutto fino alla fine: se il primo chunk gia' riempie/supera il
  contenitore, la ricorsione si ferma immediatamente al primo giro,
  esattamente come si comportava gia' prima di questa correzione in
  quel caso (nessuna regressione per le liste gia' abbastanza lunghe da
  generare uno scroll fin dal primo chunk).

  Il contenitore nascosto (display:none, clientHeight=scrollHeight=0)
  soddisfa la condizione (0 <= 0) e continuerebbe quindi a renderizzare
  ogni chunk restante fino a esaurimento dati: comportamento accettato
  deliberatamente (non e' un caso patologico, ne' un ciclo infinito - la
  ricorsione termina comunque quando FRenderedItemCount raggiunge
  FTotalItemCount), utile anzi se il contenitore verra' reso visibile
  in seguito senza un nuovo giro di scroll da parte dell'utente.

  Nessuna modifica alla firma pubblica del componente: LoadData/
  LoadNextChunk/HandleScroll restano invariati nel comportamento
  osservabile dall'esterno, solo RenderNextChunk continua ora
  automaticamente quando necessario, invece di fermarsi sempre dopo un
  solo chunk indipendentemente da quanto poco esso riempia il
  contenitore.

  IL MODELLO DEVE AVERE COME RADICE UN ELEMENTO AMMESSO DENTRO UN <div>
  ----------------------------------------------------------------------
  Ogni elemento viene costruito assegnando il markup reso all'innerHTML
  di un <div> temporaneo e prelevandone il primo elemento figlio
  (firstElementChild). Il parser HTML del browser SCARTA silenziosamente
  gli elementi che non possono essere figli diretti di un <div>: <tr>,
  <td>, <th>, <li>, <option>. Un modello che abbia uno di questi come
  radice non produce quindi alcun elemento, e l'elemento corrispondente
  semplicemente non compare - senza alcun errore, senza alcuna eccezione.

  Il sintomo e' una lista vuota (o incompleta) a fronte di dati
  perfettamente corretti, e la causa non e' deducibile da nulla di
  quanto si osserva. Per questo il componente la segnala in due punti:

    - checkTemplateRoot, invocata non appena il modello diventa
      disponibile (sia quello passato al costruttore, sia quello
      recuperato da file): l'avviso compare quindi PRIMA che arrivi un
      solo dato, tipicamente gia' all'apertura della pagina in fase di
      sviluppo;
    - RenderNextChunk, nel ramo in cui firstElementChild risulta nil:
      intercetta anche i casi che il controllo sulla radice non puo'
      prevedere (modello vuoto, oppure che produce solo testo o commenti
      per un particolare insieme di dati).

  Se servono colonne allineate, la radice deve essere un <div> con
  disposizione a griglia, mai un elemento di tabella.

  Le segnalazioni usano la console del browser (console.warn): in questo
  ambiente non esiste alcun registro applicativo equivalente a quello
  del lato server, e un avviso in console e' visibile a chi sviluppa
  senza interferire con il funzionamento per chi usa la pagina.
}

interface

uses
  Web, JS, SysUtils, TemplateEngine;

type
  // Callback function prototype used by the scroller to request data for a specific index.
  // The owner of the scroller is responsible for providing the actual TJSObject.
  TGetDataForIndexEvent = function(const aIndex: Integer): TJSObject of object;

  TGetRenderedItemsIndex = procedure (aStartIndex, anEndIndex: Integer) of object;

  { TInfiniteScroller }

  TInfiniteScroller = class(TObject)
  strict private
    FOnChunkRendered : TGetRenderedItemsIndex;

    // The scrollable container element.
    FContainer: TJSHTMLElement;
    // The HTML string template for a single item.
    FItemTemplate: string;
    FItemTemplatePath: String;
    // The total number of items in the dataset.
    FTotalItemCount: Integer;
    // How many items have been rendered into the DOM so far.
    FRenderedItemCount: Integer;
    // The number of items to render in each new chunk.
    FItemsPerChunk: Integer;
    // The callback function to get data.
    FOnGetData: TGetDataForIndexEvent;
    // The bound event handler for the scroll event.
//    FScrollHandler: TJSEventHandler;
    // A flag to prevent multiple load requests from firing at once.
    FLoading: Boolean;

    FScrollHandler : JSValue;

    // Verifica che la radice del modello sia un elemento che il browser
    // ammette come figlio di un <div> - si veda la nota "IL MODELLO DEVE
    // AVERE COME RADICE..." in testa alla unit. Non impedisce nulla e
    // non modifica il modello: si limita a segnalare in console, perche'
    // il difetto sarebbe altrimenti invisibile.
    procedure checkTemplateRoot();

    procedure HandleScroll(e: TJSEvent);
    procedure RenderNextChunk; async;
    function LoadTemplate(): Boolean; async;

  public
    constructor Create(aContainer: TJSHTMLElement; const anItemTemplate, anItemTemplatePath: string);
    destructor Destroy; override;

    // Main method to initialize the scroller with a dataset.
    procedure LoadData(aTotalCount: Integer; aOnGetData: TGetDataForIndexEvent);
    procedure LoadNextChunk(); async;

    // Clears the container and resets the state.
    procedure Clear;

    procedure setTotalItemsCount(aValue: Integer);

    property ItemTemplate: String write FItemTemplate;
    property ItemsPerChunk: Integer write FItemsPerChunk;
    property OnChunkRendered: TGetRenderedItemsIndex write FOnChunkRendered;
  end;

implementation

uses
  Math;

const
  // Elementi che il parser HTML non ammette come figli diretti di un
  // <div> e che quindi scarta silenziosamente. L'elenco non pretende di
  // essere esaustivo: raccoglie i casi che si incontrano davvero
  // scrivendo un modello di riga.
  cInvalidRootTags : array[0..4] of String = ('<tr', '<td', '<th', '<li', '<option');

  // Quanti caratteri del markup reso riportare nell'avviso: abbastanza
  // per riconoscere l'elemento radice, non tanti da rendere illeggibile
  // la console quando a fallire sono molti elementi.
  cWarnMarkupChars = Integer(120);

{ TInfiniteScroller }

constructor TInfiniteScroller.Create(aContainer: TJSHTMLElement; const anItemTemplate, anItemTemplatePath: string);
begin
  inherited Create;
  FContainer := aContainer;
  FItemTemplate := anItemTemplate;
  FItemTemplatePath := anItemTemplatePath;
  FItemsPerChunk := 20; // Default chunk size.
  FLoading := False;

  FScrollHandler := @Self.HandleScroll;

  // Bind the scroll handler so we can add/remove it correctly.
  FContainer.addEventListener('scroll', FScrollHandler);

  // Il modello puo' arrivare gia' qui, oppure piu' tardi da file: in
  // questo secondo caso la verifica avviene in LoadTemplate.
  if FItemTemplate <> '' then
    Self.checkTemplateRoot();
end;

destructor TInfiniteScroller.Destroy;
begin
  FContainer.removeEventListener('scroll', FScrollHandler);
  Self.Clear;
  inherited Destroy;
end;

procedure TInfiniteScroller.checkTemplateRoot();
var
  _t   : String;
  _Pos : Integer;
  i    : Integer;
begin
  _t := LowerCase(Trim(FItemTemplate));
  if _t = '' then Exit;

  // Un modello ben documentato comincia spesso con un commento che ne
  // spiega la struttura: senza scartarlo, il controllo guarderebbe il
  // commento invece del primo elemento reale e non segnalerebbe mai
  // nulla.
  _Pos := Pos('<!--', _t);
  while _Pos = 1 do
  begin
    _Pos := Pos('-->', _t);
    if _Pos = 0 then
      // Commento non chiuso: non c'e' modo di individuare l'inizio del
      // markup, e insistere significherebbe restare nel ciclo.
      Exit;

    _t := TrimLeft(Copy(_t, _Pos + 3, Length(_t)));
    _Pos := Pos('<!--', _t);
  end;

  for i := Low(cInvalidRootTags) to High(cInvalidRootTags) do
  begin
    if Pos(cInvalidRootTags[i], _t) = 1 then
    begin
      console.warn('TInfiniteScroller: il modello degli elementi ha come radice ' +
        cInvalidRootTags[i] + '>, che il browser non ammette come figlio di un <div> ' +
        'e scarta silenziosamente: nessun elemento verra'' reso. ' +
        'La radice del modello deve essere un <div> (con disposizione a griglia, ' +
        'se servono colonne allineate).');
      Exit;
    end;
  end;
end;

procedure TInfiniteScroller.Clear;
begin
  FContainer.innerHTML := '';
  FRenderedItemCount := 0;
  FTotalItemCount := 0;
  FOnGetData := nil;
  FLoading := False;
end;

procedure TInfiniteScroller.setTotalItemsCount(aValue: Integer);
begin
  FTotalItemCount := aValue;
end;

procedure TInfiniteScroller.LoadData(aTotalCount: Integer; aOnGetData: TGetDataForIndexEvent);
begin
  Clear;
  FTotalItemCount := aTotalCount;
  FOnGetData := aOnGetData;

  // Render the initial chunk of items. Se quel solo chunk non basta a
  // riempire il contenitore, RenderNextChunk stessa si occupa ora di
  // continuare automaticamente - vedi la nota "BUGFIX" in testa alla
  // unit.
  Self.RenderNextChunk;
end;

procedure TInfiniteScroller.LoadNextChunk();
begin
  if not FLoading and (FRenderedItemCount < FTotalItemCount) then
      Self.RenderNextChunk;
end;

procedure TInfiniteScroller.HandleScroll(e: TJSEvent);
begin
  // If we are already loading a chunk, or have rendered all items, do nothing.
  if FLoading or (FRenderedItemCount >= FTotalItemCount) then
    Exit;

  // Check if the user has scrolled close to the bottom of the container.
  // (scrollTop + clientHeight) is the position of the bottom of the visible area.
  // scrollHeight is the total height of the content.
  if (FContainer.scrollTop + FContainer.clientHeight) >= (FContainer.scrollHeight - 300) then // 300px threshold
    Self.RenderNextChunk;
end;

procedure TInfiniteScroller.RenderNextChunk;
var
  i: Integer;
  StopIndex: Integer;
  ItemData: TJSObject;
  RenderedHTML: string;
  Fragment: TJSNode;
  _TempDiv : TJSHTMLElement;
  _Loaded : Boolean;
begin
  if not Assigned(FOnGetData) then Exit;

  FLoading := True;
  try
    _Loaded := FItemTemplate <> '';
    if (not _Loaded) and (FItemTemplatePath <> '') then
      _Loaded := AWait(Boolean, Self.LoadTemplate());

    if not _Loaded then
      Exit;

    // Determine the range of items to render for this chunk.
    StopIndex := Min(FRenderedItemCount + FItemsPerChunk, FTotalItemCount);

    // Use a DocumentFragment for efficient bulk-appending to the DOM.
    Fragment := document.createDocumentFragment();

    for i := FRenderedItemCount to StopIndex - 1 do
    begin
      // Get the data for the current item via the callback.
      ItemData := FOnGetData(i);

      if ItemData <> nil then
      begin
        // Render the item template with the data.
        RenderedHTML := TemplateEngine.RenderTemplate(FItemTemplate, ItemData);

        // Create a temporary div to convert the HTML string into a DOM element.
        // This is safer than using innerHTML directly in the loop.
        _TempDiv := TJSHTMLElement(document.createElement('div'));
        _TempDiv.innerHTML := RenderedHTML;

        if _TempDiv.firstElementChild <> nil then
          Fragment.appendChild(_TempDiv.firstElementChild)
        else
          // Il markup reso non ha prodotto alcun elemento: l'elemento
          // corrente sparirebbe senza alcun segnale. Due cause
          // possibili, entrambe indicate nel messaggio perche' non
          // distinguibili da qui:
          //   - radice non ammessa dentro un <div> (il caso piu'
          //     frequente, gia' segnalato da checkTemplateRoot per il
          //     modello nel suo complesso);
          //   - modello che, per questo particolare insieme di dati,
          //     produce solo testo, spazi o commenti.
          // L'indice permette di distinguere un modello sbagliato (a
          // fallire sono tutti gli elementi) da un dato che rompe il
          // rendering (ne fallisce uno solo).
          console.warn('TInfiniteScroller: elemento ' + IntToStr(i) +
            ' non reso - il modello non ha prodotto alcun elemento radice valido. ' +
            'Verificare che la radice sia un <div> e non un elemento di tabella o di elenco. ' +
            'Inizio del markup reso: ' + Copy(Trim(RenderedHTML), 1, cWarnMarkupChars));
      end;
    end;

    // Append the entire chunk to the container in a single DOM operation.
    FContainer.appendChild(Fragment);

    if FOnChunkRendered <> nil then
      FOnChunkRendered(FRenderedItemCount, StopIndex - 1);

    // Update the count of rendered items.
    FRenderedItemCount := StopIndex;

  finally
    FLoading := False;
  end;

  {
    BUGFIX (vedi la nota estesa in testa alla unit): continua SUBITO con
    il chunk successivo SOLO se serve davvero, cioe' SOLO se ENTRAMBE le
    condizioni seguenti sono vere:

      1) restano altri elementi da mostrare (FRenderedItemCount <
         FTotalItemCount) - altrimenti non c'e' nulla da continuare;
      2) il contenitore, con quanto renderizzato FINORA, non e' ancora
         "scrollabile" (FContainer.scrollHeight <= FContainer.
         clientHeight) - se invece il contenuto gia' supera l'altezza
         visibile, il normale meccanismo di scroll (HandleScroll) e'
         gia' sufficiente e prende il sopravvento da qui in poi,
         esattamente come PRIMA di questa correzione.

    Lettura di scrollHeight/clientHeight DOPO l'appendChild sincrono
    sopra: il browser ricalcola il layout necessario per fornire questi
    due valori (reflow sincrono indotto dalla lettura stessa), quindi
    riflettono gia' il contenuto appena inserito, non quello di prima.

    Questo NON e' un ciclo cieco fino alla fine dei dati: si ferma da
    solo al primo giro in cui una delle due condizioni sopra diventa
    falsa - per una lista che gia' al primo chunk supera l'altezza del
    contenitore, il comportamento resta IDENTICO a prima di questa
    correzione (un solo chunk, poi lo scroll dell'utente).

    NOTA sul caso in cui NESSUN elemento del chunk venga reso (modello
    con radice non valida): FRenderedItemCount avanza comunque fino a
    StopIndex, quindi la ricorsione consuma i chunk restanti e termina
    regolarmente invece di ripetersi all'infinito su un contenitore che
    resta vuoto. Ogni elemento non reso ha gia' prodotto il proprio
    avviso in console.
  }
  if (FRenderedItemCount < FTotalItemCount) and (FContainer.scrollHeight <= FContainer.clientHeight) then
    Self.RenderNextChunk;
end;

function TInfiniteScroller.LoadTemplate: Boolean;
var
  _Response : TJSResponse;
begin
  Result := False;

  if FItemTemplatePath <> '' then
  begin
    _Response := AWait(TJSResponse, window.fetch(FItemTemplatePath));
    if _Response.ok then
    begin
      FItemTemplate := AWait(String, _Response.text());
      Result := True;

      // Il modello e' appena diventato disponibile: la verifica avviene
      // qui, prima che venga reso anche un solo elemento.
      Self.checkTemplateRoot();
    end
    else
      // Senza modello non verra' reso nulla, e il chiamante non riceve
      // alcun segnale: il recupero fallito va dichiarato.
      console.warn('TInfiniteScroller: impossibile recuperare il modello degli elementi da <' +
        FItemTemplatePath + '> (codice ' + IntToStr(_Response.status) + '). Nessun elemento verra'' reso.');

    FItemTemplatePath := '';
  end;
end;

end.
