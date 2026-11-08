// Port JS 1:1 dell'algoritmo di TemplateEngine.pas (per verificarne la logica con Node)
const esc=s=>String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;').replace(/\r\n|\n|\r/g,'<br/>');
const escAttr=s=>String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
const inTag=o=>o.lastIndexOf('<')>o.lastIndexOf('>');
const isDefined=v=>v!==undefined&&v!==null;
function getPath(o,p){ if(!o||p==='')return null; let c=o; for(const k of p.split('.')){ if(c==null||!Object.prototype.hasOwnProperty.call(c,k)) return null; c=c[k]; } return c; }
const sw=(t,p)=>t.substring(0,p.length)===p;
function scopeValue(sc,path){ let up=0; while(sw(path,'../')){up++;path=path.substring(3);} const idx=sc.length-1-up; if(idx<0)return null; const cur=sc[idx]; if(path==='this')return cur; if(sw(path,'this.'))path=path.substring(5); if(path===''||!isDefined(cur))return null; return getPath(cur,path); }
function truthy(v){ if(!isDefined(v))return false; if(typeof v==='boolean')return v; if(typeof v==='string')return v!==''; if(typeof v==='number')return v!==0; if(Array.isArray(v))return v.length>0; return true; }
function isPath(t){ return t!==''&&/^[A-Za-z0-9_.\/]+$/.test(t); }
function findEnd(t,from){ let depth=1,pos=from,el=-1,ela=-1; for(;;){ const o=t.indexOf('{{',pos); if(o<0)return null; const c=t.indexOf('}}',o+2); if(c<0)return null; const tag=t.substring(o+2,c).trim();
 if(sw(tag,'#each ')||sw(tag,'#if ')||sw(tag,'#unless '))depth++; else if(tag==='/each'||tag==='/if'||tag==='/unless'){depth--; if(depth===0)return{el,ela,end:o,after:c+2};} else if(tag==='else'&&depth===1&&el<0){el=o;ela=c+2;} pos=c+2; } }
function block(kind,arg,body,elseBody,hasElse,sc,pa,d){ let r=''; const v=scopeValue(sc,arg);
 if(kind==='each'){ if(isDefined(v)&&Array.isArray(v)&&v.length>0){ for(const it of v){sc.push(it); r+=rs(body,sc,pa,d+1); sc.pop();} } else if(hasElse) r=rs(elseBody,sc,pa,d+1); }
 else if(kind==='if'){ if(truthy(v)) r=rs(body,sc,pa,d+1); else if(hasElse) r=rs(elseBody,sc,pa,d+1); }
 else { if(!truthy(v)) r=rs(body,sc,pa,d+1); else if(hasElse) r=rs(elseBody,sc,pa,d+1); } return r; }
function rs(t,sc,pa,d){ let r=''; if(d>32)return r; let pos=0;
 while(pos<t.length){ const o=t.indexOf('{{',pos); if(o<0){r+=t.substring(pos);break;} r+=t.substring(pos,o);
  if(t.substring(o,o+3)==='{{{'){ const c=t.indexOf('}}}',o+3); if(c<0){r+=t.substring(o);break;} const a=t.substring(o+3,c).trim(); if(isPath(a)){const v=scopeValue(sc,a); if(isDefined(v)) r+=String(v);} else r+=t.substring(o,c+3); pos=c+3; continue; }
  const c=t.indexOf('}}',o+2); if(c<0){r+=t.substring(o);break;} const after=c+2; const tag=t.substring(o+2,c).trim();
  let kind=''; if(sw(tag,'#each '))kind='each'; else if(sw(tag,'#if '))kind='if'; else if(sw(tag,'#unless '))kind='unless';
  if(kind){ const arg=tag.substring(kind.length+1).trim(); const f=findEnd(t,after); if(f){ const has=f.el>=0; const body=has?t.substring(after,f.el):t.substring(after,f.end); const eb=has?t.substring(f.ela,f.end):''; r+=block(kind,arg,body,eb,has,sc,pa,d); pos=f.after; } else { r+=t.substring(o,after); pos=after; } continue; }
  if(sw(tag,'> ')){ const n=tag.substring(2).trim(); if(isDefined(pa)&&Object.prototype.hasOwnProperty.call(pa,n)) r+=rs(String(pa[n]),sc,pa,d+1); pos=after; continue; }
  if(isPath(tag)&&tag!=='else'&&!sw(tag,'/')){ const v=scopeValue(sc,tag); if(isDefined(v)) r+=inTag(r)?escAttr(v):esc(v);} else r+=t.substring(o,after); pos=after; }
 return r; }
const render=(t,d,p)=>rs(t,[d],p||null,0);
// motore VECCHIO (copia fedele)
function oldRender(tpl,data){ const simple=(t,o)=>t.replace(/\{\{([\w\.]+)\}\}/g,(m,p)=>{const v=getPath(o,p);return v!=null?esc(v):'';});
 const re=/\{\{#each\s+([\w\.]+)\}\}(.*?)\{\{\/each\}\}/gs; let out='',last=0,m; while((m=re.exec(tpl))){ out+=tpl.substring(last,m.index); const arr=getPath(data,m[1]); let b=''; if(arr!=null&&Array.isArray(arr)) for(const it of arr) b+=simple(m[2],it); out+=b; last=re.lastIndex; } if(last<tpl.length)out+=tpl.substring(last); return simple(out,data); }
module.exports={render,oldRender,esc};
