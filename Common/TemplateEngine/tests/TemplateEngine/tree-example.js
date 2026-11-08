const {render}=require('./port.js');
const file=`<!-- @tree -->
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
</li>`;
// come LoadTemplateSections
function sections(t){ const re=/<!--\s*@([\w-]+)\s*-->/g; const o={}; let m,pn='',ps=0; while((m=re.exec(t))){ if(pn)o[pn]=t.substring(ps,m.index).trim(); pn=m[1]; ps=re.lastIndex; } if(pn)o[pn]=t.substring(ps).trim(); return o; }
const parts=sections(file);
// risposta del server: elenco piatto con parent_uuid
const flat=[{uuid:'u1',parent_uuid:null,name:'Radice',code:'R'},{uuid:'u2',parent_uuid:'u1',name:'Ramo 1',code:'B1'},{uuid:'u3',parent_uuid:'u2',name:'Foglia <A&B>',code:''},{uuid:'u4',parent_uuid:'u1',name:'Ramo 2',code:'B2'}];
const checkedSet={u4:true};
// nestFlatList
const map=new Map(); flat.forEach(i=>{i.children=[];map.set(i.uuid,i);}); const forest=[]; flat.forEach(i=>{ const p=i.parent_uuid&&map.get(i.parent_uuid); if(p)p.children.push(i); else forest.push(i); });
const mark=a=>a.forEach(n=>{n.checked=checkedSet[n.uuid]?'checked':''; mark(n.children);}); mark(forest);
const out=render(parts.tree,{nodes:forest},parts);
module.exports={file,flat,forest,out,parts};
if(require.main===module){console.log(out);console.log(Object.keys(parts));}
