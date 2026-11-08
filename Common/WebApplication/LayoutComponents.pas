unit LayoutComponents;

interface

uses
  Web, WebComponent, SysUtils;

type

  { TLayoutComponent }
  // Classe "marker": non aggiunge membri rispetto a TWebComponent (LoadContent
  // e HasContent sono gia' ereditati da li'), ma resta volutamente distinta
  // per vincolare a livello di COMPILATORE quali classi possono essere
  // passate come header/footer/colonne a TWebApplication.Create (vedi
  // TLayoutComponentClass e WebApplication.pas). Senza questo tipo
  // intermedio, il compilatore accetterebbe in quegli slot qualsiasi
  // discendente di TWebComponent (es. un dialogo, un TCMMSAssetTree),
  // perdendo la garanzia statica che quelle quattro classi siano
  // effettivamente pensate per rappresentare una delle aree fisse del
  // layout (header, footer, colonna sinistra/destra).
  TLayoutComponent = class(TWebComponent)
  end;

  TLayoutComponentClass = class of TLayoutComponent;

  THeaderComponent = class(TLayoutComponent);
  THeaderComponentClass = class of THeaderComponent;

  TFooterComponent = class(TLayoutComponent);
  TFooterComponentClass = class of TFooterComponent;

  TSideColumnComponent = class(TLayoutComponent)
  private
    FIsVisible       : Boolean;
    // True solo se e' il CODICE APPLICATIVO a nascondere la colonna (Hide):
    // in quel caso il ridimensionamento della finestra non deve rimostrarla.
    // Il nascondimento automatico sotto MOBILE_BREAKPOINT non lo imposta.
    FHiddenByApp     : Boolean;
    FResizeHandler   : TJSRawEventHandler;
    procedure HandleResize(aEvent: TJSEvent);
    procedure DoShow;
    procedure DoHide;

  public
    constructor Create(aRootElement: TJSHTMLElement); override;
    destructor Destroy; override;

    procedure Show;
    procedure Hide;
    procedure Toggle;
    property IsVisible: Boolean read FIsVisible;
  end;

implementation

uses
  EventsManager;

const
  MOBILE_BREAKPOINT = 768;

{ TSideColumnComponent }

constructor TSideColumnComponent.Create(aRootElement: TJSHTMLElement);
begin
  inherited Create(aRootElement);

  FHiddenByApp := False;
  FIsVisible := False; // Il contenuto è sempre dinamico: inizia sempre nascosta.

  if FRootElement <> nil then
  begin
    // Forza lo stato nascosto nel DOM, indipendentemente da quanto c'è in index.html.
    FRootElement.classList.add('hidden');

    // Registra il listener per il resize e conserva il riferimento per poterlo
    // rimuovere nel distruttore.
    FResizeHandler := @Self.HandleResize;
    window.addEventListener('resize', FResizeHandler);
  end;
end;

destructor TSideColumnComponent.Destroy;
begin
  // FIX: rimuove il listener per evitare chiamate su oggetto già distrutto.
  if FResizeHandler <> nil then
  begin
    window.removeEventListener('resize', FResizeHandler);
    FResizeHandler := nil;
  end;
  inherited Destroy;
end;

procedure TSideColumnComponent.HandleResize(aEvent: TJSEvent);
begin
  if window.innerWidth < MOBILE_BREAKPOINT then
  begin
    // Schermo diventato piccolo: nasconde sempre (senza segnare la
    // colonna come nascosta dall'applicazione).
    if FIsVisible then
      Self.DoHide;
  end
  else
  begin
    // Schermo diventato grande: mostra solo se ha già il contenuto caricato
    // e solo se l'applicazione non l'ha nascosta di proposito.
    if (not FIsVisible) and (not FHiddenByApp) then
      Self.DoShow;
  end;
end;

procedure TSideColumnComponent.Show;
begin
  FHiddenByApp := False;
  Self.DoShow;
end;

procedure TSideColumnComponent.Hide;
begin
  FHiddenByApp := True;
  Self.DoHide;
end;

procedure TSideColumnComponent.DoShow;
begin
  if (FRootElement <> nil) and (Self.HasContent) and (not FIsVisible) then
  begin
    FRootElement.classList.remove('hidden');
    FIsVisible := True;
    if gv_EventsManager <> nil then
      gv_EventsManager.RaiseEvent('layout:column-toggled', FRootElement);
  end;
end;

procedure TSideColumnComponent.DoHide;
begin
  if (FRootElement <> nil) and (FIsVisible) then
  begin
    FRootElement.classList.add('hidden');
    FIsVisible := False;
    if gv_EventsManager <> nil then
      gv_EventsManager.RaiseEvent('layout:column-toggled', FRootElement);
  end;
end;

procedure TSideColumnComponent.Toggle;
begin
  if FIsVisible then Self.Hide else Self.Show;
end;

end.
