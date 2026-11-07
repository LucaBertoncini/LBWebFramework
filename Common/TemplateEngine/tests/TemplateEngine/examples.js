const {render}=require('./port.js');
const ex=[];
const add=(title,tpl,data,partials,note)=>ex.push({title,tpl,data,partials,out:render(tpl,data,partials),note});
add('1. Badge facoltativo (prima: segnaposto `*_hidden` + `HiddenClass` nel Pascal)',
`<span class="admin-row-title">{{name}}</span>
{{#if inactive}}<span class="admin-badge admin-badge-inactive">Non attivo</span>{{/if}}`,
{name:'Manutentori',inactive:true});
add('2. Due varianti con `else` (membri / non attivo)',
`{{#if is_active}}<span class="admin-badge">{{members}} membri</span>{{else}}<span class="admin-badge admin-badge-inactive">Non attivo</span>{{/if}}`,
{is_active:false,members:4});
add('3. Elenco vuoto senza segnaposto di appoggio (prima: `no_participants_hidden`)',
`<ul>{{#each participants}}<li>{{username}}</li>{{else}}<li class="wo-muted">Nessuno ha ancora iniziato la lavorazione.</li>{{/each}}</ul>`,
{participants:[]});
add('4. Condizione dentro un ciclo (pulsanti per riga)',
`{{#each orders}}<div class="admin-row">n. {{num}}
  {{#if can_join}}<button data-action="join" data-uuid="{{uuid}}">Partecipa</button>{{/if}}
  {{#if can_cancel}}<button data-action="cancel" data-uuid="{{uuid}}">Annulla</button>{{/if}}
</div>{{/each}}`,
{orders:[{num:12,uuid:'a1',can_join:true,can_cancel:false},{num:13,uuid:'b2',can_join:false,can_cancel:true}]});
add('5. Cicli annidati: blocchi del riepilogo, ognuno con le sue righe',
`{{#each blocks}}<div class="hst-block"><h4>{{title}}</h4>
{{#each rows}}  <div class="hst-bar-row"><span class="nm">{{label}}</span><span class="n">{{n}}</span></div>
{{/each}}</div>{{/each}}`,
{blocks:[{title:'Per tipologia',rows:[{label:'GUA - Guasto',n:12},{label:'MAN - Manutenzione',n:7}]},{title:'Per mese',rows:[{label:'2026-09',n:9}]}]});
add('6. `../` per leggere un campo del livello superiore',
`{{#each groups}}<h4>{{name}} ({{../asset}})</h4>{{/each}}`,
{asset:'Pressa 4',groups:[{name:'Elettrici'},{name:'Meccanici'}]});
add('7. Elenco di stringhe con `{{this}}`',
`{{#each tags}}<span class="chip">{{this}}</span>{{/each}}`,
{tags:['urgente','fermo macchina']});
add('8. Albero ricorsivo con un frammento (prima: DOM composto in Pascal)',
`<ul class="cmms-exclusion-root">{{#each nodes}}{{> node}}{{/each}}</ul>`,
{nodes:[{name:'Stabilimento',children:[{name:'Linea 1',children:[{name:'Estrusore'}]},{name:'Linea 2'}]}]},
{node:'<li>{{name}}{{#if children}}<ul>{{#each children}}{{> node}}{{/each}}</ul>{{/if}}</li>'});
add('9. `{{{ }}}`: HTML già pronto dell\'applicazione, e perché `{{ }}` resta sicuro con i dati utente',
`<div>{{{icon}}} {{label}}</div>`,
{icon:'<svg class="wo-lock"></svg>',label:'<script>alert(1)</script>'});
add('10. `unless` (messaggio quando manca qualcosa)',
`{{#unless email}}<span class="wo-muted">email non indicata</span>{{else}}{{email}}{{/unless}}`,
{email:''});
module.exports=ex;
if(require.main===module){ for(const e of ex){ console.log('##',e.title); console.log(e.out,'\n'); } }
