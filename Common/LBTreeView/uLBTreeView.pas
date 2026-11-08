unit uLBTreeView;

{$mode ObjFPC}{$H+}

interface

uses
  JS, SysUtils, web;

type
  TLBTreeViewMenuItem = class;
  TLBjsTreeView = class;

  // Callback per richiedere i menu items
  TLBTreeViewMenuCallback = reference to function(aItem: TJSObject): TJSArray;

  // Callback per l'azione del menu item
  TLBTreeViewMenuItemCallback = reference to procedure(aItem: TJSObject);

  { TLBTreeViewMenuItem }
  TLBTreeViewMenuItem = class(TObject)
  private
    FCaption: String;
    FCallback: TLBTreeViewMenuItemCallback;
    FIconClass: String;
    FGroup: String;
    FDanger: Boolean;
  public
    constructor Create(const aCaption: String; aCallback: TLBTreeViewMenuItemCallback);
    property Caption: String read FCaption;
    property Callback: TLBTreeViewMenuItemCallback read FCallback;
    // Proprieta' OPT-IN dell'aspetto della voce (vuote/False per default). Se NESSUNA voce di un menu le imposta,
    // l'HTML del menu e' IDENTICO a prima: i consumatori esistenti non cambiano.
    //   IconClass  classi CSS di uno <span> icona prima del testo (es. 'app-mi app-mi-edit'): l'icona la disegna
    //              il CSS dell'applicazione. Se almeno una voce ha l'icona, il menu riceve la classe
    //              LBTVContextMenu-Icons e le voci senza icona hanno uno span vuoto, cosi' i testi restano allineati.
    //   Group      voci vicine per significato: quando cambia rispetto alla voce precedente, la voce riceve la classe
    //              LBTVContextMenuItem-Sep (separatore sopra).
    //   Danger     azione che toglie qualcosa (es. eliminare): classe LBTVContextMenuItem-Danger.
    property IconClass: String read FIconClass write FIconClass;
    property Group: String read FGroup write FGroup;
    property Danger: Boolean read FDanger write FDanger;
  end;

  { TLBjsTreeView }

  TLBjsTreeView = class(TObject)
    strict private
      FDestElem : TJSHTMLElement;
      FDestElemId : String;
      FViewedProperty : String;
      FChildrenProperty : String;
      FIdProperty : String;
      FData : TJSArray;
      FChecked : Boolean;
      FCheckOnlyLeaf : Boolean;  // se True, checkbox solo sugli elementi foglia
      FSingleSelect : Boolean;   // modalita' selezione singola
      FFlatList : TJSArray;
      FItemIdx : Integer;
      FItemsToSelect : TJSArray;
      // Rami da aprire a render avvenuto (vedi setExpandedIds): come FItemsToSelect, vale per il prossimo renderData.
      FIdsToExpand   : TJSArray;

      // OPT-IN, default False: quando True, il testo lungo di un'etichetta
      // va a capo mantenendo freccia/checkbox/testo allineati, invece di
      // lasciare la freccia isolata su una riga a se' (il comportamento
      // ORIGINALE, invariato quando questa proprieta' resta al suo
      // default False) - vedi la nota estesa su insertArray sotto e su
      // LBTreeView.css per la spiegazione completa, inclusa la
      // motivazione della scelta opt-in (componente CONDIVISO, usato
      // da piu' applicazioni: un cambiamento del
      // comportamento visivo di DEFAULT avrebbe potuto interferire con un
      // eventuale override CSS gia' esistente altrove e mai verificato in
      // questa sede). QUESTA PROPRIETA' CONTROLLA SOLO L'ASPETTO VISIVO
      // (a-capo allineato) - vedi il commento su OnlyCaretToggles per la
      // netta separazione rispetto alla SEMANTICA del click, controllata
      // ESCLUSIVAMENTE da quell'altra proprieta'.
      FWrapLongLabels : Boolean;

      // Proprieta' OPT-IN (default False), INDIPENDENTE da
      // FWrapLongLabels - vedi il commento esteso sulla property
      // OnlyCaretToggles piu' sotto e su manageTreeViewClick per la
      // spiegazione completa di come le due proprieta' cooperano senza
      // dipendere l'una dall'altra IN NESSUNA delle due direzioni
      // (correzione rispetto a un aggiornamento precedente in cui
      // FWrapLongLabels=True finiva per imporre "solo il caret
      // apre/chiude" anche con FOnlyCaretToggles=False - un difetto
      // segnalato e corretto qui).
      FOnlyCaretToggles : Boolean;

      // Proprieta' OPT-IN (default False): freccia sottile (chevron) che ruota all'apertura, al posto dei
      // triangoli pieni. Aggiunge SOLO la classe "LBTVChevron" al contenitore radice; senza, l'HTML e' quello di
      // sempre. Vedi la property ChevronCaret.
      FChevronCaret : Boolean;

      // Default True (comportamento storico): etichette dei nodi e voci dei
      // menu sono inserite come HTML, senza escape. Impostare False per
      // trattarle come TESTO (con escape): e' la scelta sicura quando i nomi
      // arrivano dagli utenti.
      FLabelsAreHtml : Boolean;

      FCheckedList : TJSArray;   // lista live dei TJSObject selezionati
      FCheckedElems : TJSArray;  // lista live dei TJSElement DOM selezionati (SingleSelect: max 1)

      // Context menu
      FContextMenuCallback: TLBTreeViewMenuCallback;
      FContextMenuElement: TJSHTMLElement;

      // Event delegation - riferimento ai listener per poterli rimuovere
      FClickHandler : TJSEventHandler;
      FContextMenuHandler : THTMLClickEventHandler;

    private
      function get_Item(Idx: Integer): TJSObject;
      function labelHtml(const aText: String): String;

      procedure hideContextMenu;
      procedure showContextMenu(X, Y: Integer; aItem: TJSObject);
      procedure fitContextMenu(aMenu: TJSHTMLElement; X, Y: Integer);

      function doManageCaret(aTarget: TJSElement): boolean;
      procedure applyExpanded(anIds: TJSArray);
      function doManageCheckbox(aTarget: TJSElement): boolean;
      function manageContextMenu(Event: TJSMouseEvent): boolean;
      function manageTreeViewClick(Event: TJSEvent): boolean;

    protected
      // Accessor mirati per le classi derivate che sovrascrivono insertArray/renderWrapper
      function getDestElemId: String;
      function getViewedProperty: String;
      function getChildrenProperty: String;
      function getChecked: Boolean;
      function getCheckOnlyLeaf: Boolean;
      procedure pushFlatItem(aItem: TJSObject);
      function nextItemIdx: Integer;  // restituisce FItemIdx e lo incrementa

      // Virtuali: sovrascrivibili dalle classi derivate per cambiare il rendering
      function insertArray(anArray: TJSArray; aLevel: Integer; aParentItem: TJSObject = nil): String; virtual;
      function renderWrapper(const aInnerHTML: String): String; virtual;

    public
      constructor Create(anOwner: TJSHTMLElement; isChecked: Boolean; isSingleSelect: Boolean = False; isCheckOnlyLeaf: Boolean = False);
      destructor Destroy; override;

      procedure setData(aData: TJSArray; anIdProperty, aViewedProperty, aChildrenProperty: String);
      procedure renderData();

      procedure select(anIdList: TJSArray);

      procedure setChecked(anItemIdx: Integer; isChecked: Boolean);
      procedure uncheckItems();

      // STATO DI APERTURA DEI RAMI (OPT-IN: nessun consumatore e' obbligato a usarlo; senza chiamarli nulla cambia).
      // Servono a ritrovare l'albero come era stato lasciato: dopo un nuovo renderData (ricaricamento dei dati) o quando
      // la pagina che lo contiene viene ricostruita. Gli id sono quelli della proprieta' indicata in setData
      // (anIdProperty): vanno quindi usati con id UNICI e stabili fra un caricamento e l'altro (es. un uuid).
      // getExpandedIds: gli id dei rami aperti ora ([] se non c'e' nulla di aperto o se non e' ancora stato disegnato).
      function  getExpandedIds: TJSArray;
      // setExpandedIds: apre i rami con quegli id. Se l'albero e' gia' disegnato lo fa subito e, in ogni caso, anche
      // dopo il PROSSIMO renderData. Un id che non c'e' piu' si ignora. Non chiude i rami gia' aperti.
      procedure setExpandedIds(anIds: TJSArray);
      // L'elemento <li> del nodo con quell'id (nil se non c'e'): per evidenziarlo o scorrere fino a lui.
      function  findItemElement(const anId: String): TJSHTMLElement;

      // Imposta la callback per il context menu
      procedure setContextMenuCallback(aCallback: TLBTreeViewMenuCallback);

      property Item[Idx: Integer]: TJSObject read get_Item;
      property CheckedItems: TJSArray read FCheckedList;
      property CheckedElems: TJSArray read FCheckedElems;

      property CheckedList: Boolean write FChecked;
      property SingleSelect: Boolean read FSingleSelect write FSingleSelect;
      property CheckOnlyLeaf: Boolean read FCheckOnlyLeaf write FCheckOnlyLeaf;

      // Proprieta' OPT-IN (default False - comportamento ORIGINALE
      // invariato per chiunque non la imposti esplicitamente, incluse
      // TUTTE le applicazioni esistenti che gia' consumano questa unit).
      // Impostarla a True su un'istanza specifica (es. l'albero
      // principale di un'applicazione) attiva SOLO per quella istanza
      // il testo che va a capo allineato - vedi il commento esteso su
      // FWrapLongLabels sopra e su insertArray/LBTreeView.css per il
      // dettaglio completo. CONTROLLA SOLO L'ASPETTO VISIVO: NON decide
      // da sola se un click sul testo apre/chiude un ramo - quella
      // decisione dipende ESCLUSIVAMENTE da OnlyCaretToggles, vedi sotto
      // (le due proprieta' sono ORTOGONALI in ENTRAMBE le direzioni).
      property WrapLongLabels: Boolean read FWrapLongLabels write FWrapLongLabels;

      // Proprieta' OPT-IN, default False, INDIPENDENTE da WrapLongLabels
      // in ENTRAMBE le direzioni (vedi CORREZIONE sotto): quando True, un
      // click e' interpretato come apertura/chiusura del ramo SOLO se
      // cade esattamente sul glifo del caret - un click sul testo
      // dell'etichetta non fa piu' nulla. Quando False (il default), un
      // click sul testo dell'etichetta si comporta come un click sul
      // nodo stesso (il comportamento storico, INVARIATO): apre/chiude
      // il ramo se il nodo ha figli.
      //
      // Le quattro combinazioni sono TUTTE indipendenti l'una dall'altra:
      //
      //   WrapLongLabels | OnlyCaretToggles | testo va a capo | solo il caret apre/chiude
      //   False          | False            | No (originale)  | No (originale: click ovunque toggla)
      //   False          | True             | No              | Si
      //   True           | False            | Si              | No: click sul testo toggla comunque
      //   True           | True             | Si              | Si
      //
      // CORREZIONE rispetto a un aggiornamento precedente: in quella
      // versione, il wrapper strutturale "LBTVLabel" (necessario per
      // permettere l'a-capo allineato quando WrapLongLabels=True) veniva
      // ERRONEAMENTE interpretato da manageTreeViewClick come "click sul
      // testo = nessuna azione" in modo INCONDIZIONATO, ogni volta che
      // quel wrapper esisteva nel markup - indipendentemente dal VALORE
      // di questa proprieta'. Risultato: con WrapLongLabels=True e
      // OnlyCaretToggles=False (terza riga della tabella sopra), un
      // click sul testo NON toglava piu' nulla, contraddicendo
      // esplicitamente il fatto che OnlyCaretToggles fosse stata
      // impostata a False - un'incoerenza reale tra il valore dichiarato
      // della proprieta' e il comportamento osservato, segnalata e
      // corretta qui.
      //
      // CORREZIONE: manageTreeViewClick ora decide SEMPRE in base al
      // VALORE di FOnlyCaretToggles, mai in base alla sola presenza
      // strutturale del wrapper "LBTVLabel" nel markup. Quando il click
      // cade su "LBTVLabel" e FOnlyCaretToggles e' False, la risalita
      // NON si ferma li': prosegue (esattamente come se quel wrapper non
      // esistesse ai fini del click) fino al vero span del nodo
      // ("LBTVCaret"/"LBTVEmptyCaret"), dove si applica la stessa
      // regola di sempre - toggla se il nodo ha figli, nessuna azione se
      // e' una foglia (il bugfix di base, sempre attivo indipendentemente
      // da entrambe le proprieta', vedi manageTreeViewClick).
      property OnlyCaretToggles: Boolean read FOnlyCaretToggles write FOnlyCaretToggles;

      // OPT-IN (default False): la freccia di apertura diventa un chevron sottile che RUOTA di 90 gradi quando il
      // ramo e' aperto (LBTreeView.css, regole ".LBTVChevron"); i nodi foglia ricevono uno spazio della stessa
      // larghezza, cosi' i testi dei fratelli restano allineati. Colore e dimensione dalle variabili di tema di
      // sempre (--lbtv-caret-color, --lbtv-caret-hover-color, --lbtv-caret-open-color, --lbtv-caret-size).
      // Funziona con e senza WrapLongLabels. Va impostata prima di renderData.
      property ChevronCaret: Boolean read FChevronCaret write FChevronCaret;

      // Default True (come prima): le etichette dei nodi (proprieta' indicata
      // in setData) e il testo delle voci di menu sono inseriti come HTML.
      // Impostarla a False li tratta come TESTO (HtmlEncode): da usare quando
      // i nomi arrivano dagli utenti. Va impostata prima di renderData.
      property LabelsAreHtml: Boolean read FLabelsAreHtml write FLabelsAreHtml;
  end;

