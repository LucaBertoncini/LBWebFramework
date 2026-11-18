# TemplateEngine - guida ed esempi

`TemplateEngine.RenderTemplate(aTemplate, aData)` trasforma un modello HTML (testo) e un oggetto dati in HTML.
Ogni valore `{{campo}}` passa da `TextToHTML`: il testo dell'utente non diventa mai markup.

Questa guida mostra il flusso completo per ogni caso:

1. il file template HTML;
2. i dati da passare, prima in JSON e poi nella costruzione equivalente con `TJSObject` e `TJSArray`;
3. la chiamata Pascal che carica e processa quel file;
4. l'HTML prodotto;
5. la corrispondenza fra chiavi e segnaposto.

Gli esempi sono indipendenti e ordinati per difficoltà crescente. I blocchi Pascal vanno eseguiti dentro un metodo `async` e presuppongono:

```pascal
uses
  JS, Web, TemplateEngine, uLBTemplateLoader;
```

Negli esempi, `FOutputEl` è l'elemento della pagina nel quale inserire l'HTML già renderizzato. Il template viene sempre caricato come **testo**, processato e soltanto dopo assegnato a `innerHTML`.

## Riferimento rapido

| Sintassi | Significato |
|---|---|
| `{{campo}}` | Legge `campo` dall'oggetto dati ed esegue l'escape HTML. |
| `{{oggetto.campo}}` | Legge un valore seguendo un percorso annidato. |
| `{{{campo}}}` | Inserisce il valore senza escape. Usare solo HTML sicuro prodotto dall'applicazione. |
| `{{this}}` | Indica l'elemento corrente in un `#each`, utile per array di stringhe o numeri. |
| `{{../campo}}` | Legge `campo` dall'ambito genitore. Ogni ulteriore `../` risale di un livello. |
| `{{#if campo}}...{{else}}...{{/if}}` | Sceglie un ramo in base al valore di `campo`. `else` è facoltativo. |
| `{{#unless campo}}...{{else}}...{{/unless}}` | Come `#if`, ma esegue il primo ramo quando il valore è falso. |
| `{{#each elenco}}...{{else}}...{{/each}}` | Ripete il blocco per ogni elemento. `else` viene usato se l'array è vuoto o assente. |
| `{{> nome}}` | Renderizza il partial chiamato `nome` nello stesso ambito corrente. |

Per `#if` e `#unless` sono falsi: campo assente, `null`, `false`, `0`, stringa vuota e array vuoto. Tutto il resto è vero, compresa la stringa `'false'`.

Regole importanti:

- passare valori **grezzi**: non chiamare `TextToHTML` prima del rendering, altrimenti il testo viene codificato due volte;
- usare booleani e numeri reali, per esempio `True` e `12`, non stringhe che li rappresentano;
- un campo mancante produce una stringa vuota;
- fuori da un tag HTML, `{{campo}}` usa `TextToHTML`; dentro un tag, per esempio `title="{{campo}}"`, usa `HtmlEncode` senza trasformare gli a-capo in `<br/>`;
- i blocchi e i partial possono essere annidati fino a una profondità massima di 32;
- `LoadTemplate` e `LoadTemplateSections` conservano in cache i file caricati con successo. `ClearTemplateCache` svuota la cache.

---

## 1. Valore semplice

Obiettivo: inserire un solo valore testuale in un titolo.

### 1.1 File template HTML

File `pages/hello.html` completo:

```html
<h1>Ciao {{name}}</h1>
```

### 1.2 Dati da passare

Struttura logica/JSON esatta:

```json
{
  "name": "Luca & Co."
}
```

Costruzione equivalente in Pascal:

```pascal
_Data := TJSObject.new;
_Data.Properties['name'] := 'Luca & Co.';
```

### 1.3 Caricamento e rendering in Pascal

