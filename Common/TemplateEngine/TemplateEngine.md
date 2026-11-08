# TemplateEngine - guida ed esempi

`TemplateEngine.RenderTemplate(aTemplate, aData)` trasforma un modello HTML (testo) e un oggetto dati in HTML.
Ogni valore `{{campo}}` passa da `TextToHTML`: il testo dell'utente non diventa mai markup.

## Riferimento rapido

| Sintassi | Significato |
|---|---|
| `{{campo}}`, `{{oggetto.campo}}` | valore con escape; percorso con punti |
| `{{{campo}}}` | valore **senza** escape: solo per HTML prodotto dall'applicazione |
| `{{this}}` | l'elemento corrente (elenchi di stringhe/numeri) |
| `{{../campo}}` | campo dell'ambito genitore (`../../` per due livelli) |
| `{{#each elenco}}...{{/each}}` | ciclo; annidabile |
| `{{#each elenco}}...{{else}}...{{/each}}` | `else` se l'elenco e' vuoto o assente |
| `{{#if campo}}...{{else}}...{{/if}}` | condizione; `else` facoltativo |
| `{{#unless campo}}...{{else}}...{{/unless}}` | condizione negata |
| `{{> nome}}` | frammento (partial) con lo stesso ambito: per le strutture ricorsive |

**Falso** (per `#if` / `#unless`): campo assente, `null`, `false`, `0`, `''` e array vuoto. Tutto il resto e' vero
(compresa la stringa `'false'`).

## Uso dal Pascal

```pascal
uses TemplateEngine, uLBTemplateLoader;

var
  _Tpl  : String;
  _Data : TJSObject;
begin
  _Tpl := AWait(String, LoadTemplate('pages/group-row.html'));   // testo, con cache
  _Data := TJSObject.new;
  _Data.Properties['rows'] := _Items;                                       // TJSArray di TJSObject
  FListEl.innerHTML := TemplateEngine.RenderTemplate(_Tpl, _Data);
end;
```