const
  cLBTVParent = String('LBTVParent');

implementation

uses
  Types, strutils, weborworker, uLBWebUtils;

var
  gv_LBTreeViewItem : Integer = 0;

{ TLBTreeViewMenuItem }

constructor TLBTreeViewMenuItem.Create(const aCaption: String; aCallback: TLBTreeViewMenuItemCallback);
begin
  inherited Create;
  FCaption := aCaption;
  FCallback := aCallback;
  FIconClass := '';
  FGroup := '';
  FDanger := False;
end;

{ TLBjsTreeView }

function TLBjsTreeView.get_Item(Idx: Integer): TJSObject;
begin
  Result := nil;

  if (Idx >= 0) and (Idx < FFlatList.Length) then
    Result := TJSObject(FFlatList.Elements[Idx]);
end;

function TLBjsTreeView.insertArray(anArray: TJSArray; aLevel: Integer; aParentItem: TJSObject): String;
{
  WRAPPER "LBTVLabel": emesso quando FWrapLongLabels OPPURE
  FOnlyCaretToggles sono True (OR logico) - avvolge ESCLUSIVAMENTE la
  porzione checkbox-o-testo del nodo. IMPORTANTE (vedi la property
  OnlyCaretToggles per la spiegazione completa): la sola ESISTENZA di
  questo wrapper nel markup NON determina piu' da sola il comportamento
  del click - manageTreeViewClick decide SEMPRE in base al VALORE di
  FOnlyCaretToggles, mai in base alla presenza strutturale della classe.
  Questo wrapper puo' quindi esistere (per servire WrapLongLabels) senza
  che il click sul testo venga bloccato, se FOnlyCaretToggles e' False.

  WRAPPER "LBTVRow": emesso SOLO quando FWrapLongLabels e' True (mai per
  il solo FOnlyCaretToggles) - il suo scopo e' UNICAMENTE permettere a
  LBTreeView.css di riposizionare il glifo del caret (da
  "_class::before" a "_class > .LBTVRow::before") per ottenere
  l'allineamento con il testo che va a capo. Un click che cade su questo
  span (cioe' sul glifo, quando WrapLongLabels lo ha spostato qui)
  risale sempre di un livello al vero span del nodo, dove si applica poi
  la stessa regola di ogni altro "click sul caret" - indipendentemente da
  OnlyCaretToggles: il glifo del caret DEVE sempre poter aprire/chiudere
  il ramo, quale che sia il valore di quella proprieta' (che riguarda
  solo il TESTO, non il glifo).

  CAUSA ORIGINALE DEL PROBLEMA DELL'A-CAPO (per cui esiste
  FWrapLongLabels, invariato): .LBTVCheckbox aveva "white-space: nowrap"
  - un blocco indivisibile che, non entrando nella riga, si sposta per
  intero a capo lasciando la freccia (un ::before separato, sull'elemento
  padre) isolata sulla riga precedente. Risolto SOLO quando
  FWrapLongLabels = True (LBTreeView.css applica le nuove regole solo
  sotto ".LBTVWrapLabels").

  SICUREZZA per i consumatori esistenti: con FWrapLongLabels =
  False E FOnlyCaretToggles = False (il default per chiunque non attivi
  esplicitamente NESSUNA delle due), l'HTML generato qui e' BYTE PER
  BYTE IDENTICO a quello di prima di qualunque di questi aggiornamenti -
  nessun nuovo elemento, nessuna nuova classe.
}
var
  _Children : TJSArray = nil;
  _Item : TJSObject;
  _ElemId : String;
  i, l : Integer;
  _class : String;
  _isLeaf : Boolean;
  _NeedsLabelWrap : Boolean;