```pascal
var
  _Template : String;
  _Data     : TJSObject;
  _Html     : String;
begin
  _Data := TJSObject.new;
  _Data.Properties['name'] := 'Luca & Co.';

  _Template := AWait(String, LoadTemplate('pages/hello.html'));
  _Html := TemplateEngine.RenderTemplate(_Template, _Data);
  FOutputEl.innerHTML := _Html;
end;
```

### 1.4 HTML risultante

```html
<h1>Ciao Luca &amp; Co.</h1>
```

### 1.5 Corrispondenza fra dati e segnaposto

La chiave `name` dell'oggetto `_Data` riempie `{{name}}`. Il valore viene passato come `Luca & Co.`; è il motore a trasformare `&` in `&amp;`.

---

## 2. Oggetto annidato

Obiettivo: leggere proprietà contenute in oggetti a più livelli.

### 2.1 File template HTML

File `pages/product-card.html` completo:

```html
<article class="product-card">
  <h2>{{product.name}}</h2>
  <p>Codice: {{product.code}}</p>
  <p>Produttore: {{product.manufacturer.name}}</p>
</article>
```

### 2.2 Dati da passare

Struttura logica/JSON esatta:

```json
{
  "product": {
    "name": "Pompa <Pro>",
    "code": "P-100",
    "manufacturer": {
      "name": "Idro & Figli"
    }
  }
}
```

Costruzione equivalente in Pascal:

```pascal
_Manufacturer := TJSObject.new;
_Manufacturer.Properties['name'] := 'Idro & Figli';

_Product := TJSObject.new;
_Product.Properties['name'] := 'Pompa <Pro>';
_Product.Properties['code'] := 'P-100';
_Product.Properties['manufacturer'] := _Manufacturer;

_Data := TJSObject.new;
_Data.Properties['product'] := _Product;
```

### 2.3 Caricamento e rendering in Pascal

```pascal
var
  _Template     : String;
  _Data         : TJSObject;
  _Product      : TJSObject;
  _Manufacturer : TJSObject;
  _Html         : String;
begin
  _Manufacturer := TJSObject.new;
  _Manufacturer.Properties['name'] := 'Idro & Figli';

  _Product := TJSObject.new;
  _Product.Properties['name'] := 'Pompa <Pro>';
  _Product.Properties['code'] := 'P-100';
  _Product.Properties['manufacturer'] := _Manufacturer;

  _Data := TJSObject.new;
  _Data.Properties['product'] := _Product;

  _Template := AWait(String, LoadTemplate('pages/product-card.html'));
  _Html := TemplateEngine.RenderTemplate(_Template, _Data);
  FOutputEl.innerHTML := _Html;
end;
```

### 2.4 HTML risultante

```html
<article class="product-card">
  <h2>Pompa &lt;Pro&gt;</h2>
  <p>Codice: P-100</p>
  <p>Produttore: Idro &amp; Figli</p>
</article>
```

### 2.5 Corrispondenza fra dati e segnaposto

- `{{product.name}}` segue `_Data['product']` e poi `['name']`.
- `{{product.code}}` segue `_Data['product']` e poi `['code']`.
- `{{product.manufacturer.name}}` attraversa tre livelli: `product`, `manufacturer`, `name`.

Anche qui i valori sono grezzi: `<Pro>` e `&` vengono protetti dal motore.

---

## 3. Condizione `if/else`

Obiettivo: produrre markup diverso in base a un booleano.

### 3.1 File template HTML

File `pages/account-status.html` completo:

```html
<div class="status">{{#if active}}<span class="ok">Attivo</span>{{else}}<span class="ko">Non attivo</span>{{/if}}</div>
```

### 3.2 Dati da passare

Struttura logica/JSON esatta:

```json
{
  "active": false
}
```

Costruzione equivalente in Pascal:

```pascal
_Data := TJSObject.new;
_Data.Properties['active'] := False;
```

### 3.3 Caricamento e rendering in Pascal