Con i frammenti ricorsivi (`LoadTemplateSections` legge un file con piu' modelli separati da `<!-- @nome -->`):

```pascal
_Parts := AWait(TJSObject, LoadTemplateSections('pages/tree.html'));
FListEl.innerHTML := TemplateEngine.RenderTemplateWithPartials(
  String(_Parts.Properties['tree']), _Data, _Parts);
```

Regole pratiche:
- Passare i valori **grezzi**: il motore fa gia' l'escape (se si passa `TextToHTML(x)` si ottiene una doppia codifica, `&` diventa `&amp;`).
- Booleani e numeri si passano com'e': `Properties['can_join'] := True`, non `'hidden'` o `''`.
- Un modello con segnaposto dentro i tag (`data-id="{{id}}"`) va letto come **testo** (`fetch` + `.text()`, o `LoadTemplate`)
  e reso prima di toccare il DOM: il parser HTML del browser lo deformerebbe.
- Dentro un tag (`value="{{note}}"`, `title="{{x}}"`) l'escape e' quello per gli attributi: `& < > " '` e **nessuna** conversione degli a-capo in `<br/>`.
  Il riconoscimento guarda il testo gia' prodotto nello stesso blocco: un tag aperto in un blocco e chiuso in un altro (`{{#if}}` dentro il tag) non e' riconosciuto.
- `LoadTemplate` e `LoadTemplateSections` stanno in `uLBTemplateLoader` (cartella TemplateEngine).
- `else` e i nomi che iniziano con `/` o `#` sono riservati; un tag che non si capisce resta nel testo cosi' com'e'.

## Esempio completo: albero ricorsivo (HTML, dati e Pascal)

Esempio: un albero (radice, rami, foglie) con una casella per ogni nodo. Ogni nodo puo' avere
dei figli, che a loro volta ne hanno: il numero di livelli non e' noto in anticipo, quindi serve un modello che richiami se stesso.

### 1. Il file HTML: ogni pezzo ha un NOME

Un solo file, `pages/tree.html`, con **piu' modelli**. Ognuno inizia con una riga
`<!-- @nome -->`: **il nome dopo la `@` e' l'identificativo con cui il Pascal e gli altri modelli ritrovano quel pezzo**.
Senza nome un frammento non si puo' ne' scegliere dal Pascal ne' richiamare con `{{> nome}}`.

```html
<!-- @tree -->
<ul class="tree-root">{{#each nodes}}{{> node}}{{/each}}</ul>

<!-- @node -->
<li class="tree-node" data-uuid="{{uuid}}">
  <div class="tree-row">
    <input type="checkbox" class="tree-chk" data-uuid="{{uuid}}" {{checked}}>
    <span class="tree-name">{{name}}</span>
    {{#if code}}<span class="tree-code">({{code}})</span>{{/if}}
  </div>
  {{#if children}}
  <ul class="tree-nested">{{#each children}}{{> node}}{{/each}}</ul>
  {{/if}}
</li>
```

Come si legge:
- `tree` e' il punto di ingresso: lo sceglie il Pascal. Contiene l'elenco dei nodi radice e, per ognuno, rimanda a `node`.
- `node` e' il disegno di UN nodo. Dentro, `{{#each children}}{{> node}}{{/each}}` dice: "per ogni figlio, ridisegna questo stesso modello".
  La ricorsione finisce da sola: un nodo senza figli ha `children` vuoto, quindi `{{#if children}}` e' falso e il ramo non viene aperto.
- `{{> node}}` e' un richiamo **per nome**: se il nome non esiste tra i frammenti passati al motore, quel punto resta vuoto (nessun errore).
- Le due parole `tree` e `node` le scegli tu; devono solo coincidere tra le righe `<!-- @... -->`, i `{{> ...}}` e il Pascal.
- I modelli hanno segnaposto dentro i tag (`data-uuid="{{uuid}}"`): il file va letto come **testo**, mai inserito nella pagina cosi' com'e'.
  Gli a capo e i rientri del modello finiscono nell'HTML prodotto; sono innocui (un elenco `<ul>` ignora gli spazi tra gli elementi).

### 2. La struttura dati

Il server restituisce un elenco **piatto**, un record per nodo, con il riferimento al padre:

```json
[
  {
    "uuid": "u1",
    "parent_uuid": null,
    "name": "Radice",
    "code": "R",
    "checked": ""
  },
  {
    "uuid": "u2",
    "parent_uuid": "u1",
    "name": "Ramo 1",
    "code": "B1",
    "checked": ""
  },
  {
    "uuid": "u3",
    "parent_uuid": "u2",
    "name": "Foglia <A&B>",
    "code": "",
    "checked": ""
  },
  {
    "uuid": "u4",
    "parent_uuid": "u1",
    "name": "Ramo 2",
    "code": "B2",
    "checked": "checked"
  }
]
```

Prima del rendering servono due preparazioni, entrambe in Pascal:
1. **annidare**: ogni nodo riceve un array `children` con i propri figli (e i nodi senza padre diventano le radici);
2. **marcare**: ogni nodo riceve `checked` = `'checked'` oppure `''` (e' il testo che finisce nell'attributo della casella).

Dopo le due preparazioni il motore riceve l'oggetto `{ "nodes": [ ...radici... ] }`:

```json
{ "nodes": [
    {
      "uuid": "u1",
      "parent_uuid": null,
      "name": "Radice",
      "code": "R",
      "children": [
        {
          "uuid": "u2",
          "parent_uuid": "u1",
          "name": "Ramo 1",
          "code": "B1",
          "children": [
            {
              "uuid": "u3",
              "parent_uuid": "u2",
              "name": "Foglia <A&B>",
              "code": "",
              "children": [],
              "checked": ""
            }
          ],
          "checked": ""
        },
        {
          "uuid": "u4",
          "parent_uuid": "u1",
          "name": "Ramo 2",
          "code": "B2",
          "children": [],
          "checked": "checked"
        }
      ],
      "checked": ""
    }
  ] }
```

I campi usati dal modello sono `uuid`, `name`, `code`, `checked` e `children`. Gli altri (come `parent_uuid`) sono ignorati.
I valori vanno passati **grezzi** (`Foglia <A&B>`): l'escape lo fa il motore.

### 3. L'uso in Pascal

```pascal
uses
  JS, Web, SysUtils, TemplateEngine, uLBTemplateLoader;

const
  cTreeTemplatePath = 'pages/tree.html';

// 1. annidare: dall'elenco piatto alla foresta (ogni nodo con il suo array 'children')
procedure NestFlatList(aFlat, aForest: TJSArray);
var
  _Map    : TJSMap;
  i       : Integer;
  _Item   : TJSObject;
  _Parent : TJSObject;
  _PKey   : String;
begin
  _Map := TJSMap.new;
  for i := 0 to aFlat.Length - 1 do
  begin
    _Item := TJSObject(aFlat.Elements[i]);
    _Item.Properties['children'] := TJSArray.new;
    _Map.&set(String(_Item.Properties['uuid']), _Item);
  end;
  for i := 0 to aFlat.Length - 1 do
  begin
    _Item := TJSObject(aFlat.Elements[i]);
    if hasValue(_Item.Properties['parent_uuid']) then
    begin
      _PKey := String(_Item.Properties['parent_uuid']);
      if _Map.has(_PKey) then
      begin
        _Parent := TJSObject(_Map.get(_PKey));
        TJSArray(_Parent.Properties['children']).push(_Item);
        Continue;
      end;
    end;
    aForest.push(_Item);
  end;
end;

// 2. marcare: 'checked' sui nodi presenti nell'insieme dei nodi spuntati (ricorsiva)
procedure MarkChecked(aForest: TJSArray; aCheckedSet: TJSObject);
var
  i     : Integer;
  _Item : TJSObject;
begin
  for i := 0 to aForest.Length - 1 do
  begin
    _Item := TJSObject(aForest.Elements[i]);
    if aCheckedSet.hasOwnProperty(String(_Item.Properties['uuid'])) then
      _Item.Properties['checked'] := 'checked'
    else
      _Item.Properties['checked'] := '';
    MarkChecked(TJSArray(_Item.Properties['children']), aCheckedSet);
  end;
end;

// 3. rendering: un solo passaggio per tutto l'albero
procedure TTreeDialog.RenderTree(aFlat: TJSArray; aCheckedSet: TJSObject);
var
  _Parts  : TJSObject;   // nome -> testo del modello: { tree: '...', node: '...' }
  _Forest : TJSArray;
  _Data   : TJSObject;
begin
  _Parts := AWait(TJSObject, LoadTemplateSections(cTreeTemplatePath));   // il file, spezzato per nome
  if not _Parts.hasOwnProperty('tree') then
  begin
    Self.ShowError('Impossibile caricare il modello dell''albero.');
    Exit;
  end;

  _Forest := TJSArray.new;
  NestFlatList(aFlat, _Forest);
  MarkChecked(_Forest, aCheckedSet);

  _Data := TJSObject.new;
  _Data.Properties['nodes'] := _Forest;                                  // il nome usato in {{#each nodes}}

  FListEl.innerHTML := TemplateEngine.RenderTemplateWithPartials(
    String(_Parts.Properties['tree']),     // da quale modello partire
    _Data,                                  // i dati
    _Parts);                                // i frammenti richiamabili con {{> nome}}
end;
```

Tre punti da ricordare:
- il **terzo argomento** (`_Parts`) e' cio' che permette a `{{> node}}` di trovare `node`; dimenticarlo (o passare `nil`) lascia l'albero vuoto dopo le radici;
- `LoadTemplateSections` scarica il file una volta (cache) e lo spezza in un oggetto `nome -> testo`; lo stesso oggetto serve da elenco dei frammenti;
- la chiave `nodes` dei dati e il nome in `{{#each nodes}}` sono la stessa parola, come `children`.

### 4. Il risultato

Con i dati di sopra (e `u4` tra i nodi spuntati) l'HTML prodotto e':

```html
<ul class="tree-root"><li class="tree-node" data-uuid="u1">
  <div class="tree-row">
    <input type="checkbox" class="tree-chk" data-uuid="u1" >
    <span class="tree-name">Radice</span>
    <span class="tree-code">(R)</span>
  </div>
  
  <ul class="tree-nested"><li class="tree-node" data-uuid="u2">
  <div class="tree-row">
    <input type="checkbox" class="tree-chk" data-uuid="u2" >
    <span class="tree-name">Ramo 1</span>
    <span class="tree-code">(B1)</span>
  </div>
  
  <ul class="tree-nested"><li class="tree-node" data-uuid="u3">
  <div class="tree-row">
    <input type="checkbox" class="tree-chk" data-uuid="u3" >
    <span class="tree-name">Foglia &lt;A&amp;B&gt;</span>
    
  </div>
  
</li></ul>
  
</li><li class="tree-node" data-uuid="u4">
  <div class="tree-row">
    <input type="checkbox" class="tree-chk" data-uuid="u4" checked>
    <span class="tree-name">Ramo 2</span>
    <span class="tree-code">(B2)</span>
  </div>
  
</li></ul>
  
</li></ul>
```

Il nome con `<A&B>` esce correttamente protetto, e solo `u4` ha `checked`.

## Esempi (l'output e' quello prodotto dal motore)

### 1. Badge facoltativo (prima: segnaposto `*_hidden` + `HiddenClass` nel Pascal)

Modello:

```html
<span class="admin-row-title">{{name}}</span>
{{#if inactive}}<span class="admin-badge admin-badge-inactive">Non attivo</span>{{/if}}
```

Dati (in Pascal: `TJSObject` / `TJSArray` con le stesse chiavi):

```json
{
  "name": "Manutentori",
  "inactive": true
}
```

Risultato:

```html
<span class="admin-row-title">Manutentori</span>
<span class="admin-badge admin-badge-inactive">Non attivo</span>
```

### 2. Due varianti con `else` (membri / non attivo)

Modello:

```html
{{#if is_active}}<span class="admin-badge">{{members}} membri</span>{{else}}<span class="admin-badge admin-badge-inactive">Non attivo</span>{{/if}}
```

Dati (in Pascal: `TJSObject` / `TJSArray` con le stesse chiavi):

```json
{
  "is_active": false,
  "members": 4
}
```

Risultato:

```html
<span class="admin-badge admin-badge-inactive">Non attivo</span>
```

### 3. Elenco vuoto senza segnaposto di appoggio (prima: `no_participants_hidden`)

Modello:

```html
<ul>{{#each participants}}<li>{{username}}</li>{{else}}<li class="muted">Nessun partecipante.</li>{{/each}}</ul>
```

Dati (in Pascal: `TJSObject` / `TJSArray` con le stesse chiavi):

```json
{
  "participants": []
}
```

Risultato:

```html
<ul><li class="muted">Nessun partecipante.</li></ul>
```

### 4. Condizione dentro un ciclo (pulsanti per riga)

Modello:

```html
{{#each orders}}<div class="admin-row">n. {{num}}
  {{#if can_join}}<button data-action="join" data-uuid="{{uuid}}">Partecipa</button>{{/if}}
  {{#if can_cancel}}<button data-action="cancel" data-uuid="{{uuid}}">Annulla</button>{{/if}}
</div>{{/each}}
```

Dati (in Pascal: `TJSObject` / `TJSArray` con le stesse chiavi):

```json
{
  "orders": [
    {
      "num": 12,
      "uuid": "a1",
      "can_join": true,
      "can_cancel": false
    },
    {
      "num": 13,
      "uuid": "b2",
      "can_join": false,
      "can_cancel": true
    }
  ]
}
```

Risultato:

```html
<div class="admin-row">n. 12
  <button data-action="join" data-uuid="a1">Partecipa</button>
  
</div><div class="admin-row">n. 13
  
  <button data-action="cancel" data-uuid="b2">Annulla</button>
</div>
```

### 5. Cicli annidati: blocchi del riepilogo, ognuno con le sue righe

Modello:

```html
{{#each blocks}}<div class="stat-block"><h4>{{title}}</h4>
{{#each rows}}  <div class="stat-bar-row"><span class="nm">{{label}}</span><span class="n">{{n}}</span></div>
{{/each}}</div>{{/each}}
```

Dati (in Pascal: `TJSObject` / `TJSArray` con le stesse chiavi):

```json
{
  "blocks": [
    {
      "title": "Per tipologia",
      "rows": [
        {
          "label": "A - Categoria A",
          "n": 12
        },
        {
          "label": "B - Categoria B",
          "n": 7
        }
      ]
    },
    {
      "title": "Per mese",
      "rows": [
        {
          "label": "2026-09",
          "n": 9
        }
      ]
    }
  ]
}
```

Risultato:

```html
<div class="stat-block"><h4>Per tipologia</h4>
  <div class="stat-bar-row"><span class="nm">A - Categoria A</span><span class="n">12</span></div>
  <div class="stat-bar-row"><span class="nm">B - Categoria B</span><span class="n">7</span></div>
</div><div class="stat-block"><h4>Per mese</h4>
  <div class="stat-bar-row"><span class="nm">2026-09</span><span class="n">9</span></div>
</div>
```

### 6. `../` per leggere un campo del livello superiore

Modello:

```html
{{#each groups}}<h4>{{name}} ({{../asset}})</h4>{{/each}}
```

Dati (in Pascal: `TJSObject` / `TJSArray` con le stesse chiavi):

```json
{
  "asset": "Elemento 4",
  "groups": [
    {
      "name": "Gruppo A"
    },
    {
      "name": "Gruppo B"
    }
  ]
}
```

Risultato:

```html
<h4>Gruppo A (Elemento 4)</h4><h4>Gruppo B (Elemento 4)</h4>
```

### 7. Elenco di stringhe con `{{this}}`

Modello:

```html
{{#each tags}}<span class="chip">{{this}}</span>{{/each}}
```

Dati (in Pascal: `TJSObject` / `TJSArray` con le stesse chiavi):

```json
{
  "tags": [
    "urgente",
    "fermo macchina"
  ]
}
```

Risultato:

```html
<span class="chip">urgente</span><span class="chip">fermo macchina</span>
```

### 8. Albero ricorsivo con un frammento (prima: DOM composto in Pascal)

Modello:

```html
<ul class="tree-root">{{#each nodes}}{{> node}}{{/each}}</ul>
```

Dati (in Pascal: `TJSObject` / `TJSArray` con le stesse chiavi):

```json
{
  "nodes": [
    {
      "name": "Radice",
      "children": [
        {
          "name": "Ramo 1",
          "children": [
            {
              "name": "Foglia"
            }
          ]
        },
        {
          "name": "Ramo 2"
        }
      ]
    }
  ]
}
```

Frammenti:

```json
{
  "node": "<li>{{name}}{{#if children}}<ul>{{#each children}}{{> node}}{{/each}}</ul>{{/if}}</li>"
}
```

Risultato:

```html
<ul class="tree-root"><li>Radice<ul><li>Ramo 1<ul><li>Foglia</li></ul></li><li>Ramo 2</li></ul></li></ul>
```

### 9. `{{{ }}}`: HTML già pronto dell'applicazione, e perché `{{ }}` resta sicuro con i dati utente

Modello:

```html
<div>{{{icon}}} {{label}}</div>
```

Dati (in Pascal: `TJSObject` / `TJSArray` con le stesse chiavi):

```json
{
  "icon": "<svg class=\"lock-icon\"></svg>",
  "label": "<script>alert(1)</script>"
}
```

Risultato:

```html
<div><svg class="lock-icon"></svg> &lt;script&gt;alert(1)&lt;/script&gt;</div>
```

### 10. `unless` (messaggio quando manca qualcosa)

Modello:

```html
{{#unless email}}<span class="muted">email non indicata</span>{{else}}{{email}}{{/unless}}
```

Dati (in Pascal: `TJSObject` / `TJSArray` con le stesse chiavi):

```json
{
  "email": ""
}
```

Risultato:

```html
<span class="muted">email non indicata</span>
```

## Prima e dopo: cosa cambia nel progetto

Prima, per un pulsante facoltativo serviva un segnaposto di classe calcolato in Pascal:

```pascal
Result.Properties['cancel_hidden'] := HiddenClass(not RowBool(aRow, 'can_cancel'));
```
```html
<button class="admin-btn admin-btn-del {{cancel_hidden}}" data-action="cancel" data-uuid="{{uuid}}">Annulla</button>
```

Con `#if`, il Pascal passa il dato e il modello decide cosa mostrare:

```pascal
Result.Properties['can_cancel'] := RowBool(aRow, 'can_cancel');
```
```html
{{#if can_cancel}}<button class="admin-btn admin-btn-del" data-action="cancel" data-uuid="{{uuid}}">Annulla</button>{{/if}}
```

Vantaggi: il pulsante non sta nel DOM se non serve (niente elementi nascosti con `data-action`), il Pascal non conosce
le classi CSS e il modello dice cosa compare davvero.

## Verifica

`tests/TemplateEngine/test.js` e' una copia 1:1 dell'algoritmo in JavaScript con i casi di prova
(`node tests/TemplateEngine/test.js`). Passando una o piu' cartelle di modelli (`node test.js cartella/pages`) confronta anche il motore nuovo con il vecchio sui modelli esistenti, scritti per la versione precedente,
diano lo stesso risultato.