begin
  Result := '';

  _NeedsLabelWrap := FWrapLongLabels or FOnlyCaretToggles;

  if (anArray.Length > 0) then
  begin
    for i := 0 to anArray.Length - 1 do
    begin
      _Item := TJSObject(anArray.Elements[i]);
      if Length(FChildrenProperty) > 0 then
        _Children := TJSArray(_Item.Properties[FChildrenProperty]);

      // Un elemento e' foglia se non ha figli o li ha ma la lista e' vuota
      _isLeaf := (not hasValue(_Children)) or (_Children.Length = 0);

      FFlatList.push(_Item);
      _ElemId := FDestElemId + '_' + IntToStr(FItemIdx);
      FItemIdx += 1;

      Result += '<li data-item-idx="' + IntToStr(FItemIdx - 1) + '">';

      for l := 1 to aLevel do
        Result += '<span class="LBTVEmptyCaret">';

      _class := 'LBTVEmptyCaret';
      if hasValue(_Children) then
      begin
        if (_Children.Length > 0) then
          _class := 'LBTVCaret';
      end;

      Result += '<span class="' + _class + '">';

      // "LBTVRow": SOLO con FWrapLongLabels.
      if FWrapLongLabels then
        Result += '<span class="LBTVRow">';

      // "LBTVLabel": con FWrapLongLabels OPPURE FOnlyCaretToggles.
      if _NeedsLabelWrap then
        Result += '<span class="LBTVLabel">';

      // la checkbox viene mostrata se FChecked=True e:
      // - FCheckOnlyLeaf=False (comportamento originale: tutti gli elementi)
      // - FCheckOnlyLeaf=True (solo le foglie)
      if FChecked and (not FCheckOnlyLeaf or _isLeaf) then
        Result += '<span id="' + _ElemId + '" class="LBTVCheckbox">' +
                  Self.labelHtml(String(_Item.Properties[FViewedProperty])) + '</span>'
      else
        Result += Self.labelHtml(String(_Item.Properties[FViewedProperty]));

      if _NeedsLabelWrap then
        Result += '</span>'; // chiude LBTVLabel

      if FWrapLongLabels then
        Result += '</span>'; // chiude LBTVRow

      if hasValue(aParentItem) then
        _Item[cLBTVParent] := aParentItem;

      if hasValue(_Children) then
      begin
        if (_Children.Length > 0) then
          Result += '<ul class="LBTreeView LBTVNested">' +
                    Self.insertArray(_Children, aLevel + 1, _Item) + '</ul>';
      end;

      Result += '</span>'; // chiude lo span esterno (_class)

      for l := 1 to aLevel do
        Result += '</span>';

      Result += '</li>';
    end;
  end;