```pascal
var
  _Template : String;
  _Data     : TJSObject;
  _Html     : String;
begin
  _Data := TJSObject.new;
  _Data.Properties['active'] := False;

  _Template := AWait(String, LoadTemplate('pages/account-status.html'));
  _Html := TemplateEngine.RenderTemplate(_Template, _Data);
  FOutputEl.innerHTML := _Html;
end;
```

### 3.4 HTML risultante

```html
<div class="status"><span class="ko">Non attivo</span></div>
```

### 3.5 Corrispondenza fra dati e segnaposto

`{{#if active}}` legge la chiave booleana `active`. Poiché vale `False`, il motore ignora il primo ramo e renderizza il contenuto compreso fra `{{else}}` e `{{/if}}`. Impostando la stessa chiave a `True`, il risultato conterrebbe invece `<span class="ok">Attivo</span>`.

---

## 4. Ciclo `each`

Obiettivo: generare un elemento `<li>` per ogni stringa contenuta in un array.

### 4.1 File template HTML

File `pages/tag-list.html` completo:

```html
<ul class="tags">
  {{#each tags}}<li>{{this}}</li>{{else}}<li class="empty">Nessuna etichetta</li>{{/each}}
</ul>
```

### 4.2 Dati da passare

Struttura logica/JSON esatta:

```json
{
  "tags": [
    "urgente",
    "fermo & manutenzione"
  ]
}
```

Costruzione equivalente in Pascal:

```pascal
_Tags := TJSArray.new;
_Tags.push('urgente');
_Tags.push('fermo & manutenzione');

_Data := TJSObject.new;
_Data.Properties['tags'] := _Tags;
```

### 4.3 Caricamento e rendering in Pascal

```pascal
var
  _Template : String;
  _Data     : TJSObject;
  _Tags     : TJSArray;
  _Html     : String;
begin
  _Tags := TJSArray.new;
  _Tags.push('urgente');
  _Tags.push('fermo & manutenzione');

  _Data := TJSObject.new;
  _Data.Properties['tags'] := _Tags;

  _Template := AWait(String, LoadTemplate('pages/tag-list.html'));
  _Html := TemplateEngine.RenderTemplate(_Template, _Data);
  FOutputEl.innerHTML := _Html;
end;
```

### 4.4 HTML risultante

```html
<ul class="tags">
  <li>urgente</li><li>fermo &amp; manutenzione</li>
</ul>
```

### 4.5 Corrispondenza fra dati e segnaposto

`{{#each tags}}` legge l'array associato alla chiave `tags`. A ogni iterazione l'ambito corrente è una singola stringa, quindi `{{this}}` inserisce quella stringa. Se `tags` fosse `[]` o mancasse, verrebbe prodotto `<li class="empty">Nessuna etichetta</li>`.

---

## 5. Tabella con righe

Obiettivo: passare un array di oggetti e produrre una riga `<tr>` per ogni oggetto.

### 5.1 File template HTML

File `pages/products-table.html` completo:

```html
<table class="products">
  <thead><tr><th>Codice</th><th>Descrizione</th><th>Quantità</th></tr></thead>
  <tbody>
    {{#each rows}}<tr data-id="{{id}}"><td>{{code}}</td><td>{{description}}</td><td>{{quantity}}</td></tr>{{else}}<tr><td colspan="3">Nessun prodotto</td></tr>{{/each}}
  </tbody>
</table>
```

### 5.2 Dati da passare

Struttura logica/JSON esatta:

```json
{
  "rows": [
    {
      "id": 101,
      "code": "P-100",
      "description": "Pompa & filtro",
      "quantity": 2
    },
    {
      "id": 102,
      "code": "V-200",
      "description": "Valvola <inox>",
      "quantity": 5
    }
  ]
}
```

Costruzione equivalente in Pascal:

```pascal
_Row1 := TJSObject.new;
_Row1.Properties['id'] := 101;
_Row1.Properties['code'] := 'P-100';
_Row1.Properties['description'] := 'Pompa & filtro';
_Row1.Properties['quantity'] := 2;

_Row2 := TJSObject.new;
_Row2.Properties['id'] := 102;
_Row2.Properties['code'] := 'V-200';
_Row2.Properties['description'] := 'Valvola <inox>';
_Row2.Properties['quantity'] := 5;

_Rows := TJSArray.new;
_Rows.push(_Row1);
_Rows.push(_Row2);

_Data := TJSObject.new;
_Data.Properties['rows'] := _Rows;
```

### 5.3 Caricamento e rendering in Pascal

```pascal
var
  _Template : String;
  _Data     : TJSObject;
  _Rows     : TJSArray;
  _Row1     : TJSObject;
  _Row2     : TJSObject;
  _Html     : String;
begin
  _Row1 := TJSObject.new;
  _Row1.Properties['id'] := 101;
  _Row1.Properties['code'] := 'P-100';
  _Row1.Properties['description'] := 'Pompa & filtro';
  _Row1.Properties['quantity'] := 2;

  _Row2 := TJSObject.new;
  _Row2.Properties['id'] := 102;
  _Row2.Properties['code'] := 'V-200';
  _Row2.Properties['description'] := 'Valvola <inox>';
  _Row2.Properties['quantity'] := 5;

  _Rows := TJSArray.new;
  _Rows.push(_Row1);
  _Rows.push(_Row2);

  _Data := TJSObject.new;
  _Data.Properties['rows'] := _Rows;

  _Template := AWait(String, LoadTemplate('pages/products-table.html'));
  _Html := TemplateEngine.RenderTemplate(_Template, _Data);
  FOutputEl.innerHTML := _Html;
end;
```

### 5.4 HTML risultante

```html
<table class="products">
  <thead><tr><th>Codice</th><th>Descrizione</th><th>Quantità</th></tr></thead>
  <tbody>
    <tr data-id="101"><td>P-100</td><td>Pompa &amp; filtro</td><td>2</td></tr><tr data-id="102"><td>V-200</td><td>Valvola &lt;inox&gt;</td><td>5</td></tr>
  </tbody>
</table>
```

### 5.5 Corrispondenza fra dati e segnaposto

- `{{#each rows}}` itera l'array `_Rows`.
- Dentro il ciclo, ogni elemento è un `TJSObject` e diventa l'ambito corrente.
- `{{id}}`, `{{code}}`, `{{description}}` e `{{quantity}}` leggono quindi le proprietà della riga corrente, non quelle dell'oggetto `_Data` esterno.
- `{{id}}` si trova dentro l'attributo `data-id`, mentre gli altri valori sono testo delle celle. Il motore applica automaticamente l'escape adatto in entrambi i casi.

---

## 6. File con più sezioni e partial

Obiettivo: conservare nello stesso file un template principale e un template riutilizzabile per ogni membro. Questo esempio usa un partial, ma non è ancora ricorsivo.

### 6.1 File template HTML

File `pages/team-sections.html` completo:

```html
<!-- @page -->
<section class="team">
  <h2>{{title}}</h2>
  <div class="team-list">{{#each members}}{{> member}}{{else}}<p>Nessun membro</p>{{/each}}</div>
</section>

<!-- @member -->
<article class="member" data-id="{{id}}">
  <strong>{{name}}</strong>
  <span>{{role}}</span>
</article>
```

Le righe `<!-- @page -->` e `<!-- @member -->` dividono il file in due sezioni chiamate rispettivamente `page` e `member`. `LoadTemplateSections` restituisce un oggetto nel quale la proprietà `page` contiene il testo completo della prima sezione e la proprietà `member` contiene il testo completo della seconda.

### 6.2 Dati da passare

Struttura logica/JSON esatta:

```json
{
  "title": "Team assistenza",
  "members": [
    {
      "id": 7,
      "name": "Anna Rossi",
      "role": "Coordinatrice"
    },
    {
      "id": 9,
      "name": "Paolo Bianchi",
      "role": "Tecnico"
    }
  ]
}
```

Costruzione equivalente in Pascal:

```pascal
_Member1 := TJSObject.new;
_Member1.Properties['id'] := 7;
_Member1.Properties['name'] := 'Anna Rossi';
_Member1.Properties['role'] := 'Coordinatrice';

_Member2 := TJSObject.new;
_Member2.Properties['id'] := 9;
_Member2.Properties['name'] := 'Paolo Bianchi';
_Member2.Properties['role'] := 'Tecnico';

_Members := TJSArray.new;
_Members.push(_Member1);
_Members.push(_Member2);

_Data := TJSObject.new;
_Data.Properties['title'] := 'Team assistenza';
_Data.Properties['members'] := _Members;
```

### 6.3 Caricamento e rendering in Pascal

```pascal
var
  _Sections : TJSObject;
  _Data     : TJSObject;
  _Members  : TJSArray;
  _Member1  : TJSObject;
  _Member2  : TJSObject;
  _Html     : String;
begin
  _Member1 := TJSObject.new;
  _Member1.Properties['id'] := 7;
  _Member1.Properties['name'] := 'Anna Rossi';
  _Member1.Properties['role'] := 'Coordinatrice';

  _Member2 := TJSObject.new;
  _Member2.Properties['id'] := 9;
  _Member2.Properties['name'] := 'Paolo Bianchi';
  _Member2.Properties['role'] := 'Tecnico';

  _Members := TJSArray.new;
  _Members.push(_Member1);
  _Members.push(_Member2);

  _Data := TJSObject.new;
  _Data.Properties['title'] := 'Team assistenza';
  _Data.Properties['members'] := _Members;

  _Sections := AWait(TJSObject,
    LoadTemplateSections('pages/team-sections.html'));

  _Html := TemplateEngine.RenderTemplateWithPartials(
    String(_Sections.Properties['page']),
    _Data,
    _Sections);

  FOutputEl.innerHTML := _Html;
end;
```

### 6.4 HTML risultante

```html
<section class="team">
  <h2>Team assistenza</h2>
  <div class="team-list"><article class="member" data-id="7">
  <strong>Anna Rossi</strong>
  <span>Coordinatrice</span>
</article><article class="member" data-id="9">
  <strong>Paolo Bianchi</strong>
  <span>Tecnico</span>
</article></div>
</section>
```

### 6.5 Corrispondenza fra dati e segnaposto

- Il Pascal sceglie `page` come sezione iniziale con `_Sections.Properties['page']`.
- Nel template `page`, `{{title}}` legge `_Data['title']` e `{{#each members}}` itera `_Data['members']`.
- Durante ogni iterazione, `{{> member}}` renderizza la sezione `member` usando il membro corrente come ambito.
- Di conseguenza, `{{id}}`, `{{name}}` e `{{role}}` leggono le proprietà del singolo membro.
- Il terzo argomento di `RenderTemplateWithPartials` deve essere `_Sections`: è l'oggetto nel quale il motore cerca il partial chiamato `member`.

---

## 7. Albero ricorsivo

Obiettivo: renderizzare un albero con un numero di livelli non noto in anticipo. La sezione `node` richiama sé stessa per ogni elemento dell'array `children`.

### 7.1 File template HTML

File `pages/category-tree.html` completo:

```html
<!-- @tree -->
<ul class="tree">{{#each nodes}}{{> node}}{{/each}}</ul>

<!-- @node -->
<li>{{name}}{{#if children}}<ul>{{#each children}}{{> node}}{{/each}}</ul>{{/if}}</li>
```

`tree` è il punto di ingresso. `node` descrive un nodo e, quando `children` non è vuoto, usa di nuovo `{{> node}}` per ogni figlio.

