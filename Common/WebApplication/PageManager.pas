unit PageManager;

{
  LOGICA DI FUNZIONAMENTO
  ======================================================================
  Questa unit e' il gestore della navigazione: l'applicazione vive in un
  unico documento, e cambiare pagina significa sostituire il contenuto di
  un solo contenitore invece di chiedere al server un documento diverso.
  Cio' che cambia nell'indirizzo del browser e' la sola parte dopo il
  cancelletto, che il gestore usa come nome della pagina da mostrare.

  1. REGISTRAZIONE DELLE ROTTE
  ----------------------------------------------------------------------
  Prima che qualunque navigazione possa avvenire, l'applicazione dichiara
  quali rotte esistono e quale classe serve ciascuna (RegisterForm). Una
  rotta e' una stringa scelta liberamente: non deve corrispondere ad
  alcun percorso reale sul disco, perche' dove si trovi il template e'
  stabilito separatamente (si veda il punto 4).

  Una stessa rotta puo' essere registrata PIU' VOLTE, con classi diverse
  e requisiti di dimensione diversi: e' cosi' che si ottengono varianti
  della medesima pagina per schermi differenti. La scelta fra esse
  avviene ad ogni navigazione, non una volta per tutte (punto 5).

  2. AVVIO
  ----------------------------------------------------------------------
  StartRouting decide quale pagina mostrare per prima guardando
  l'indirizzo con cui l'applicazione e' stata aperta:

    - se contiene gia' un nome di pagina, e' quello che si carica, e non
      si aggiunge alcuna voce alla cronologia del browser: quella voce
      esiste gia', ed aggiungerne una seconda identica costringerebbe a
      premere due volte il tasto "indietro" per uscire;

    - se non lo contiene, si usa la PRIMA rotta registrata, e in questo
      caso la voce di cronologia va creata perche' non esiste ancora.

  Ne discende che l'ORDINE delle registrazioni conta: la prima e' la
  pagina predefinita dell'applicazione.

  3. TRE MODI DI NAVIGARE, UN SOLO PUNTO DI PASSAGGIO
  ----------------------------------------------------------------------
  Una pagina puo' essere richiesta in tre modi diversi:

    NavigateTo        richiesta esplicita dal codice applicativo
    HandlePopState    tasti avanti/indietro del browser
    StartRouting      apertura iniziale

  Tutti e tre convergono su LoadPage, che e' quindi l'unico punto
  attraverso cui passa ogni cambio di pagina. E' il motivo per cui una
  notifica agganciata li' (si veda OnPageLoaded piu' sotto) copre
  automaticamente tutti i casi, compresi quelli che non passano da alcun
  codice applicativo.

  La differenza fra i tre sta solo nella cronologia: NavigateTo vi
  aggiunge una voce, gli altri due no, perche' in quei casi la voce
  esiste gia' - e' anzi proprio da essa che la richiesta proviene.

  4. LA SEQUENZA DI CARICAMENTO DI UNA PAGINA
  ----------------------------------------------------------------------
  LoadPage procede in quest'ordine:

    a) verifica che non ci sia gia' una navigazione in corso (punto 7);

    b) sottopone la rotta richiesta a OnValidatePage, che puo'
       TRASFORMARLA: un utente non autenticato che chieda una pagina
       riservata riceve invece quella di accesso. Da qui in avanti si
       lavora sulla rotta trasformata, mai su quella richiesta;

    c) sceglie la registrazione piu' adatta allo schermo (punto 5);

    d) determina dove si trova il template, con tre livelli di
       precedenza: il percorso imposto dalla pagina stessa
       (getTemplatePath), altrimenti il file dichiarato al momento della
       registrazione, altrimenti la convenzione "pages/<rotta>.html" -
       gli ultimi due relativi alla cartella radice dell'applicativo;

    e) chiede alla pagina di caricare i propri fogli di stile;

    f) recupera il template dal server.

  Solo se il recupero RIESCE si procede a sostituire cio' che e' a
  schermo: la pagina precedente viene liberata, il nuovo markup
  iniettato nel contenitore, l'istanza della pagina costruita, la
  cartella radice assegnata, e infine BindUI invocata.

  Questo ordine non e' casuale. Il markup viene iniettato PRIMA della
  costruzione perche' BindUI, che viene dopo, risolve i propri elementi
  cercandoli in cio' che e' gia' presente. E la pagina precedente viene
  rimossa DOPO il recupero, non prima: se il template non si trova, a
  schermo resta quella di prima invece di un contenitore vuoto.

  Al termine, se richiesto, si aggiunge la voce di cronologia e si
  notifica il cambio di pagina avvenuto.

  NOTA: l'esito del caricamento dei fogli di stile viene raccolto ma non
  verificato - una pagina il cui foglio non si carichi viene mostrata
  ugualmente, priva di stile. E' deliberato: non tutte le pagine hanno
  un foglio proprio, e un foglio assente non deve impedire di vedere il
  contenuto.

  5. SCELTA FRA PIU' REGISTRAZIONI DELLA STESSA ROTTA
  ----------------------------------------------------------------------
  Ogni registrazione puo' dichiarare una larghezza e un'altezza minime.
  GetBestRegistration divide allora le registrazioni di una rotta in due
  insiemi:

    - quella che non dichiara alcun minimo (entrambi a zero) e' la
      variante PREDEFINITA, valida per qualunque schermo;

    - le altre sono candidate solo se lo schermo soddisfa ENTRAMBI i
      loro minimi.

  Fra le candidate vince quella con la larghezza minima piu' alta, cioe'
  la piu' specifica fra quelle compatibili. Se nessuna e' compatibile si
  ricade sulla predefinita; se non esiste nemmeno quella, la navigazione
  non avviene e resta a schermo la pagina corrente.

  La valutazione avviene ad OGNI navigazione: la stessa rotta puo'
  quindi mostrare una variante diversa dopo un ridimensionamento della
  finestra.

  6. LA PAGINA CORRENTE E' POSSEDUTA DAL GESTORE
  ----------------------------------------------------------------------
  Esiste una sola pagina viva per volta, e la sua liberazione non e'
  responsabilita' di chi l'ha richiesta: ClearCurrentForm la distrugge e
  svuota il contenitore, sia quando se ne carica un'altra sia quando il
  gestore stesso viene distrutto. Una pagina non deve percio' essere
  liberata dall'esterno.

  7. UNA NAVIGAZIONE PER VOLTA
  ----------------------------------------------------------------------
  Il caricamento comporta due attese (i fogli di stile e il template):
  in quell'intervallo l'applicazione continua a rispondere, e una
  seconda navigazione potrebbe partire prima che la prima sia conclusa.
  Le due si intreccerebbero, e l'istanza costruita dalla prima si
  troverebbe davanti il markup iniettato dalla seconda.

  Un indicatore impedisce che accada: finche' un caricamento e' in
  corso, ogni altra richiesta viene IGNORATA. Non accodata, ignorata -
  chi chiede una pagina mentre un'altra sta arrivando non la ottiene, e
  deve chiederla di nuovo. E' una scelta deliberata: accodarla
  significherebbe mostrare comunque, di li' a poco, una pagina che
  l'utente ha smesso di volere.

  ======================================================================


  AGGIORNAMENTO (titolo di sezione nell'header): aggiunto l'evento
  OnPageLoaded, invocato da LoadPage subito dopo che una pagina e' stata
  caricata e agganciata con successo (BindUI gia' eseguita, history gia'
  aggiornata se richiesto). E' il punto giusto per notificare "la
  rotta effettivamente mostrata e' cambiata" perche' LoadPage e' l'UNICO
  punto attraverso cui passa ogni navigazione di questa applicazione: sia
  quella esplicita (NavigateTo), sia quella implicita del browser
  (HandlePopState, avanti/indietro), sia il caricamento iniziale
  (StartRouting) - agganciarsi qui, invece che ripetere una chiamata in
  ciascun metodo "gotoXxx" del chiamante (la classe derivata da TWebApplication),
  copre automaticamente tutti e tre i casi con un solo punto di codice,
  ed e' inoltre a prova di futuri metodi di navigazione aggiunti piu'
  avanti (continuerebbero comunque a passare da qui).
  aRoute passato a OnPageLoaded e' la rotta EFFETTIVA dopo l'eventuale
  trasformazione di OnValidatePage (es. un utente non loggato che chiede
  'items' riceve invece 'login'): il chiamante dell'evento riceve quindi
  sempre la rotta della pagina REALMENTE mostrata, mai quella
  originariamente richiesta.
  Non invocato in caso di errore (form non trovato, fetch del template
  fallito): in quei casi la pagina precedente resta a schermo (o nessuna,
  al primissimo avvio), quindi non ha senso notificare un cambio di
  sezione che non e' avvenuto.


  AGGIORNAMENTO (piu' applicativi nella stessa pagina): LA REGISTRAZIONE
  DI UNA ROTTA PUO' ORA DICHIARARE IL FILE DEL TEMPLATE E LA CARTELLA
  RADICE DELL'APPLICATIVO
  ----------------------------------------------------------------------
  Un unico server puo' ospitare piu' applicativi distinti, che
  condividono autenticazione, utenti e permessi ma hanno pagine, fogli
  di stile e risorse proprie. La disposizione naturale dei file diventa
  allora questa:

      html/
        index.html
        pages/            pagine comuni (accesso, selettore, errori)
        css/
        app2/
          pages/
          css/
        app1/
          pages/
          css/

  Il percorso del template era pero' costruito con un prefisso fisso
  ('pages/' + rotta + '.html'), quindi ogni pagina sarebbe stata cercata
  nella sola cartella comune, indipendentemente dall'applicativo di
  appartenenza.

  RegisterForm accetta percio' due parametri facoltativi in coda:

      aHtmlFile   il file del template, relativo alla cartella radice
                  dell'applicativo. Se omesso vale la convenzione
                  'pages/<rotta>.html', come prima.

      aBasePath   la cartella radice dell'applicativo a cui la pagina
                  appartiene ('app1/', 'app2/'). Se omessa la pagina vive
                  nella radice, ed e' esattamente il comportamento
                  precedente a questo aggiornamento.

  Entrambi sono in CODA e hanno un valore predefinito: ogni chiamata a
  RegisterForm gia' scritta continua quindi a compilare senza alcuna
  modifica, e si comporta esattamente come prima.

  IL CASO SENZA APPLICATIVO NON E' UN'ECCEZIONE DA GESTIRE
  ----------------------------------------------------------------------
  Una cartella radice vuota, concatenata, produce letteralmente le
  stesse stringhe di prima:

      ''     + 'pages/login.html'     ->  'pages/login.html'
      'app1/' + 'pages/reports.html'  ->  'app1/pages/reports.html'

  Non esiste quindi alcun ramo dedicato alla compatibilita': e' la
  stessa espressione, con un prefisso che per le pagine nella radice e'
  vuoto.

  LA CARTELLA RADICE ARRIVA ANCHE ALLA PAGINA, E QUESTO E' IL PUNTO
  ----------------------------------------------------------------------
  Il percorso del template puo' essere dichiarato qui, ma quello dei
  fogli di stile vive dentro loadNeededCSS, che senza alcun parametro
  non avrebbe modo di sapere dove si trovi la propria pagina. La
  conseguenza sarebbe un'asimmetria fastidiosa: rinominando la cartella
  di un applicativo il template seguirebbe, i fogli di stile no - e in
  modo silenzioso, perche' la pagina si caricherebbe ugualmente, solo
  senza stile.

  LoadPage passa percio' la cartella radice a loadNeededCSS, e la
  assegna inoltre alla proprieta' BasePath dell'istanza, che serve per
  le risorse recuperate dalla pagina stessa dopo la costruzione
  (tipicamente i template ausiliari: il modello di una singola riga di
  un elenco). Si veda la nota estesa su TBaseForm in WebComponent.pas.

  PERCHE' UNA PROPRIETA' "cartella corrente" SUL GESTORE NON ANDREBBE
  BENE: sarebbe uno stato globale da cambiare a ogni passaggio da un
  applicativo all'altro, e basterebbe dimenticarne un aggiornamento - o
  una navigazione tramite i pulsanti del browser, che non passa da
  alcun codice applicativo - perche' una pagina cercasse le proprie
  risorse nella cartella sbagliata. Legando invece la cartella alla
  singola registrazione, la corrispondenza e' garantita per costruzione
  e non esiste alcuno stato da mantenere allineato.
}

interface

uses
  Web, JS, SysUtils, WebComponent;

const
  // Cartella dei template dentro la radice di un applicativo (o nella
  // radice del sito, per le pagine comuni).
  cPageManager_PagesFolder = 'pages/';

  cPageManager_TemplateExt = '.html';

type
  TOnValidatePageEvent = reference to function(aPage: String): String; safecall;

  // NUOVO
  TOnPageLoadedEvent = reference to procedure(aRoute: String); safecall;

  { TPageManager }

  TPageManager = class(TObject)
  strict private
    FOnValidatePage : TOnValidatePageEvent;
    FOnPageLoaded   : TOnPageLoadedEvent; // NUOVO

    FContainer: TJSHTMLElement;
    FFormRegistrations: TJSMap;
    FCurrentForm: TBaseForm;
    FIsNavigating : Boolean;

    // Richiesta del browser (avanti/indietro) arrivata MENTRE un'altra
    // navigazione era in corso. A differenza di NavigateTo, qui la voce di
    // cronologia e' gia' cambiata: ignorare la richiesta lascerebbe l'URL
    // su una pagina e lo schermo su un'altra. Si ricorda solo l'ULTIMA e la
    // si esegue appena la navigazione corrente finisce.
    FPendingPopRoute : String;
    // True solo per il caricamento iniziale (StartRouting): abilita il
    // ripiego sulla prima rotta se quella dell'indirizzo non esiste.
    FInitialLoad : Boolean;

    function FirstRegisteredRoute: String;
    function HandlePopState(event: TJSPopStateEvent): Boolean;
    procedure LoadPage(aRoute: String; aPushState: Boolean = True); async;
    procedure ClearCurrentForm;

    { Restituisce l'INTERA registrazione scelta per la rotta, non la sola
      classe: servono anche il file del template e la cartella radice,
      dichiarati insieme ad essa. La logica di scelta fra piu'
      registrazioni della stessa rotta (quella per dimensione dello
      schermo) e' rimasta identica. }
    function GetBestRegistration(aRoute: String): TJSObject;

  public
    constructor Create(aContainer: TJSHTMLElement);
    destructor Destroy; override;

    { aHtmlFile e aBasePath sono facoltativi e in coda: ogni chiamata
      gia' scritta continua a compilare e si comporta come prima.

        aHtmlFile   file del template, RELATIVO ad aBasePath. Omesso:
                    vale 'pages/<rotta>.html'.
        aBasePath   cartella radice dell'applicativo ('app1/', 'app2/').
                    Omessa: la pagina vive nella radice del sito.

      La barra finale di aBasePath viene aggiunta qui se manca, cosi'
      'app1' e 'app1/' sono equivalenti e chi registra una rotta non deve
      ricordarsi la convenzione. }
    procedure RegisterForm(aRoute: string; aFormClass: TBaseFormClass; aMinWidth: NativeInt = 0; aMinHeight: NativeInt = 0; const aHtmlFile: String = ''; const aBasePath: String = '');

    procedure NavigateTo(aRoute: string);
    procedure StartRouting;

    procedure Back();

    property CurrentForm: TBaseForm read FCurrentForm;

    property OnValidatePage: TOnValidatePageEvent write FOnValidatePage;
    // NUOVO: write-only, stesso stile di OnValidatePage sopra - il
    // chiamante (la classe derivata da TWebApplication) assegna un handler, non legge mai
    // indietro il valore assegnato.
    property OnPageLoaded: TOnPageLoadedEvent write FOnPageLoaded;
  end;


implementation

{ TPageManager }

constructor TPageManager.Create(aContainer: TJSHTMLElement);
begin
  inherited Create;
  FIsNavigating := False;
  FPendingPopRoute := '';
  FInitialLoad := False;
  FContainer := aContainer;
  FFormRegistrations := TJSMap.new;
  FCurrentForm := nil;

  window.onpopstate := @Self.HandlePopState;
end;

destructor TPageManager.Destroy;
begin
  Self.ClearCurrentForm;
  FFormRegistrations := nil;
  window.onpopstate := nil;
  inherited Destroy;
end;

procedure TPageManager.RegisterForm(aRoute: string; aFormClass: TBaseFormClass; aMinWidth: NativeInt; aMinHeight: NativeInt; const aHtmlFile: String; const aBasePath: String);
var
  regList: TJSArray;
  reg: TJSObject;
  _Base: String;

begin
  if not FFormRegistrations.has(aRoute) then
  begin
    regList := TJSArray.new;
    FFormRegistrations.&set(aRoute, regList);
  end
  else
    regList := TJSArray(FFormRegistrations.get(aRoute));

  // La barra finale e' cio' che rende corretta ogni concatenazione
  // successiva: senza, 'app1' + 'pages/x.html' produrrebbe
  // 'app1pages/x.html'. Viene aggiunta qui una volta sola, invece di
  // pretenderla da chi registra la rotta.
  _Base := Trim(aBasePath);
  if (_Base <> '') and (_Base[Length(_Base)] <> '/') then
    _Base := _Base + '/';

  reg := TJSObject.new;
  reg['FormClass'] := aFormClass;
  reg['MinWidth'] := aMinWidth;
  reg['MinHeight'] := aMinHeight;
  reg['HtmlFile'] := Trim(aHtmlFile);
  reg['BasePath'] := _Base;

  regList.push(reg);
end;

function TPageManager.GetBestRegistration(aRoute: String): TJSObject;
var
  regList, validForms: TJSArray;
  i: Integer;
  reg, bestFit, defaultFit: TJSObject;
  screenWidth, screenHeight: NativeInt;
begin
  Result := nil;
  bestFit := nil;
  defaultFit := nil;

  if not FFormRegistrations.has(aRoute) then
    exit;

  regList := TJSArray(FFormRegistrations.get(aRoute));
  screenWidth := window.innerWidth;
  screenHeight := window.innerHeight;

  validForms := TJSArray.new;

  for i := 0 to regList.length - 1 do
  begin
    reg := TJSObject(regList[i]);
    if (Integer(reg['MinWidth']) = 0) and (Integer(reg['MinHeight']) = 0) then
      defaultFit := reg
    else if (screenWidth >= Integer(reg['MinWidth'])) and (screenHeight >= Integer(reg['MinHeight'])) then
      validForms.push(reg);
  end;

  if validForms.length > 0 then
  begin
    bestFit := TJSObject(validForms[0]);
    for i := 1 to validForms.length - 1 do
    begin
      reg := TJSObject(validForms[i]);
      if Integer(reg['MinWidth']) > Integer(bestFit['MinWidth']) then
        bestFit := reg;
    end;
  end;

  // Restituisce l'intera registrazione: il chiamante ne estrae la
  // classe, il file del template e la cartella radice.
  if hasValue(bestFit) then
    Result := bestFit
  else if hasValue(defaultFit) then
    Result := defaultFit;
end;

procedure TPageManager.NavigateTo(aRoute: string);
begin
  Self.LoadPage(aRoute, True);
end;

procedure TPageManager.ClearCurrentForm;
begin
  if FCurrentForm <> nil then
  begin
    FCurrentForm.Free;
    FCurrentForm := nil;
  end;
  FContainer.innerHTML := '';
end;

function TPageManager.HandlePopState(event: TJSPopStateEvent): Boolean;
var
  _Route: String;
begin
  Result := False;

  if event.state <> nil then
  begin
    _Route := String(TJSObject(event.state).Properties['page']);
    if _Route <> '' then
    begin
      Self.LoadPage(_Route, False);
      Result := True;
    end;
  end
  else begin
    _Route := window.location.hash.substring(1);
    if _Route <> '' then
    begin
      Self.LoadPage(_Route, False);
      Result := True;
    end;
  end;
end;

procedure TPageManager.LoadPage(aRoute: String; aPushState: Boolean); async;
var
  _Registration: TJSObject;
  _FormClass: TBaseFormClass;
  _TemplatePath: String;
  _BasePath: String;
  _HtmlFile: String;
  _Response: TJSResponse;
  _HTML: String;
  _State: TJSObject;
//  rootElement: TJSHTMLElement;
  _Loaded : Boolean;
  _Requested : String;
  _Initial : Boolean;
  _Fallback : String;
begin
  _Initial := FInitialLoad;
  FInitialLoad := False;

  if FIsNavigating then
  begin
    // Vedi FPendingPopRoute: solo le richieste del browser vanno ricordate.
    if not aPushState then
      FPendingPopRoute := aRoute;
    Exit;
  end;

  FIsNavigating := True;
  try
    _Requested := aRoute;
    if hasValue(FOnValidatePage) then
      aRoute := FOnValidatePage(aRoute);

    _Registration := Self.GetBestRegistration(aRoute);

    // Indirizzo di apertura con una rotta inesistente (refuso, vecchio
    // segnalibro): invece di lasciare la pagina bianca si ripiega sulla
    // prima rotta registrata, come se l'indirizzo non ne contenesse alcuna.
    if (_Registration = nil) and _Initial then
    begin
      _Fallback := Self.FirstRegisteredRoute;
      if (_Fallback <> '') and (_Fallback <> aRoute) then
      begin
        console.warn('Route "' + aRoute + '" non registrata: uso "' + _Fallback + '"');
        aRoute := _Fallback;
        _Requested := aRoute;
        if hasValue(FOnValidatePage) then
          aRoute := FOnValidatePage(aRoute);
        _Registration := Self.GetBestRegistration(aRoute);
        // L'hash nell'indirizzo e' sbagliato: va sostituito, non aggiunto.
        aPushState := False;
        _State := TJSObject.new;
        _State.Properties['page'] := aRoute;
        window.history.replaceState(_State, aRoute, '#' + aRoute);
      end;
    end;

    if _Registration = nil then
    begin
      console.warn('Error: No suitable form found for route: ', aRoute);
      Exit;
    end;

    _FormClass := TBaseFormClass(_Registration['FormClass']);
    _BasePath  := String(_Registration['BasePath']);
    _HtmlFile  := String(_Registration['HtmlFile']);

    try
      _TemplatePath := _FormClass.getTemplatePath;
    except
      on E: Exception do
      begin
        _TemplatePath := '';
        console.error(E.Message);
      end;
    end;

    // Ordine di precedenza nel determinare il template:
    //   1) getTemplatePath, se la pagina ne impone uno: e' un percorso
    //      COMPLETO, la cartella radice non vi viene anteposta - chi lo
    //      ridefinisce vuole il controllo totale;
    //   2) il file dichiarato al momento della registrazione, RELATIVO
    //      alla cartella radice;
    //   3) la convenzione 'pages/<rotta>.html' dentro la cartella
    //      radice.
    // Con una cartella radice vuota, il terzo caso produce esattamente
    // la stessa stringa costruita prima di questo aggiornamento.
    if _TemplatePath = '' then
    begin
      if _HtmlFile <> '' then
        _TemplatePath := _BasePath + _HtmlFile
      else
        _TemplatePath := _BasePath + cPageManager_PagesFolder + aRoute + cPageManager_TemplateExt;
    end;

    try
      // La cartella radice arriva alla pagina: e' cio' che le permette
      // di comporre i percorsi dei propri fogli di stile senza
      // scriverli per esteso - si veda la nota in testa alla unit.
      _Loaded := AWait(Boolean, _FormClass.loadNeededCSS(_BasePath));
      _Response := AWait(TJSResponse, window.fetch(_TemplatePath));
      if _Response.ok then
      begin
        _HTML := AWait(String, _Response.text());

        Self.ClearCurrentForm;
        FContainer.innerHTML := _HTML;

        FCurrentForm := _FormClass.Create(FContainer);

        // Assegnata PRIMA di BindUI: una pagina puo' averne bisogno
        // gia' li', per recuperare i propri template ausiliari.
        FCurrentForm.BasePath := _BasePath;

        // Il template e' gia' stato iniettato in FContainer (riga sopra)
        // PRIMA della Create: il markup e' quindi gia' presente e corretto.
        // BindUI non viene piu' chiamata automaticamente dal costruttore
        // di TWebComponent (vedi WebComponent.pas), quindi va invocata qui
        // esplicitamente, subito dopo la creazione dell'istanza.
        FCurrentForm.BindUI;

        if aPushState then
        begin
          _State := TJSObject.new;
          _State.Properties['page'] := aRoute;
          // Navigare verso la rotta GIA' mostrata nell'indirizzo ricarica la
          // pagina ma non deve aggiungere una voce uguale alla precedente
          // (costringerebbe a premere due volte "indietro").
          if window.location.hash.substring(1) = aRoute then
            window.history.replaceState(_State, aRoute, '#' + aRoute)
          else
            window.history.pushState(_State, aRoute, '#' + aRoute);
        end
        else if aRoute <> _Requested then
        begin
          // Richiesta del browser (indietro/avanti o apertura) trasformata
          // da OnValidatePage (es. pagina riservata -> accesso): l'indirizzo
          // deve mostrare la pagina REALE, non quella richiesta.
          _State := TJSObject.new;
          _State.Properties['page'] := aRoute;
          window.history.replaceState(_State, aRoute, '#' + aRoute);
        end;

        // NUOVO: notifica il cambio di pagina AVVENUTO CON SUCCESSO, con
        // la rotta EFFETTIVA (gia' passata per FOnValidatePage sopra) -
        // vedi il commento in testa alla unit per il perche' di questo
        // punto d'aggancio.
        if hasValue(FOnPageLoaded) then
          FOnPageLoaded(aRoute);
      end
      else
        // Il percorso effettivamente tentato viene riportato accanto
        // alla rotta: con piu' applicativi la causa piu' frequente di
        // un template non trovato e' una pagina collocata in una
        // cartella diversa da quella dichiarata, e senza vedere il
        // percorso non sarebbe riconoscibile.
        console.warn('Could not load template for route: ' + aRoute + ' (percorso: ' + _TemplatePath + ')');
    except
      on E: Exception do
        console.error('Fetch error for route ' + aRoute + ': ' + E.Message);
    end;

  finally
    FIsNavigating := False;

    // Una richiesta del browser arrivata durante questa navigazione viene
    // eseguita ora (solo l'ultima). Sta nel finally, e non dopo, perche'
    // un Exit nel corpo salterebbe qualunque codice successivo.
    if FPendingPopRoute <> '' then
    begin
      _Requested := FPendingPopRoute;
      FPendingPopRoute := '';
      Self.LoadPage(_Requested, False);
    end;
  end;
end;

function TPageManager.FirstRegisteredRoute: String;
var
  _Iter: TJSIterator;
  _Entry: TJSIteratorValue;
begin
  Result := '';
  _Iter := FFormRegistrations.keys();
  _Entry := _Iter.next;
  if not _Entry.done then
    Result := String(_Entry.value);
end;

procedure TPageManager.StartRouting;
var
  _InitialRoute: String;
  _PushState: Boolean;
begin
  _InitialRoute := window.location.hash.substring(1);

  if _InitialRoute <> '' then
  begin
    // L'hash e' gia' nell'URL: la voce di history esiste gia'.
    // Carichiamo la pagina senza aggiungere un duplicato.
    _PushState := False;
  end
  else begin
    // Nessun hash: prendiamo la prima route registrata come default.
    // In questo caso la voce di history NON esiste ancora -> va creata.
    _InitialRoute := Self.FirstRegisteredRoute;
    _PushState := True;
  end;

  if _InitialRoute <> '' then
  begin
    FInitialLoad := True;
    Self.LoadPage(_InitialRoute, _PushState);
  end;
end;

procedure TPageManager.Back();
begin
  window.history.back;
end;

end.