end;

function TLBjsTreeView.renderWrapper(const aInnerHTML: String): String;
{
  INVARIATO: la classe modificatore "LBTVWrapLabels" resta legata SOLO a
  FWrapLongLabels - FOnlyCaretToggles non necessita di alcuna classe CSS
  sul contenitore radice (il wrapper "LBTVLabel" che introduce da solo,
  senza WrapLongLabels, non ha ALCUNA regola CSS associata - resta un
  contenitore strutturale inerte ai fini visivi, rilevante solo per la
  logica di manageTreeViewClick).
}
var
  _class : String;
begin
  // classi modificatore OPT-IN sul solo contenitore radice: senza opzioni attive l'HTML e' quello di sempre
  _class := 'LBTreeView';
  if FWrapLongLabels then
    _class += ' LBTVWrapLabels';
  if FChevronCaret then
    _class += ' LBTVChevron';
  Result := '<ul class="' + _class + '">' + aInnerHTML + '</ul>';
end;

function TLBjsTreeView.getDestElemId: String;
begin
  Result := FDestElemId;
end;

function TLBjsTreeView.getViewedProperty: String;
begin
  Result := FViewedProperty;
end;

function TLBjsTreeView.getChildrenProperty: String;
begin
  Result := FChildrenProperty;
end;

function TLBjsTreeView.getChecked: Boolean;
begin
  Result := FChecked;
end;

function TLBjsTreeView.getCheckOnlyLeaf: Boolean;
begin
  Result := FCheckOnlyLeaf;
end;

procedure TLBjsTreeView.pushFlatItem(aItem: TJSObject);
begin
  FFlatList.push(aItem);
end;

function TLBjsTreeView.nextItemIdx: Integer;
begin
  Result := FItemIdx;
  FItemIdx += 1;
end;

function TLBjsTreeView.labelHtml(const aText: String): String;
begin
  if FLabelsAreHtml then
    Result := aText
  else
    Result := HtmlEncode(aText);
end;

constructor TLBjsTreeView.Create(anOwner: TJSHTMLElement; isChecked: Boolean; isSingleSelect: Boolean = False; isCheckOnlyLeaf: Boolean = False);
begin
  inherited Create();

  gv_LBTreeViewItem += 1;
  FDestElem := anOwner;
  FDestElemId := 'LBTV_' + IntToStr(gv_LBTreeViewItem);
  FChecked := isChecked;
  FLabelsAreHtml := True;   // comportamento storico: vedi la property LabelsAreHtml
  FCheckOnlyLeaf := isCheckOnlyLeaf;
  FSingleSelect := isSingleSelect;
  // Default False per entrambe: comportamento ORIGINALE invariato finche'
  // il chiamante non le imposta esplicitamente - vedi i rispettivi
  // commenti sulle due property nell'interfaccia.
  FWrapLongLabels := False;
  FOnlyCaretToggles := False;
  FChevronCaret := False;
  FIdsToExpand := nil;

  FCheckedList := nil;
  FCheckedElems := nil;
  FContextMenuCallback := nil;
  FContextMenuElement := nil;
  FClickHandler := nil;
  FContextMenuHandler := nil;
end;

destructor TLBjsTreeView.Destroy;
begin
  if FDestElem <> nil then
  begin
    if hasValue(FClickHandler) then
      TJSElement(FDestElem).removeEventListener('click', FClickHandler);
    if hasValue(FContextMenuHandler) then
      TJSElement(FDestElem).removeEventListener('contextmenu', FContextMenuHandler);
    FDestElem.innerHTML := '';
  end;

  if FContextMenuElement <> nil then
  begin
    FContextMenuElement.remove;
    FContextMenuElement := nil;
  end;

  inherited Destroy;
end;