### 7.2 Dati da passare

Struttura logica/JSON esatta:

```json
{
  "nodes": [
    {
      "name": "Impianto",
      "children": [
        {
          "name": "Pompe",
          "children": [
            {
              "name": "Pompa A",
              "children": []
            }
          ]
        },
        {
          "name": "Valvole",
          "children": []
        }
      ]
    }
  ]
}
```

Costruzione equivalente in Pascal:

```pascal
_PumpAChildren := TJSArray.new;
_PumpA := TJSObject.new;
_PumpA.Properties['name'] := 'Pompa A';
_PumpA.Properties['children'] := _PumpAChildren;

_PumpsChildren := TJSArray.new;
_PumpsChildren.push(_PumpA);
_Pumps := TJSObject.new;
_Pumps.Properties['name'] := 'Pompe';
_Pumps.Properties['children'] := _PumpsChildren;

_ValvesChildren := TJSArray.new;
_Valves := TJSObject.new;
_Valves.Properties['name'] := 'Valvole';
_Valves.Properties['children'] := _ValvesChildren;

_PlantChildren := TJSArray.new;
_PlantChildren.push(_Pumps);
_PlantChildren.push(_Valves);
_Plant := TJSObject.new;
_Plant.Properties['name'] := 'Impianto';
_Plant.Properties['children'] := _PlantChildren;

_Nodes := TJSArray.new;
_Nodes.push(_Plant);

_Data := TJSObject.new;
_Data.Properties['nodes'] := _Nodes;
```

### 7.3 Caricamento e rendering in Pascal

```pascal
var
  _Sections      : TJSObject;
  _Data          : TJSObject;
  _Nodes         : TJSArray;
  _Plant         : TJSObject;
  _PlantChildren : TJSArray;
  _Pumps         : TJSObject;
  _PumpsChildren : TJSArray;
  _PumpA         : TJSObject;
  _PumpAChildren : TJSArray;
  _Valves         : TJSObject;
  _ValvesChildren : TJSArray;
  _Html          : String;
begin
  // Foglia "Pompa A": children è presente ma vuoto.
  _PumpAChildren := TJSArray.new;
  _PumpA := TJSObject.new;
  _PumpA.Properties['name'] := 'Pompa A';
  _PumpA.Properties['children'] := _PumpAChildren;

  // Nodo "Pompe" con una foglia.
  _PumpsChildren := TJSArray.new;
  _PumpsChildren.push(_PumpA);
  _Pumps := TJSObject.new;
  _Pumps.Properties['name'] := 'Pompe';
  _Pumps.Properties['children'] := _PumpsChildren;

  // Foglia "Valvole".
  _ValvesChildren := TJSArray.new;
  _Valves := TJSObject.new;
  _Valves.Properties['name'] := 'Valvole';
  _Valves.Properties['children'] := _ValvesChildren;

  // Radice "Impianto" con due figli.
  _PlantChildren := TJSArray.new;
  _PlantChildren.push(_Pumps);
  _PlantChildren.push(_Valves);
  _Plant := TJSObject.new;
  _Plant.Properties['name'] := 'Impianto';
  _Plant.Properties['children'] := _PlantChildren;

  _Nodes := TJSArray.new;
  _Nodes.push(_Plant);

  _Data := TJSObject.new;
  _Data.Properties['nodes'] := _Nodes;

  _Sections := AWait(TJSObject,
    LoadTemplateSections('pages/category-tree.html'));

  _Html := TemplateEngine.RenderTemplateWithPartials(
    String(_Sections.Properties['tree']),
    _Data,
    _Sections);

  FOutputEl.innerHTML := _Html;
end;
```

### 7.4 HTML risultante

```html
<ul class="tree"><li>Impianto<ul><li>Pompe<ul><li>Pompa A</li></ul></li><li>Valvole</li></ul></li></ul>
```

