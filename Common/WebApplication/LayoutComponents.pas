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
    FResizeHandler   : TJSRawEventHandler;
    procedure HandleResize(aEvent: TJSEvent);

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
    // Schermo diventato piccolo: nasconde sempre.
    if FIsVisible then
      Self.Hide;
  end
  else
  begin
    // Schermo diventato grande: mostra solo se ha già il contenuto caricato.
    // Se il contenuto non è ancora caricato, Show non farà nulla (HasContent=False).
    if not FIsVisible then
      Self.Show;
  end;
end;

procedure TSideColumnComponent.Show;
begin
  if (FRootElement <> nil) and (Self.HasContent) and (not FIsVisible) then
  begin
    FRootElement.classList.remove('hidden');
    FIsVisible := True;
    if gv_EventsManager <> nil then
      gv_EventsManager.RaiseEvent('layout:column-toggled', FRootElement);
  end;
end;

procedure TSideColumnComponent.Hide;
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