{ ---- stato di apertura dei rami ---- }

function TLBjsTreeView.getExpandedIds: TJSArray;
var
  _Nodes : TJSNodeList;
  i      : Integer;
  _Li    : TJSElement;
  _Idx   : Integer;
  _Item  : TJSObject;
begin
  Result := TJSArray.new;
  if (FDestElem = nil) or (not hasValue(FFlatList)) then Exit;
  // un ramo aperto e' lo span con classe LBTVCaret-Down (vedi doManageCaret); il suo <li> porta l'indice nell'elenco piatto
  _Nodes := FDestElem.querySelectorAll('.LBTVCaret-Down');
  for i := 0 to _Nodes.length - 1 do
  begin
    _Li := TJSElement(_Nodes.item(i)).closest('li');
    if not hasValue(_Li) then Continue;
    _Idx := StrToIntDef(String(_Li.getAttribute('data-item-idx')), -1);
    if _Idx < 0 then Continue;
    _Item := Self.Item[_Idx];
    if hasValue(_Item) then
      Result.push(String(_Item.Properties[FIdProperty]));
  end;
end;

procedure TLBjsTreeView.applyExpanded(anIds: TJSArray);
var
  i      : Integer;
  _Item  : TJSObject;
  _Li    : TJSElement;
  _Caret : TJSElement;
begin
  if (not hasValue(anIds)) or (not hasValue(FFlatList)) or (FDestElem = nil) then Exit;
  for i := 0 to FFlatList.Length - 1 do
  begin
    _Item := TJSObject(FFlatList.Elements[i]);
    if not anIds.includes(String(_Item.Properties[FIdProperty])) then Continue;
    _Li := TJSElement(FDestElem.querySelector('li[data-item-idx="' + IntToStr(i) + '"]'));
    if not hasValue(_Li) then Continue;
    // il PRIMO .LBTVCaret nell'ordine del documento e' quello del nodo stesso (i suoi figli vengono dopo); una foglia
    // non ne ha (ha .LBTVEmptyCaret) e si salta
    _Caret := TJSElement(_Li.querySelector('.LBTVCaret'));
    if hasValue(_Caret) and (not _Caret.classList.contains('LBTVCaret-Down')) then
      Self.doManageCaret(_Caret);
  end;
end;

procedure TLBjsTreeView.setExpandedIds(anIds: TJSArray);
begin
  FIdsToExpand := anIds;
  if hasValue(FFlatList) and (FDestElem <> nil) then
    Self.applyExpanded(anIds);
end;

function TLBjsTreeView.findItemElement(const anId: String): TJSHTMLElement;
var
  i : Integer;
begin
  Result := nil;
  if (FDestElem = nil) or (not hasValue(FFlatList)) then Exit;
  for i := 0 to FFlatList.Length - 1 do
    if String(TJSObject(FFlatList.Elements[i]).Properties[FIdProperty]) = anId then
    begin
      Result := TJSHTMLElement(FDestElem.querySelector('li[data-item-idx="' + IntToStr(i) + '"]'));
      Exit;
    end;
end;

procedure TLBjsTreeView.setData(aData: TJSArray; anIdProperty, aViewedProperty, aChildrenProperty: String);
begin
  FData := aData;
  FIdProperty := anIdProperty;
  FViewedProperty := aViewedProperty;
  FChildrenProperty := aChildrenProperty;
end;

function TLBjsTreeView.doManageCaret(aTarget: TJSElement): boolean;
var
  _nested: TJSElement;
begin
  _nested := TJSElement(aTarget.querySelector('.LBTVNested'));
  if hasValue(_nested) then
    _nested.classList.toggle('LBTVActive');
  aTarget.classList.toggle('LBTVCaret-Down');
  Result := True;
end;

function TLBjsTreeView.doManageCheckbox(aTarget: TJSElement): boolean;
var
  _Parts : TStringDynArray;
  _Checked : Boolean;
  _newIdx : Integer;
  _clickedElem : TJSElement;
  _prevElem : TJSElement;
  _elemIdx : Integer;
begin
  Result := False;
  _Parts := SplitString(aTarget.id, '_');
  if Length(_Parts) < 3 then Exit;
  _newIdx := StrToIntDef(_Parts[2], -1);
  if _newIdx < 0 then Exit;

  _clickedElem := aTarget;

  if FSingleSelect then
  begin
    if (FCheckedElems.Length > 0) then
    begin

      _prevElem := TJSElement(FCheckedElems.Elements[0]);

      _prevElem.classList.remove('LBTVCheckbox-Checked');
      TJSObject(FCheckedList.Elements[0]).Properties['LBTV_Selected'] := False;
      FCheckedList.splice(0, 1);
      FCheckedElems.splice(0, 1);
      if _prevElem = _clickedElem then // l'elemento e' stato rimosso dalla selezione quindi esce
        Exit(True);
    end;

    _clickedElem.classList.add('LBTVCheckbox-Checked');
    FCheckedElems.push(_clickedElem);
    Self.setChecked(_newIdx, True);
  end
  else begin
    _Checked := _clickedElem.classList.toggle('LBTVCheckbox-Checked');
    _elemIdx := FCheckedElems.indexOf(_clickedElem);
    if _Checked then
    begin
      if _elemIdx = -1 then
        FCheckedElems.push(_clickedElem);
    end
    else
    begin
      if _elemIdx > -1 then
        FCheckedElems.splice(_elemIdx, 1);
    end;
    Self.setChecked(_newIdx, _Checked);
  end;

  Result := True;
end;

