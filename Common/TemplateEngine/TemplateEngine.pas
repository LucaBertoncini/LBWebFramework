unit TemplateEngine;
(*
  Motore di template minimale.

  SINTASSI
  ----------------------------------------------------------------------
    {{campo}}                valore, con escape HTML (TextToHTML); dentro un tag,
                             cioe' in un valore di attributo, l'escape e'
                             HtmlEncode senza conversione degli a-capo
    {{oggetto.campo}}        percorso con punti
    {{{campo}}}              valore SENZA escape (solo per HTML gia' sicuro:
                             vedi la nota in fondo)
    {{this}}                 l'elemento corrente (utile per elenchi di stringhe)
    {{../campo}}             campo dell'ambito genitore (uno ../ per livello)
    {{#each elenco}} ... {{/each}}
    {{#each elenco}} ... {{else}} ... {{/each}}   {{else}}: elenco vuoto o assente
    {{#if campo}} ... {{/if}}
    {{#if campo}} ... {{else}} ... {{/if}}
    {{#unless campo}} ... {{/unless}}             (anche con {{else}})
    {{> nome}}               frammento (partial) con lo stesso ambito: serve per
                             le strutture ricorsive (alberi). I frammenti si
                             passano a RenderTemplateWithPartials come oggetto
                             nome -> testo del modello.

  I blocchi si annidano liberamente (each dentro each, if dentro each, ...).
  Dentro un each i nomi si risolvono SOLO nell'elemento corrente: per un campo
  del genitore si usa ../campo. Un nome mancante vale stringa vuota.

  VERITA' (#if / #unless)
  ----------------------------------------------------------------------
  Falso: assente, null, false, 0, '' (stringa vuota) e array vuoto. Vero tutto
  il resto, compresa la stringa 'false' e qualunque oggetto.

  COMPATIBILITA'
  ----------------------------------------------------------------------
  I modelli scritti per la versione precedente (solo {{campo}} e un livello di
  {{#each}}) producono lo stesso risultato. Cambia un solo caso limite: un
  valore che contiene a sua volta "{{x}}" non viene piu' rielaborato (prima una
  seconda passata lo poteva sostituire).

  SICUREZZA
  ----------------------------------------------------------------------
  {{campo}} esegue sempre l'escape. {{{campo}}} no: usarlo solo per HTML
  prodotto dall'applicazione stessa (mai per testo che arriva dall'utente o dal
  server), altrimenti si apre la porta all'iniezione di markup.
  Un modello con segnaposto dentro i tag NON va mai inserito nella pagina prima
  del rendering: va letto come testo (fetch + .text()).

  Profondita' massima di annidamento (blocchi + frammenti): 32, oltre la quale
  il ramo viene troncato (protezione da frammenti che richiamano se stessi senza
  un elenco che si esaurisca).
*)

interface

uses
  JS, SysUtils;

function RenderTemplate(const aTemplate: string; const aData: TJSObject): string;

// Come RenderTemplate, con i frammenti richiamabili da {{> nome}}: aPartials e'
// un oggetto nome -> testo del modello (per esempio quello restituito da
// LoadTemplateSections di uLBTemplateLoader). Puo' essere nil.
function RenderTemplateWithPartials(const aTemplate: string; const aData: TJSObject;
  const aPartials: TJSObject): string;

implementation

uses
  uLBWebUtils;

const
  cMaxDepth = 32;

function StartsWithText(const aText, aPrefix: string): Boolean;
begin
  Result := TJSString(aText).substring(0, Length(aPrefix)) = aPrefix;
end;

// True se la posizione corrente dell'output cade DENTRO un tag HTML (tra un
// '<' e il '>' che lo chiude), cioe' in un valore di attributo. Si guarda solo
// il piu' vicino fra '<' e '>' gia' prodotti: i valori inseriti sono sempre
// escapati, quindi nell'output reso un '<' o '>' viene solo dal modello.
function IsInsideTag(const aOutput: string): Boolean;
begin
  Result := TJSString(aOutput).lastIndexOf('<') > TJSString(aOutput).lastIndexOf('>');
end;

// Percorso con punti dentro un oggetto. nil se manca un passaggio.
function GetValueFromPath(const aObject: TJSObject; const aPath: string): JSValue;
var
  _Parts: TStringArray;
  _CurrentObj: JSValue;
  _i: Integer;
  _propName: string;
begin
  Result := nil;
  if (aObject = nil) or (aPath = '') then Exit;
  _Parts := aPath.Split(['.']);
  _CurrentObj := aObject;
  for _i := 0 to High(_Parts) do
  begin
    _propName := _Parts[_i];
    if (_CurrentObj = nil) or (not TJSObject(_CurrentObj).HasOwnProperty(_propName)) then
      Exit(nil);
    _CurrentObj := TJSObject(_CurrentObj).Properties[_propName];
  end;
  Result := _CurrentObj;
end;

// Risolve aPath rispetto alla pila degli ambiti: "../" sale di un livello,
// "this" e' l'elemento corrente.
function ScopeValue(aScopes: TJSArray; const aPath: string): JSValue;
var
  _Path: string;
  _Up: Integer;
  _Idx: Integer;
  _Cur: JSValue;
begin
  Result := nil;
  _Path := aPath;
  _Up := 0;
  while StartsWithText(_Path, '../') do
  begin
    Inc(_Up);
    _Path := TJSString(_Path).substring(3);
  end;
  _Idx := aScopes.length - 1 - _Up;
  if _Idx < 0 then Exit;
  _Cur := aScopes[_Idx];
  if _Path = 'this' then
  begin
    Result := _Cur;
    Exit;
  end;
  if StartsWithText(_Path, 'this.') then
    _Path := TJSString(_Path).substring(5);
  if (_Path = '') or (not isDefined(_Cur)) then Exit;
  Result := GetValueFromPath(TJSObject(_Cur), _Path);
end;

function IsTruthy(const aValue: JSValue): Boolean;
begin
  if not isDefined(aValue) then
    Result := False
  else if isBoolean(aValue) then
    Result := Boolean(aValue)
  else if isString(aValue) then
    Result := String(aValue) <> ''
  else if isNumber(aValue) then
    Result := Double(aValue) <> 0
  else if TJSArray.isArray(TJSObject(aValue)) then
    Result := TJSArray(aValue).length > 0
  else
    Result := True;
end;

function IsPathText(const aText: string): Boolean;
var
  i: Integer;
  c: string;
begin
  Result := aText <> '';
  for i := 0 to Length(aText) - 1 do
  begin
    c := TJSString(aText).charAt(i);
    if not (((c >= 'a') and (c <= 'z')) or ((c >= 'A') and (c <= 'Z')) or
            ((c >= '0') and (c <= '9')) or (c = '_') or (c = '.') or (c = '/')) then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

// Cerca la chiusura del blocco il cui tag di apertura finisce in aFrom. Tiene
// conto dei blocchi annidati. aElse = inizio e aElseAfter = fine del {{else}} di
// primo livello (-1 se manca); aEnd = inizio e aEndAfter = fine del tag di chiusura.
function FindBlockEnd(const aTpl: string; aFrom: NativeInt;
  out aElse, aElseAfter, aEnd, aEndAfter: NativeInt): Boolean;
var
  _Depth: Integer;
  _Pos, _Open, _Close: NativeInt;
  _Tag: string;
begin
  Result := False;
  aElse := -1;
  aElseAfter := -1;
  aEnd := -1;
  aEndAfter := -1;
  _Depth := 1;
  _Pos := aFrom;
  while True do
  begin
    _Open := TJSString(aTpl).indexOf('{{', _Pos);
    if _Open < 0 then Exit;
    _Close := TJSString(aTpl).indexOf('}}', _Open + 2);
    if _Close < 0 then Exit;
    _Tag := Trim(TJSString(aTpl).substring(_Open + 2, _Close));
    if StartsWithText(_Tag, '#each ') or StartsWithText(_Tag, '#if ') or
       StartsWithText(_Tag, '#unless ') then
      Inc(_Depth)
    else if (_Tag = '/each') or (_Tag = '/if') or (_Tag = '/unless') then
    begin
      Dec(_Depth);
      if _Depth = 0 then
      begin
        aEnd := _Open;
        aEndAfter := _Close + 2;
        Result := True;
        Exit;
      end;
    end
    else if (_Tag = 'else') and (_Depth = 1) and (aElse < 0) then
    begin
      aElse := _Open;
      aElseAfter := _Close + 2;
    end;
    _Pos := _Close + 2;
  end;
end;

function RenderScoped(const aTpl: string; aScopes: TJSArray; const aPartials: TJSObject;
  aDepth: Integer): string; forward;

// Rende un blocco (each / if / unless) gia' delimitato.
function RenderBlock(const aKind, aArg, aBody, aElseBody: string; aHasElse: Boolean;
  aScopes: TJSArray; const aPartials: TJSObject; aDepth: Integer): string;
var
  _Value: JSValue;
  _Arr: TJSArray;
  _k: Integer;
begin
  Result := '';
  _Value := ScopeValue(aScopes, aArg);
  if aKind = 'each' then
  begin
    if isDefined(_Value) and TJSArray.isArray(TJSObject(_Value)) and (TJSArray(_Value).length > 0) then
    begin
      _Arr := TJSArray(_Value);
      for _k := 0 to _Arr.length - 1 do
      begin
        aScopes.push(_Arr[_k]);
        Result := Result + RenderScoped(aBody, aScopes, aPartials, aDepth + 1);
        aScopes.pop;
      end;
    end
    else if aHasElse then
      Result := RenderScoped(aElseBody, aScopes, aPartials, aDepth + 1);
  end
  else if aKind = 'if' then
  begin
    if IsTruthy(_Value) then
      Result := RenderScoped(aBody, aScopes, aPartials, aDepth + 1)
    else if aHasElse then
      Result := RenderScoped(aElseBody, aScopes, aPartials, aDepth + 1);
  end
  else
  begin
    // unless
    if not IsTruthy(_Value) then
      Result := RenderScoped(aBody, aScopes, aPartials, aDepth + 1)
    else if aHasElse then
      Result := RenderScoped(aElseBody, aScopes, aPartials, aDepth + 1);
  end;
end;

function RenderScoped(const aTpl: string; aScopes: TJSArray; const aPartials: TJSObject;
  aDepth: Integer): string;
var
  _Pos, _Open, _Close, _After: NativeInt;
  _ElseAt, _ElseAfter, _EndAt, _EndAfter: NativeInt;
  _Tag, _Kind, _Arg, _Body, _ElseBody, _Name: string;
  _Value: JSValue;
  _HasElse: Boolean;
begin
  Result := '';
  if aDepth > cMaxDepth then Exit;
  _Pos := 0;
  while _Pos < Length(aTpl) do
  begin
    _Open := TJSString(aTpl).indexOf('{{', _Pos);
    if _Open < 0 then
    begin
      Result := Result + TJSString(aTpl).substring(_Pos);
      Break;
    end;
    Result := Result + TJSString(aTpl).substring(_Pos, _Open);

    // {{{campo}}}: senza escape
    if TJSString(aTpl).substring(_Open, _Open + 3) = '{{{' then
    begin
      _Close := TJSString(aTpl).indexOf('}}}', _Open + 3);
      if _Close < 0 then
      begin
        Result := Result + TJSString(aTpl).substring(_Open);
        Break;
      end;
      _Arg := Trim(TJSString(aTpl).substring(_Open + 3, _Close));
      if IsPathText(_Arg) then
      begin
        _Value := ScopeValue(aScopes, _Arg);
        if isDefined(_Value) then
          Result := Result + String(_Value);
      end
      else
        Result := Result + TJSString(aTpl).substring(_Open, _Close + 3);
      _Pos := _Close + 3;
      Continue;
    end;

    _Close := TJSString(aTpl).indexOf('}}', _Open + 2);
    if _Close < 0 then
    begin
      Result := Result + TJSString(aTpl).substring(_Open);
      Break;
    end;
    _After := _Close + 2;
    _Tag := Trim(TJSString(aTpl).substring(_Open + 2, _Close));

    // blocchi
    _Kind := '';
    if StartsWithText(_Tag, '#each ') then _Kind := 'each'
    else if StartsWithText(_Tag, '#if ') then _Kind := 'if'
    else if StartsWithText(_Tag, '#unless ') then _Kind := 'unless';
    if _Kind <> '' then
    begin
      _Arg := Trim(TJSString(_Tag).substring(Length(_Kind) + 1));
      if FindBlockEnd(aTpl, _After, _ElseAt, _ElseAfter, _EndAt, _EndAfter) then
      begin
        _HasElse := _ElseAt >= 0;
        if _HasElse then
        begin
          _Body := TJSString(aTpl).substring(_After, _ElseAt);
          _ElseBody := TJSString(aTpl).substring(_ElseAfter, _EndAt);
        end
        else
        begin
          _Body := TJSString(aTpl).substring(_After, _EndAt);
          _ElseBody := '';
        end;
        Result := Result + RenderBlock(_Kind, _Arg, _Body, _ElseBody, _HasElse,
          aScopes, aPartials, aDepth);
        _Pos := _EndAfter;
      end
      else
      begin
        // blocco non chiuso: il tag resta com'e'
        Result := Result + TJSString(aTpl).substring(_Open, _After);
        _Pos := _After;
      end;
      Continue;
    end;

    // frammento
    if StartsWithText(_Tag, '> ') then
    begin
      _Name := Trim(TJSString(_Tag).substring(2));
      if isDefined(aPartials) and aPartials.hasOwnProperty(_Name) then
        Result := Result + RenderScoped(String(aPartials.Properties[_Name]), aScopes,
          aPartials, aDepth + 1);
      _Pos := _After;
      Continue;
    end;

    // valore con escape ('else' e le chiusure /x fuori posto non sono nomi di campo)
    if IsPathText(_Tag) and (_Tag <> 'else') and (not StartsWithText(_Tag, '/')) then
    begin
      _Value := ScopeValue(aScopes, _Tag);
      if isDefined(_Value) then
      begin
        // In un attributo (value="{{x}}", title="{{x}}") un a-capo convertito
        // in <br/> comparirebbe come testo letterale: li' si fa il solo escape.
        if IsInsideTag(Result) then
          Result := Result + HtmlEncode(String(_Value))
        else
          Result := Result + TextToHTML(String(_Value));
      end;
    end
    else
      // tag non riconosciuto (o {{else}} / {{/x}} fuori posto): resta com'e'
      Result := Result + TJSString(aTpl).substring(_Open, _After);
    _Pos := _After;
  end;
end;

function RenderTemplateWithPartials(const aTemplate: string; const aData: TJSObject;
  const aPartials: TJSObject): string;
var
  _Scopes: TJSArray;
begin
  _Scopes := TJSArray.new;
  _Scopes.push(aData);
  Result := RenderScoped(aTemplate, _Scopes, aPartials, 0);
end;

function RenderTemplate(const aTemplate: string; const aData: TJSObject): string;
begin
  Result := RenderTemplateWithPartials(aTemplate, aData, nil);
end;

end.
