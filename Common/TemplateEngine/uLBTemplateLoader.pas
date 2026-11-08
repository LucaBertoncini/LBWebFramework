unit uLBTemplateLoader;
(*
  Caricamento dei modelli HTML come TESTO, con cache, da usare insieme a
  TemplateEngine.

  Un modello con segnaposto dentro i tag (data-id="{{id}}") non va mai
  inserito nella pagina prima del rendering: il parser HTML lo deformerebbe.
  Va letto come testo (fetch + .text()), reso con RenderTemplate e solo
  dopo assegnato a innerHTML. Queste due funzioni fanno la prima parte.

    LoadTemplate(path)          testo di un file, con cache per percorso
    LoadTemplateSections(path)  un file con PIU' modelli, ciascuno introdotto
                                da una riga  <!-- @nome -->  ->  oggetto
                                nome -> testo, pronto per
                                RenderTemplateWithPartials

  Entrambe NON sollevano eccezioni: se il file non si trova (o la rete
  fallisce) segnalano in console e restituiscono '' / un oggetto vuoto, e
  l'insuccesso non viene messo in cache (la chiamata successiva riprova).
*)

{$mode ObjFPC}{$H+}

interface

uses
  JS, Web, SysUtils;

function LoadTemplate(const aPath: String): String; async;
function LoadTemplateSections(const aPath: String): TJSObject; async;

// Svuota la cache (utile se i modelli cambiano durante la sessione).
procedure ClearTemplateCache;

// Suddivide un testo in sezioni <!-- @nome -->. Esposta per i test e per chi
// ha gia' il testo; il testo prima della prima marca viene ignorato.
function SplitTemplateSections(const aText: String): TJSObject;

implementation

var
  gv_TextCache: TJSObject = nil;
  gv_SectionsCache: TJSObject = nil;

procedure EnsureCaches;
begin
  if gv_TextCache = nil then
    gv_TextCache := TJSObject.new;
  if gv_SectionsCache = nil then
    gv_SectionsCache := TJSObject.new;
end;

procedure ClearTemplateCache;
begin
  gv_TextCache := TJSObject.new;
  gv_SectionsCache := TJSObject.new;
end;

function SplitTemplateSections(const aText: String): TJSObject;
begin
  Result := TJSObject.new;
  asm
    var re = /<!--\s*@([A-Za-z0-9_\-]+)\s*-->/g;
    var m, name = null, from = 0;
    while ((m = re.exec(aText)) !== null) {
      if (name !== null) Result[name] = aText.substring(from, m.index).trim();
      name = m[1];
      from = re.lastIndex;
    }
    if (name !== null) Result[name] = aText.substring(from).trim();
  end;
end;

function LoadTemplate(const aPath: String): String;
var
  _Response: TJSResponse;
begin
  Result := '';
  EnsureCaches;

  if gv_TextCache.hasOwnProperty(aPath) then
  begin
    Result := String(gv_TextCache.Properties[aPath]);
    Exit;
  end;

  try
    _Response := AWait(TJSResponse, window.fetch(aPath));
    if _Response.ok then
    begin
      Result := AWait(String, _Response.text());
      gv_TextCache.Properties[aPath] := Result;
    end
    else
      console.warn('LoadTemplate: impossibile caricare <' + aPath + '> (codice ' +
        IntToStr(_Response.status) + ')');
  except
    on E: Exception do
      console.error('LoadTemplate: errore nel caricamento di <' + aPath + '>: ' + E.Message);
  end;
end;

function LoadTemplateSections(const aPath: String): TJSObject;
var
  _Text: String;
begin
  EnsureCaches;

  if gv_SectionsCache.hasOwnProperty(aPath) then
  begin
    Result := TJSObject(gv_SectionsCache.Properties[aPath]);
    Exit;
  end;

  _Text := AWait(String, LoadTemplate(aPath));
  Result := SplitTemplateSections(_Text);

  // Solo un risultato non vuoto entra in cache: un file mancante o vuoto
  // verra' ritentato alla chiamata successiva.
  if _Text <> '' then
    gv_SectionsCache.Properties[aPath] := Result;
end;

end.