function TLBjsTreeView.manageTreeViewClick(Event: TJSEvent): boolean;
{
  BUGFIX DI BASE (sempre attivo, INDIPENDENTE da entrambe le proprieta'
  opt-in): un click su un discendente qualsiasi (in particolare un
  FIGLIO FOGLIA) chiudeva il ramo PADRE gia' espanso, invece di non fare
  nulla. Causa: <ul class="LBTVNested"> (il sottoalbero dei figli di un
  nodo) e' generato DENTRO il proprio <span class="_class"> (invariato,
  vedi insertArray) - la vecchia risalita si fermava al PRIMO antenato
  con classe "LBTVCaret", ma un nodo FOGLIA ha classe "LBTVEmptyCaret"
  (nome DIVERSO, nessun match): la risalita scavalcava quindi il proprio
  span, il proprio <li>, il <ul> del padre, e trovava il primo vero
  "LBTVCaret" solo al livello del PADRE, chiudendolo. CORRETTO: la
  risalita ora si FERMA SEMPRE al confine del nodo su cui si e'
  realmente cliccato (branch "LBTVEmptyCaret" sotto) - mai oltre, verso
  un antenato diverso. Attivo con QUALUNQUE combinazione delle due
  proprieta' opt-in, comprese entrambe False.

  "SOLO IL CARET APRE/CHIUDE" - CORREZIONE rispetto a un aggiornamento
  precedente (segnalata dall'utente): la decisione ora dipende SEMPRE dal
  VALORE di FOnlyCaretToggles, MAI dalla sola presenza strutturale della
  classe "LBTVLabel" nel markup (che, come spiegato nel commento sulla
  property OnlyCaretToggles, puo' esistere anche quando
  FOnlyCaretToggles = False, per servire FWrapLongLabels). Quando il
  target e' "LBTVLabel":
    - se FOnlyCaretToggles = True: nessuna azione, ferma qui (click sul
      testo non deve aprire/chiudere nulla).
    - se FOnlyCaretToggles = False: NON ci si ferma - si prosegue la
      risalita esattamente come se questo wrapper non esistesse ai fini
      del click, fino al vero span del nodo ("LBTVCaret"/
      "LBTVEmptyCaret"), dove si applica la stessa regola di sempre
      (toggla se il nodo ha figli, nessuna azione se e' una foglia) -
      ripristinando cosi' il comportamento storico "click ovunque sulla
      riga apre/chiude", indipendentemente dal fatto che
      FWrapLongLabels sia True o False.

  "LBTVRow" (presente SOLO quando FWrapLongLabels = True): un click qui
  e' SEMPRE un click sul glifo del caret (mai sul testo, che vive dentro
  "LBTVLabel", figlio di "LBTVRow") - risale SEMPRE di un livello al vero
  span del nodo, INDIPENDENTEMENTE da FOnlyCaretToggles: il glifo deve
  poter sempre aprire/chiudere il ramo, quale che sia il valore di quella
  proprieta' (che riguarda esclusivamente il TESTO).

  Quando NE' FWrapLongLabels NE' FOnlyCaretToggles sono attive: nessun
  wrapper "LBTVLabel"/"LBTVRow" esiste nel markup - un click sul testo
  grezzo dell'etichetta produce lo STESSO target dello span esterno
  ("LBTVCaret"/"LBTVEmptyCaret" stesso): il comportamento e' quindi
  quello storico per costruzione (nessuna distinzione possibile ne'
  necessaria), col bugfix di base comunque sempre applicato.

  Nessuna modifica a doManageCaret/doManageCheckbox: ricevono esattamente
  lo stesso tipo di elemento di prima, solo risolto con un percorso di
  risalita piu' preciso.
}
var
  _target: TJSElement;
begin
  Result := False;
  _target := TJSElement(Event.targetElement);

  while hasValue(_target) and (_target <> Event.currentTargetElement) do
  begin
    if _target.classList.contains('LBTVCheckbox') then
    begin
      Event.stopImmediatePropagation;
      Result := doManageCheckbox(_target);
      Exit;
    end;

    if _target.classList.contains('LBTVLabel') then
    begin
      if FOnlyCaretToggles then
        Exit; // click sul testo: nessuna azione, SOLO se richiesto
              // esplicitamente. Altrimenti (False): nessuna azione QUI,
              // si prosegue la risalita in fondo al ciclo, esattamente
              // come se questo wrapper non esistesse ai fini del click -
              // vedi il commento esteso sopra.
    end
    else if _target.classList.contains('LBTVRow') then
    begin
      // Sempre un click sul glifo del caret (mai sul testo) - risale
      // sempre di un livello, indipendentemente da FOnlyCaretToggles.
      _target := _target.parentElement;
      Continue;
    end
    else if _target.classList.contains('LBTVCaret') then
    begin
      Event.stopImmediatePropagation;
      Result := doManageCaret(_target);
      Exit;
    end
    else if _target.classList.contains('LBTVEmptyCaret') then
      Exit // confine di un nodo FOGLIA: nulla da aprire/chiudere -
           // FERMA SEMPRE qui la risalita (bugfix di base)
    else if (_target.tagName = 'LI') or _target.classList.contains('LBTVNested') then
      Exit; // spazio non coperto da alcun elemento interno: nessuna azione

    _target := _target.parentElement;
  end;
end;

function TLBjsTreeView.manageContextMenu(Event: TJSMouseEvent): boolean;
var
  _targetLi: TJSElement;
  _item: TJSObject;
  _itemIdx: Integer;
begin
  Result := True;
  if not hasValue(FContextMenuCallback) then Exit;

  Event.preventDefault;
  Event.stopPropagation;

  _targetLi := Event.targetElement;
  while hasValue(_targetLi) and (_targetLi.tagName <> 'LI') do
    _targetLi := _targetLi.parentElement;

  _item := nil;
  if hasValue(_targetLi) then
  begin
    _itemIdx := StrToIntDef(String(TJSObject(_targetLi.Properties['dataset'])['itemIdx']), -1);
    if _itemIdx >= 0 then
      _item := Self.Item[_itemIdx];
  end;

  Self.showContextMenu(Trunc(Event.clientX), Trunc(Event.clientY), _item);
end;

