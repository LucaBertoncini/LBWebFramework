const {render}=require('./port.js');
const file=`<!-- @tree -->
<ul class="cmms-exclusion-root">{{#each nodes}}{{> node}}{{/each}}</ul>

<!-- @node -->
<li class="cmms-exclusion-node" data-uuid="{{uuid}}">
  <div class="cmms-exclusion-row">
    <input type="checkbox" class="cmms-exclusion-chk" data-uuid="{{uuid}}" {{checked}}>
    <span class="cmms-exclusion-name">{{name}}</span>
    {{#if code}}<span class="cmms-exclusion-code">({{code}})</span>{{/if}}
  </div>
  {{#if children}}
  <ul class="cmms-exclusion-nested">{{#each children}}{{> node}}{{/each}}</ul>
  {{/if}}
</li>`;
// come LoadTemplateSections
function sections(t){ const re=/<!--\s*@([\w-]+)\s*-->/g; const o={}; let m,pn='',ps=0; while((m=re.exec(t))){ if(pn)o[pn]=t.substring(ps,m.index).trim(); pn=m[1]; ps=re.lastIndex; } if(pn)o[pn]=t.substring(ps).trim(); return o; }
const parts=sections(file);
// risposta del server: elenco piatto con parent_uuid
const flat=[{uuid:'u1',parent_uuid:null,name:'Stabilimento',code:'ST'},{uuid:'u2',parent_uuid:'u1',name:'Linea 1',code:'L1'},{uuid:'u3',parent_uuid:'u2',name:'Estrusore <A&B>',code:''},{uuid:'u4',parent_uuid:'u1',name:'Linea 2',code:'L2'}];
const excluded={u4:true};
// nestFlatList
const map=new Map(); flat.forEach(i=>{i.children=[];map.set(i.uuid,i);}); const forest=[]; flat.forEach(i=>{ const p=i.parent_uuid&&map.get(i.parent_uuid); if(p)p.children.push(i); else forest.push(i); });
const mark=a=>a.forEach(n=>{n.checked=excluded[n.uuid]?'checked':''; mark(n.children);}); mark(forest);
const out=render(parts.tree,{nodes:forest},parts);
module.exports={file,flat,forest,out,parts};
if(require.main===module){console.log(out);console.log(Object.keys(parts));}
