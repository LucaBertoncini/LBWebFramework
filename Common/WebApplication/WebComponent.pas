unit WebComponent;

interface

uses
  Web, JS;

type

  TWebComponent = class;
  TUIElementWrapper = class;

  TUIElementClickEventHandler = reference to function(aSender: TUIElementWrapper; aEvent : TJSMouseEvent) : boolean; safecall;

  { TUIElementWrapper }

  TUIElementWrapper = class(TObject)
  strict private
    FOnClickEvent : TUIElementClickEventHandler;

    FId: String;
    FElement: TJSHTMLElement;
    FSearched: Boolean;
    FOwner: TWebComponent;
    FAttrib : TJSObject;

    function clicked(aEvent : TJSMouseEvent): Boolean;
    function GetAsButton: TJSHTMLButtonElement;
    function getAsDiv: TJSHTMLDivElement;
    function GetAsInput: TJSHTMLInputElement;
    function GetAsSelect: TJSHTMLSelectElement;
    function getAttribute(aName: String): JSValue;
    function getElementAttribute(aName: String): String;
    function get_checked: Boolean;
    function get_innerHTML: String;
    function get_value: String;
    procedure setAttribute(aName: String; AValue: JSValue);
    procedure setElementAttribute(aName: String; AValue: String);
    procedure set_checked(AValue: Boolean);
    procedure set_disabled(AValue: Boolean);
    procedure set_innerHTML(AValue: String);
    procedure set_onchange(AValue: TJSEventHandler);
    procedure set_textContent(AValue: String);
    procedure set_value(AValue: String);
    procedure set_onclick(AValue: TUIElementClickEventHandler);

  public
    constructor Create(aOwner: TWebComponent; const anId: String);
    destructor Destroy; override;

    procedure Clear();
    procedure setFocus();
    procedure addClass(aClass: String);
    procedure removeClass(aClass: String);
    function containsClass(aClass: String): Boolean;
    function appendChild(aChild : TJSNode) : TJSNode;
    function getFile(): TJSHTMLFile;
    function GetElement: TJSHTMLElement;
    function querySelector(selectors: String): TJSHTMLElement;
    function querySelectorAll(selectors: String): TJSNodeList;

    property AsButton: TJSHTMLButtonElement read GetAsButton;
    property AsInput: TJSHTMLInputElement read GetAsInput;
    property AsSelect: TJSHTMLSelectElement read GetAsSelect;
    property AsDiv: TJSHTMLDivElement read getAsDiv;

    property value: String read get_value write set_value;
    property innerHTML: String read get_innerHTML write set_innerHTML;
    property disabled: Boolean write set_disabled;
    property checked: Boolean read get_checked write set_checked;
    property textContent: String write set_textContent;
    property onclick: TUIElementClickEventHandler write set_onclick;
    property onchange : TJSEventHandler write set_onchange;

    property Attrib[aName: String]: JSValue read getAttribute write setAttribute;
    property ElementAttribute[aName: String]: String read getElementAttribute write setElementAttribute;
  end;

  // A base class for any component that manages a piece of the UI.
  // It holds a reference to a root DOM element and provides a standard lifecycle.

  { TWebComponent }

  TWebComponent = class(TObject)
  strict private
    FElements : TJSMap;

    procedure DestroyElements;

  protected
    FRootElement: TJSHTMLElement;

    // Indica se FRootElement contiene attualmente markup caricato tramite
    // LoadContent. Serve a componenti come TSideColumnComponent per decidere
    // se possono mostrarsi (non ha senso mostrare una colonna vuota).
    FHasContent: Boolean;

  public
    constructor Create(aRootElement: TJSHTMLElement); virtual; reintroduce;
    destructor Destroy; override;

    { BindUI - NON e' piu' invocata automaticamente dal costruttore (vedi
      Create sotto). E' responsabilita' del CHIAMANTE invocarla esplicitamente
      nel momento esatto in cui FRootElement contiene il markup corretto:

        - Se il markup e' gia' presente nella pagina ospite al momento della
          Create (es. TBaseForm creato da TPageManager.LoadPage, dopo che il
          template e' gia' stato iniettato in FContainer): chiamare BindUI
          subito dopo la Create. TPageManager.LoadPage lo fa esplicitamente.

        - Se il markup arriva in modo asincrono tramite LoadContent: non serve
          fare nulla, LoadContent chiama gia' BindUI internamente dopo
          l'injection (vedi sotto).

      Resa pubblica (non piu' protected) proprio per permettere a chiamanti
      esterni come TPageManager di invocarla. Override obbligatorio nelle
      classi derivate che devono legare eventi/elementi. }
    procedure BindUI; virtual;

    function getElementById(const anId: String): TUIElementWrapper;

    { LoadContent - GENERALIZZATO da TPageManager.LoadPage (vedi
      PageManager.pas): stessa identica sequenza fetch -> testo -> injection
      nel proprio elemento radice, resa qui riusabile da QUALUNQUE
      TWebComponent, non solo dalle pagine di rotta gestite dal
      PageManager.

      A differenza di TPageManager (che chiama BindUI esplicitamente dopo la
      Create, vedi PageManager.LoadPage), qui BindUI viene invocata
      internamente da LoadContent stessa, subito dopo l'injection del markup:
      il chiamante di LoadContent non deve fare nient'altro.

      Prima di richiamare BindUI, LoadContent invalida la cache dei wrapper
      gia' eventualmente risolti (DestroyElements), cosi' che le chiamate a
      getElementById successive ricreino i wrapper da zero contro il markup
      appena iniettato, invece di restituire vecchi wrapper agganciati a nodi
      DOM ormai rimossi (TUIElementWrapper.GetElement e' lazy e cachata - vedi
      FSearched).

      Ritorna True se il contenuto e' stato caricato e iniettato con
      successo (imposta anche HasContent), False altrimenti.

      Il chiamante decide QUANDO invocarla (tipicamente una volta sola,
      subito dopo Create, o alla prima apertura di un componente creato in
      anticipo ma mostrato solo su richiesta - vedi uCMMSAssetModelDialog.pas
      per un esempio concreto).

      IMPORTANTE - nessuna chiamata automatica a BindUI nel costruttore
      (vedi Create sotto): un TWebComponent il cui markup e' GIA' presente
      nella pagina ospite al momento della Create (es. TCMMSAssetTree,
      TCMMSDocumentsPanel, o un dialogo il cui HTML e' statico nella pagina
      che lo ospita) non usa LoadContent, ma deve invocare Self.BindUI
      esplicitamente subito dopo la Create - esattamente come fa
      TPageManager.LoadPage per TBaseForm. Questo e' un cambio di
      comportamento rispetto alla versione precedente: verificare tutti i
      punti del codice che istanziano un TWebComponent/discendente con
      markup gia' presente e aggiungere la chiamata a BindUI se mancante,
      altrimenti quei componenti smetteranno silenziosamente di legare
      eventi ed elementi. }
    function LoadContent(const aTemplatePath: String): Boolean; async; virtual;

    property RootElement: TJSHTMLElement read FRootElement;
    property HasContent: Boolean read FHasContent;
  end;

  { TBaseForm

    AGGIORNAMENTO (piu' applicativi nella stessa pagina): introdotta la
    nozione di CARTELLA RADICE dell'applicativo a cui la pagina
    appartiene, disponibile sia alla classe (parametro di loadNeededCSS)
    sia all'istanza (proprieta' BasePath).

    IL PROBLEMA CHE RISOLVE
    ------------------------------------------------------------------
    Quando un unico server ospita piu' applicativi distinti, ciascuno
    con le proprie pagine, i propri fogli di stile e le proprie
    risorse, la disposizione naturale dei file diventa:

        html/
          index.html
          pages/            pagine comuni
          css/
          cmms/
            pages/
            css/
          wms/
            pages/
            css/

    Il percorso del template puo' essere dichiarato al momento della
    registrazione della rotta, ma quello dei fogli di stile no: e'
    scritto dentro loadNeededCSS, che essendo una class function senza
    parametri non ha alcun modo di sapere dove si trovi la propria
    pagina.

    La conseguenza e' un'asimmetria fastidiosa: rinominando la cartella
    di un applicativo (da 'wms' a 'wms1', per dire) il template segue
    perche' il suo percorso e' dichiarato in un punto solo, mentre i
    fogli di stile restano indietro - e il guasto e' silenzioso, perche'
    la pagina si carica ugualmente, solo senza stile.

    PERCHE' UN PERCORSO E NON UN NOME DERIVATO DALLA ROTTA
    ------------------------------------------------------------------
    Una pagina puo' caricare PIU' fogli di stile, con nomi che non
    hanno alcun rapporto con quello della pagina (un foglio comune
    all'applicativo, uno specifico, uno di un componente riusato).
    Qualunque regola che derivi il nome del file dalla rotta sarebbe
    quindi inutilizzabile.

    Cio' che si puo' derivare e' invece la CARTELLA, che e' la stessa
    per tutte le risorse di un applicativo: la pagina continua a
    dichiarare quali fogli le servono, ma li compone a partire da un
    percorso che riceve dall'esterno.

    IL CASO SENZA APPLICATIVO NON E' UN'ECCEZIONE
    ------------------------------------------------------------------
    Una cartella radice vuota produce esattamente i percorsi che si
    usavano prima che esistesse questa nozione:

        ''      + 'css/login.css'    ->  'css/login.css'
        'wms/'  + 'css/ricerche.css' ->  'wms/css/ricerche.css'

    Una pagina che vive nella radice non e' quindi un caso particolare
    da gestire: e' semplicemente l'applicativo che ha la radice come
    propria cartella. Le pagine gia' scritte, che compongono percorsi
    come 'css/assets.css', continuano a funzionare tali e quali e
    possono ignorare del tutto il nuovo parametro.

    LA BARRA FINALE E' GARANTITA: TPageManager.RegisterForm normalizza
    il valore ricevuto aggiungendola se manca, cosi' la concatenazione
    e' sempre corretta e chi registra una rotta non deve ricordarsene. }

  TBaseForm = class(TWebComponent)
    strict private
      FBasePath : String;

    public
      class function getTemplatePath(): String; virtual;

      { aBasePath: cartella radice dell'applicativo a cui la pagina
        appartiene, con barra finale gia' garantita ('wms/', 'cmms/',
        oppure stringa vuota per le pagine che vivono nella radice).

        Da anteporre al percorso di ciascun foglio di stile:

            if not isCSSLoaded(aBasePath + 'css/ricerche.css') then
              ... loadResource(aBasePath + 'css/ricerche.css', 'css') ...

        Un override che non abbia bisogno di distinguere l'applicativo
        puo' semplicemente ignorare il parametro: il comportamento
        resta quello di prima. }
      class function loadNeededCSS(const aBasePath: String): Boolean; async; virtual;

      { Stessa cartella radice, disponibile all'ISTANZA: serve per le
        risorse che una pagina recupera per conto proprio DOPO essere
        stata costruita - tipicamente i template ausiliari, come il
        modello di una singola riga di un elenco:

            _RowTemplate := Self.BasePath + 'pages/shipment-row.html';

        Valorizzata da TPageManager.LoadPage subito dopo la Create e
        PRIMA di BindUI, cosi' e' gia' utilizzabile li'. }
      property BasePath: String read FBasePath write FBasePath;
  end;

  TBaseFormClass = class of TBaseForm;


implementation

uses
  SysUtils;

{ TWebComponent }

constructor TWebComponent.Create(aRootElement: TJSHTMLElement);
begin
  inherited Create;
  FRootElement := aRootElement;
  FElements := TJSMap.new;
  FHasContent := False;
end;

destructor TWebComponent.Destroy;
begin
  Self.DestroyElements;
  inherited Destroy;
end;

function TWebComponent.getElementById(const anId: String): TUIElementWrapper;
begin
  Result := TUIElementWrapper(FElements.get(anId));
  if not hasValue(Result) then
  begin
    Result := TUIElementWrapper.Create(Self, anId);
    FElements.&set(anId, Result);
  end;
end;

function TWebComponent.LoadContent(const aTemplatePath: String): Boolean;
{
  Stessa sequenza VERIFICATA in TPageManager.LoadPage (fetch -> .ok ->
  .text() -> injection), qui applicata a FRootElement (il contenitore di
  QUESTO componente) invece che al contenitore globale del PageManager.
  Nessuna chiamata o firma inventata: window.fetch/TJSResponse/AWait sono
  usati esattamente come in quel metodo.
}
var
  _Response : TJSResponse;
  _HTML     : String;
begin
  Result := False;
  FHasContent := False;

  if FRootElement = nil then
  begin
    console.warn('TWebComponent.LoadContent: FRootElement e'' nil, impossibile caricare ' + aTemplatePath);
    Exit;
  end;

  try
    _Response := AWait(TJSResponse, window.fetch(aTemplatePath));
    if _Response.ok then
    begin
      _HTML := AWait(String, _Response.text());
      FRootElement.innerHTML := _HTML;
      FHasContent := True;

      // Il markup precedente (se c'era) non esiste piu': i wrapper gia'
      // risolti andrebbero rieseguiti a vuoto per sempre (GetElement e'
      // lazy e cachata - vedi TUIElementWrapper.FSearched). Si invalida
      // la cache e si rilancia BindUI, che ricreera' i wrapper da zero
      // contro il markup appena iniettato.
      Self.DestroyElements;
      Self.BindUI;

      Result := True;
    end
    else
      console.warn('TWebComponent.LoadContent: impossibile caricare il template ' + aTemplatePath);
  except
    on E: Exception do
      console.error('TWebComponent.LoadContent: errore nel caricamento di ' + aTemplatePath + ': ' + E.Message);
  end;
end;

procedure TWebComponent.BindUI;
begin
  // Base implementation is empty. Descendants must override this.
end;

procedure TWebComponent.DestroyElements;
var
  _Iter: TJSIterator;
  _Value : TJSIteratorValue;
  _Item : TUIElementWrapper;
begin
  _Iter := FElements.values;
  repeat
    _Value := _Iter.next();
    if not _Value.done then
    begin
      _Item := TUIElementWrapper(_Value.value);
      _Item.Free;
    end
    else
      Break;
  until False;

  FElements.clear;
end;


{ TUIElementWrapper }

function TUIElementWrapper.clicked(aEvent: TJSMouseEvent): Boolean;
begin
  Result := False;
  if FOnClickEvent <> nil then
    Result := FOnClickEvent(Self, aEvent);
end;

function TUIElementWrapper.GetAsButton: TJSHTMLButtonElement;
begin
  Result := TJSHTMLButtonElement(Self.GetElement);
end;

function TUIElementWrapper.getAsDiv: TJSHTMLDivElement;
begin
  Result := TJSHTMLDivElement(Self.GetElement);
end;

function TUIElementWrapper.GetAsInput: TJSHTMLInputElement;
begin
  Result := TJSHTMLInputElement(Self.GetElement);
end;

function TUIElementWrapper.GetAsSelect: TJSHTMLSelectElement;
begin
  Result := TJSHTMLSelectElement(Self.GetElement);
end;

function TUIElementWrapper.getAttribute(aName: String): JSValue;
begin
  Result := FAttrib[aName];
end;

function TUIElementWrapper.getElementAttribute(aName: String): String;
var
  elem : TJSHTMLElement;
begin
  Result := '';
  elem := Self.GetElement;
  if hasValue(elem) then
    Result := elem.Attrs[aName];
end;

function TUIElementWrapper.get_checked: Boolean;
var
  elem: TJSHTMLElement;
begin
  Result := False;
  elem := Self.GetElement;
  if hasValue(elem) and (elem is TJSHTMLInputElement) then
    Result := TJSHTMLInputElement(elem).checked;
end;

function TUIElementWrapper.get_innerHTML: String;
var
  elem: TJSHTMLElement;
begin
  Result := '';
  elem := Self.GetElement;
  if hasValue(elem) then
    Result := elem.innerHTML;
end;

function TUIElementWrapper.get_value: String;
var
  elem: TJSHTMLElement;
begin
  Result := '';
  elem := Self.GetElement;
  if hasValue(elem) then
  begin
    if elem is TJSHTMLInputElement then
      Result := TJSHTMLInputElement(elem).value
    else if elem is TJSHTMLSelectElement then
      Result := TJSHTMLSelectElement(elem).value
    else
      Result := String(elem.Properties['value']); // textarea e altri
  end;
end;

procedure TUIElementWrapper.setAttribute(aName: String; AValue: JSValue);
begin
  FAttrib[aName] := AValue;
end;

procedure TUIElementWrapper.setElementAttribute(aName: String; AValue: String);
var
  elem : TJSHTMLElement;
begin
  elem := Self.GetElement;
  if hasValue(elem) then
    elem.Attrs[aName] := AValue;
end;

procedure TUIElementWrapper.set_checked(AValue: Boolean);
var
  elem: TJSHTMLElement;
begin
  elem := Self.GetElement;
  if hasValue(elem) and (elem is TJSHTMLInputElement) then
    TJSHTMLInputElement(elem).checked := AValue;
end;

procedure TUIElementWrapper.set_disabled(AValue: Boolean);
var
  elem: TJSHTMLElement;
begin
  elem := Self.GetElement;
  if hasValue(elem) then
    elem.Properties['disabled'] := AValue;
end;

procedure TUIElementWrapper.set_innerHTML(AValue: String);
var
  elem: TJSHTMLElement;
begin
  elem := Self.GetElement;
  if hasValue(elem) then
    elem.innerHTML := AValue;
end;

procedure TUIElementWrapper.set_onchange(AValue: TJSEventHandler);
var
  elem: TJSHTMLElement;
begin
  elem := Self.GetElement;
  if hasValue(elem) then
    elem.onchange := AValue;
end;

procedure TUIElementWrapper.set_textContent(AValue: String);
var
  elem: TJSHTMLElement;
begin
  elem := Self.GetElement;
  if hasValue(elem) then
    elem.textContent := AValue;
end;

procedure TUIElementWrapper.set_value(AValue: String);
var
  elem: TJSHTMLElement;
begin
  elem := Self.GetElement;
  if hasValue(elem) then
  begin
    if elem is TJSHTMLInputElement then
      TJSHTMLInputElement(elem).value := AValue
    else if elem is TJSHTMLSelectElement then
      TJSHTMLSelectElement(elem).value := AValue
    else
      elem.Properties['value'] := AValue; // textarea e altri
  end;
end;

procedure TUIElementWrapper.set_onclick(AValue: TUIElementClickEventHandler);
var
  elem: TJSHTMLElement;
begin
  elem := Self.GetElement;
  if hasValue(elem) then
  begin
    if AValue = nil then
    begin
      FOnClickEvent := nil;
      elem.onclick := nil;
    end
    else begin
      FOnClickEvent := AValue;
      elem.onclick := @Self.clicked;
    end;
  end;
end;

function TUIElementWrapper.GetElement: TJSHTMLElement;
begin
  if not FSearched then
  begin
    // Selettore per attributo invece di '#id': funziona anche con id che
    // contengono caratteri speciali (punti, due punti, ...).
    FElement := TJSHTMLElement(FOwner.RootElement.querySelector('[id="' + FId + '"]'));
    // Si memorizza SOLO un risultato positivo: se l'elemento non c'e' ancora
    // (viene creato dopo, ad esempio con innerHTML) la ricerca va ripetuta
    // alla chiamata successiva, invece di restare per sempre a nil.
    FSearched := hasValue(FElement);
  end;
  Result := FElement;
end;

constructor TUIElementWrapper.Create(aOwner: TWebComponent; const anId: String);
begin
  inherited Create;
  FOwner := aOwner;
  FId := anId;
  FSearched := False;
  FElement := nil;
  FAttrib := TJSObject.new;
end;

destructor TUIElementWrapper.Destroy;
begin
  // Un wrapper che non ha mai trovato il proprio elemento non ha nulla da
  // sganciare: evita anche una querySelector inutile per ognuno.
  if FSearched then
  begin
    try
      Self.onclick := nil;
      Self.onchange := nil;
    except
      on E: Exception do
        console.error(E.message);
    end;
  end;

  inherited Destroy;
end;

procedure TUIElementWrapper.Clear();
begin
  Self.innerHTML := '';
end;

procedure TUIElementWrapper.setFocus();
var
  elem: TJSHTMLElement;
begin
  elem := Self.GetElement;
  if hasValue(elem) then
    elem.focus();
end;

procedure TUIElementWrapper.addClass(aClass: String);
var
  elem: TJSHTMLElement;
begin
  elem := Self.GetElement;
  if hasValue(elem) then
    elem.classList.add(aClass);
end;

procedure TUIElementWrapper.removeClass(aClass: String);
var
  elem: TJSHTMLElement;
begin
  elem := Self.GetElement;
  if hasValue(elem) then
    elem.classList.remove(aClass);
end;

function TUIElementWrapper.containsClass(aClass: String): Boolean;
var
  elem: TJSHTMLElement;
begin
  Result := False;
  elem := Self.GetElement;
  if hasValue(elem) then
    Result := elem.classList.contains(aClass);
end;

function TUIElementWrapper.appendChild(aChild: TJSNode): TJSNode;
var
  elem: TJSHTMLElement;
begin
  Result := nil;
  elem := Self.GetElement;
  if hasValue(elem) then
    Result := elem.appendChild(aChild);
end;

function TUIElementWrapper.getFile(): TJSHTMLFile;
var
  elem: TJSHTMLElement;
  _files : TJSHTMLFileList;
begin
  Result := nil;
  elem := Self.GetElement;
  if hasValue(elem) then
  begin
    asm _files = elem.files; end;
    if hasValue(_files) and (_files.length > 0) then
      Result := _files.Files[0];
  end;
end;

function TUIElementWrapper.querySelector(selectors: String): TJSHTMLElement;
var
  _elem: TJSHTMLElement;
begin
  Result := nil;
  _elem := Self.GetElement;
  if hasValue(_elem) then
    Result := TJSHTMLElement(_elem.querySelector(selectors));
end;

function TUIElementWrapper.querySelectorAll(selectors: String): TJSNodeList;
var
  _elem: TJSHTMLElement;
begin
  Result := nil;
  _elem := Self.GetElement;
  if hasValue(_elem) then
    Result := _elem.querySelectorAll(selectors);
end;


{ TBaseForm }

class function TBaseForm.getTemplatePath: String;
begin
  Result := '';
end;

class function TBaseForm.loadNeededCSS(const aBasePath: String): Boolean;
begin
  // Implementazione di base vuota: una pagina senza fogli di stile
  // propri non deve ridefinire nulla. Il parametro e' comunque
  // dichiarato qui perche' la firma sia unica per tutte le pagine.
  Result := True;
end;

end.