procedure TLBjsTreeView.renderData();
begin
  FFlatList := TJSArray.new;
  FCheckedList := TJSArray.new;
  FCheckedElems := TJSArray.new;
  FItemIdx := 0;

  if (FDestElem <> nil) then
  begin
    FDestElem.innerHTML := Self.renderWrapper(Self.insertArray(FData, 0, nil));

    // Rimuove i listener precedenti se esistono (evita accumulo a ogni renderData)
    if hasValue(FClickHandler) then
      TJSElement(FDestElem).removeEventListener('click', FClickHandler);
    if hasValue(FContextMenuHandler) then
      TJSElement(FDestElem).removeEventListener('contextmenu', FContextMenuHandler);

    FClickHandler := @manageTreeViewClick;
    FDestElem.addEventListener('click', FClickHandler);

    // Il listener e' sempre registrato: manageContextMenu esce subito
    // se FContextMenuCallback non e' ancora impostata (puo' essere impostata dopo renderData)
    FContextMenuHandler := @manageContextMenu;
    FDestElem.addEventListener('contextmenu', FContextMenuHandler);
  end;

  Self.setChecked(-1, false);

  if hasValue(FItemsToSelect) then
  begin
    Self.select(FItemsToSelect);
    FItemsToSelect := nil;
  end;

  // rami da riaprire (setExpandedIds): valgono per UN solo disegno
  if hasValue(FIdsToExpand) then
  begin
    Self.applyExpanded(FIdsToExpand);
    FIdsToExpand := nil;
  end;
end;

procedure TLBjsTreeView.hideContextMenu;
begin
  if hasValue(FContextMenuElement) then
  begin
    FContextMenuElement.remove;
    FContextMenuElement := nil;
  end;
end;

{ Posiziona il menu (gia' nel documento, in position: fixed) in modo che stia TUTTO nella finestra visibile.
  Prima il menu si apriva sempre con l'angolo in alto a sinistra sul punto del clic: vicino al margine inferiore (o
  destro) usciva dallo schermo e le ultime voci non si raggiungevano.
  - In VERTICALE: se sotto il punto non c'e' posto per tutto il menu, si apre VERSO L'ALTO (il bordo basso del menu
    sul punto del clic); se non entra nemmeno sopra, lo si appoggia al margine inferiore.
  - In ORIZZONTALE: stessa regola, verso sinistra.
  - Un menu piu' alto della finestra (molte voci, schermo basso) prende l'altezza della finestra e scorre al suo interno.
  Vale per tutti i consumatori del componente: un menu che entra nella finestra resta dov'e' sempre stato. }
procedure TLBjsTreeView.fitContextMenu(aMenu: TJSHTMLElement; X, Y: Integer);
const
  cMenuMargin = 8;   // distanza minima dai bordi della finestra
var
  _VW, _VH   : Integer;
  _W, _H     : Integer;
  _Left, _Top: Integer;
  _Avail     : Integer;
begin
  _VW := Integer(window.innerWidth);
  _VH := Integer(window.innerHeight);
  _W := Round(aMenu.offsetWidth);
  _H := Round(aMenu.offsetHeight);

  // piu' alto della finestra: altezza massima e scorrimento interno
  _Avail := _VH - 2 * cMenuMargin;
  if _H > _Avail then
  begin
    aMenu.style.setProperty('max-height', IntToStr(_Avail) + 'px');
    aMenu.style.setProperty('overflow-y', 'auto');
    _H := _Avail;
  end;

  // verticale
  _Top := Y;
  if _Top + _H > _VH - cMenuMargin then
  begin
    if Y - _H >= cMenuMargin then
      _Top := Y - _H                       // verso l'alto: il bordo basso del menu sul punto del clic
    else
      _Top := _VH - cMenuMargin - _H;      // non entra ne' sopra ne' sotto: contro il margine inferiore
  end;
  if _Top < cMenuMargin then
    _Top := cMenuMargin;

  // orizzontale
  _Left := X;
  if _Left + _W > _VW - cMenuMargin then
  begin
    if X - _W >= cMenuMargin then
      _Left := X - _W                      // verso sinistra
    else
      _Left := _VW - cMenuMargin - _W;
  end;
  if _Left < cMenuMargin then
    _Left := cMenuMargin;

  aMenu.style.setProperty('left', IntToStr(_Left) + 'px');
  aMenu.style.setProperty('top', IntToStr(_Top) + 'px');
end;

procedure TLBjsTreeView.showContextMenu(X, Y: Integer; aItem: TJSObject);
var
  _menuItems: TJSArray;

  function executeItemCallback(Event: TJSEvent): boolean;
  var
    _idx: Integer;
    _item: TLBTreeViewMenuItem;
  begin
    Result := True;
    Event.stopPropagation;
    _idx := StrToIntDef(String(TJSObject(Event.currentTargetElement.Properties['dataset'])['menuIdx']), -1);
    if (_idx >= 0) and (_idx < _menuItems.Length) then
    begin
      _item := TLBTreeViewMenuItem(_menuItems.Elements[_idx]);
      if hasValue(_item.Callback) then
        _item.Callback(aItem);
    end;
    Self.hideContextMenu;
  end;

  function hidePopupMenu(Event: TJSEvent): Boolean;
  begin
    Result := True;
    Self.hideContextMenu;
  end;

var
  _menuDiv: TJSHTMLElement;
  _menuItemDiv: TJSHTMLElement;
  _menuItem: TLBTreeViewMenuItem;
  i: Integer;
  _html: String;
  _opts : TJSEventListenerOptions;
  _hasIcons : Boolean;
  _itemClass : String;
  _prevGroup : String;