### 7.5 Corrispondenza fra dati e segnaposto

- `{{#each nodes}}` parte dall'array delle radici `_Data['nodes']`.
- `{{> node}}` renderizza il partial `node` sul nodo corrente.
- Nel partial, `{{name}}` legge il nome del nodo corrente.
- `{{#if children}}` è vero soltanto se `children` è un array non vuoto.
- `{{#each children}}` sposta l'ambito su ogni figlio e il successivo `{{> node}}` richiama lo stesso partial. È questo richiamo che realizza la ricorsione.
- Ogni foglia contiene `children: []`: l'array vuoto rende falso `{{#if children}}` e interrompe naturalmente quel ramo.
- Come nell'esempio precedente, `_Sections` deve essere passato come terzo argomento; senza i partial, `{{> node}}` non produrrebbe contenuto.

Il motore tronca un ramo oltre 32 livelli complessivi di blocchi e partial. Questa protezione evita una ricorsione infinita se un partial richiama sé stesso senza attraversare un array che prima o poi termina.

---

## Ambiti nei cicli

Dentro `{{#each elenco}}`, i nomi vengono cercati soltanto nell'elemento corrente. Per leggere una proprietà del livello esterno si usa `../`.

Per esempio, se l'oggetto esterno contiene `title` e ogni elemento corrente contiene `name`, dentro il ciclo si usano `{{name}}` per l'elemento e `{{../title}}` per il dato esterno. Nei cicli annidati si può usare `../../title` per risalire di due livelli.

Questa regola spiega perché, negli esempi della tabella e dei partial, `{{id}}` e `{{name}}` si riferiscono alla riga o al membro corrente e non all'oggetto radice.

## Valori con e senza escape

Usare normalmente `{{campo}}`. Il motore protegge `&`, `<`, `>`, virgolette e apici; nel testo converte inoltre gli a-capo secondo `TextToHTML`.

Usare `{{{campo}}}` soltanto quando il valore è HTML creato e controllato dall'applicazione. Non usarlo per testo ricevuto dall'utente o dal server: il contenuto verrebbe inserito come markup senza protezione.

## Caricamento e cache

- `LoadTemplate(path)` restituisce il testo completo di un file e lo mette in cache per percorso.
- `LoadTemplateSections(path)` carica il file, lo divide in corrispondenza di `<!-- @nome -->` e restituisce un `TJSObject` del tipo `nome -> testo della sezione`.
- Il testo che precede la prima marca `<!-- @nome -->` viene ignorato.
- I nomi di sezione possono contenere lettere, numeri, `_` e `-`.
- Se il caricamento fallisce, le funzioni restituiscono rispettivamente una stringa vuota o un oggetto vuoto e non memorizzano l'insuccesso in cache.
- `ClearTemplateCache` forza il ricaricamento dei template alle chiamate successive.

## Errori frequenti

1. **Inserire il template nel DOM prima del rendering.** Un template con `data-id="{{id}}"` deve essere letto come testo; il browser potrebbe deformare i segnaposto se analizza prima l'HTML.
2. **Passare testo già codificato.** Inserire `TextToHTML(Value)` nei dati causa doppio escape. Passare `Value` così com'è.
3. **Passare `'false'` invece di `False`.** La stringa non vuota `'false'` è vera per `#if`; usare un booleano reale.
4. **Cercare il dato nell'ambito sbagliato.** Dentro `#each`, usare i campi dell'elemento corrente oppure `../campo` per risalire.
5. **Dimenticare il terzo argomento.** I template con `{{> nome}}` richiedono `RenderTemplateWithPartials(..., _Sections)`.
6. **Usare un nome diverso.** `{{> member}}` cerca esattamente la sezione `<!-- @member -->`; i due nomi devono coincidere.
7. **Creare una ricorsione che non termina.** Un partial ricorsivo deve procedere verso array di figli sempre più piccoli, fino a un array vuoto.