begin
  Self.hideContextMenu;

  if not hasValue(FContextMenuCallback) then
    Exit;

  _menuItems := FContextMenuCallback(aItem);

  if not hasValue(_menuItems) or (_menuItems.Length = 0) then
    Exit;

  _menuDiv := TJSHTMLElement(document.createElement('div'));
  _menuDiv.id := 'LBTVContextMenu_' + FDestElemId;
  _menuDiv.className := 'LBTVContextMenu';
  _menuDiv.style.setProperty('position', 'fixed');
  _menuDiv.style.setProperty('left', IntToStr(X) + 'px');
  _menuDiv.style.setProperty('top', IntToStr(Y) + 'px');
  _menuDiv.style.setProperty('z-index', '10000');

  // icone, separatori e voci "pericolose" (OPT-IN, vedi TLBTreeViewMenuItem): senza, l'HTML e' quello di sempre
  _hasIcons := False;
  for i := 0 to _menuItems.Length - 1 do
    if TLBTreeViewMenuItem(_menuItems.Elements[i]).IconClass <> '' then
    begin
      _hasIcons := True;
      Break;
    end;
  if _hasIcons then
    _menuDiv.className := 'LBTVContextMenu LBTVContextMenu-Icons';
  _html := '';
  _prevGroup := '';
  for i := 0 to _menuItems.Length - 1 do
  begin
    _menuItem := TLBTreeViewMenuItem(_menuItems.Elements[i]);
    _itemClass := 'LBTVContextMenuItem';
    if (i > 0) and (_menuItem.Group <> _prevGroup) then
      _itemClass += ' LBTVContextMenuItem-Sep';
    if _menuItem.Danger then
      _itemClass += ' LBTVContextMenuItem-Danger';
    _prevGroup := _menuItem.Group;
    _html += '<div class="' + _itemClass + '" data-menu-idx="' + IntToStr(i) + '">';
    if _hasIcons then
      _html += '<span class="LBTVContextMenuIcon ' + _menuItem.IconClass + '" aria-hidden="true"></span>' +
               '<span class="LBTVContextMenuCaption">' + Self.labelHtml(_menuItem.Caption) + '</span>'
    else
      _html += Self.labelHtml(_menuItem.Caption);
    _html += '</div>';
  end;

  _menuDiv.innerHTML := _html;
  document.body.appendChild(_menuDiv);
  FContextMenuElement := _menuDiv;
  // ora che ha le sue dimensioni: si sposta se uscirebbe dalla finestra (verso l'alto / sinistra)
  Self.fitContextMenu(_menuDiv, X, Y);

  for i := 0 to _menuItems.Length - 1 do
  begin
    _menuItemDiv := TJSHTMLElement(_menuDiv.children.item(i));
    _menuItem := TLBTreeViewMenuItem(_menuItems.Elements[i]);
    _menuItemDiv.addEventListener('click', @executeItemCallback);
  end;

  _opts := TJSEventListenerOptions.new;
  _opts.once := True;
  document.addEventListener('click', @hidePopupMenu, _opts);
end;

procedure TLBjsTreeView.select(anIdList: TJSArray);
var
  i : Integer;
  _Id : String;
  _Checked : Boolean;
  _ElemId : String;
  _Element : TJSElement;
  _prevElem : TJSElement;

begin
  if hasValue(FFlatList) then
  begin
    if hasValue(anIdList) then
    begin
      for i := 0 to FFlatList.Length - 1 do
      begin
        _Id := String(TJSObject(FFlatList.Elements[i]).Properties[FIdProperty]);
        _Checked := anIdList.includes(_Id);

        if FSingleSelect then
        begin
          if _Checked then
          begin
            _ElemId := FDestElemId + '_' + IntToStr(i);
            _Element := TJSElement(document.getElementById(_ElemId));

            if FCheckedElems.Length > 0 then
            begin
              _prevElem := TJSElement(FCheckedElems.Elements[0]);
              if _prevElem <> _Element then
              begin
                _prevElem.classList.remove('LBTVCheckbox-Checked');
                TJSObject(FCheckedList.Elements[0]).Properties['LBTV_Selected'] := False;
                FCheckedList.splice(0, 1);
                FCheckedElems.splice(0, 1);
              end;
            end;

            if hasValue(_Element) then
            begin
              _Element.classList.add('LBTVCheckbox-Checked');
              FCheckedElems.push(_Element);
            end;
            Self.setChecked(i, True);

            Break;
          end;
        end
        else
        begin
          _ElemId := FDestElemId + '_' + IntToStr(i);
          _Element := TJSElement(document.getElementById(_ElemId));
          if hasValue(_Element) then
          begin
            if _Checked then
            begin
              if not _Element.classList.contains('LBTVCheckbox-Checked') then
              begin
                _Element.classList.add('LBTVCheckbox-Checked');
                if FCheckedElems.indexOf(_Element) = -1 then
                  FCheckedElems.push(_Element);
              end;
            end
            else begin
              if _Element.classList.contains('LBTVCheckbox-Checked') then
              begin
                _Element.classList.remove('LBTVCheckbox-Checked');
                FCheckedElems.splice(FCheckedElems.indexOf(_Element), 1);
              end;
            end;
          end;
          Self.setChecked(i, _Checked);
        end;
      end;
    end;
  end
  else
    FItemsToSelect := anIdList;
end;

procedure TLBjsTreeView.setChecked(anItemIdx: Integer; isChecked: Boolean);
var
  _Item : TJSObject;
  _Idx : Integer;

begin
  _Item := Self.Item[anItemIdx];
  if _Item <> nil then
  begin
    _Item.Properties['LBTV_Selected'] := isChecked;
    _Idx := FCheckedList.indexOf(_Item);

    if isChecked then
    begin
      if _Idx = -1 then
        FCheckedList.push(_Item)
    end
    else begin
      if _Idx > -1 then
        FCheckedList.splice(_Idx, 1);
    end;
  end;
end;

procedure TLBjsTreeView.uncheckItems();
var
  i : Integer;
  _Element : TJSElement;

begin
  FItemsToSelect := TJSArray.new;

  if hasValue(FCheckedElems) then
  begin
    for i := 0 to FCheckedElems.Length - 1 do
    begin
      _Element := TJSElement(FCheckedElems.Elements[i]);
      if hasValue(_Element) then
        _Element.classList.remove('LBTVCheckbox-Checked');
    end;
  end;

  FCheckedElems := TJSArray.new;
  FCheckedList := TJSArray.new;
end;

procedure TLBjsTreeView.setContextMenuCallback(aCallback: TLBTreeViewMenuCallback);
begin
  FContextMenuCallback := aCallback;
end;

end.
