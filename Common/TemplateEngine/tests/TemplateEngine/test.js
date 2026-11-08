const {render,oldRender}=require('./port.js'); const fs=require('fs'); let fail=0;
const eq=(n,a,b)=>{ if(a!==b){fail++;console.log('FAIL',n,'\n  got:',JSON.stringify(a),'\n  exp:',JSON.stringify(b));} else console.log('ok  ',n); };
eq('var',render('Ciao {{n}}',{n:'a<b&c'}),'Ciao a&lt;b&amp;c');
eq('raw',render('{{{h}}}|{{h}}',{h:'<b>x</b>'}),'<b>x</b>|&lt;b&gt;x&lt;/b&gt;');
eq('path',render('{{a.b.c}}',{a:{b:{c:7}}}),'7');
eq('missing',render('[{{x}}][{{a.z}}]',{a:{}}),'[][]');
eq('each',render('{{#each l}}<{{n}}>{{/each}}',{l:[{n:1},{n:2}]}),'<1><2>');
eq('each else',render('{{#each l}}x{{else}}vuoto{{/each}}',{l:[]}),'vuoto');
eq('each missing else',render('{{#each l}}x{{else}}vuoto{{/each}}',{}),'vuoto');
eq('each this',render('{{#each t}}[{{this}}]{{/each}}',{t:['a','<']}),'[a][&lt;]');
eq('if true',render('{{#if a}}Y{{/if}}',{a:1}),'Y');
eq('if false vals',['',0,null,false,[],undefined].map(v=>render('{{#if a}}Y{{else}}N{{/if}}',{a:v})).join(''),'NNNNNN');
eq('if truthy vals',['x','false',-1,[0],{}].map(v=>render('{{#if a}}Y{{else}}N{{/if}}',{a:v})).join(''),'YYYYY');
eq('unless',render('{{#unless a}}N{{else}}Y{{/unless}}',{a:true})+render('{{#unless a}}N{{/unless}}',{a:0}),'YN');
eq('nested each',render('{{#each g}}{{n}}:{{#each r}}{{this}},{{/each}};{{/each}}',{g:[{n:'a',r:[1,2]},{n:'b',r:[]}]}),'a:1,2,;b:;');
eq('parent ../',render('{{#each l}}{{../t}}-{{n}} {{/each}}',{t:'T',l:[{n:1},{n:2}]}),'T-1 T-2 ');
eq('parent ../../',render('{{#each a}}{{#each b}}{{../../t}}{{../n}}{{x}} {{/each}}{{/each}}',{t:'T',a:[{n:'N',b:[{x:1}]}]}),'TN1 ');
eq('if in each',render('{{#each l}}{{#if on}}[{{n}}]{{/if}}{{/each}}',{l:[{n:1,on:true},{n:2,on:false},{n:3,on:1}]}),'[1][3]');
eq('each in if',render('{{#if l}}{{#each l}}{{this}}{{/each}}{{else}}none{{/if}}',{l:[1,2]}),'12');
eq('else belongs to inner',render('{{#if a}}{{#if b}}1{{else}}2{{/if}}{{else}}3{{/if}}',{a:1,b:0}),'2');
eq('else outer',render('{{#if a}}{{#if b}}1{{else}}2{{/if}}{{else}}3{{/if}}',{a:0,b:0}),'3');
eq('partial tree',render('<ul>{{#each n}}<li>{{name}}{{#if kids}}{{> tree}}{{/if}}</li>{{/each}}</ul>'.replace('{{> tree}}','<ul>{{#each kids}}{{> node}}{{/each}}</ul>').replace(/^.*$/,'{{#each n}}{{> node}}{{/each}}'),{n:[{name:'a',kids:[{name:'b',kids:[]}]},{name:'c'}]},{node:'<li>{{name}}{{#if kids}}<ul>{{#each kids}}{{> node}}{{/each}}</ul>{{/if}}</li>'}),'<li>a<ul><li>b</li></ul></li><li>c</li>');
eq('recursion cap',render('{{> x}}',{}, {x:'a{{> x}}'}).length<=40,true);
eq('unclosed',render('a{{#if x}}b',{x:1}),'a{{#if x}}b');
eq('orphan',render('{{/if}}{{else}}',{}),'{{/if}}{{else}}');
eq('unknown tag',render('{{ a b }}{{!c}}',{}),'{{ a b }}{{!c}}');
eq('no double pass',render('{{v}}',{v:'{{w}}',w:'X'}),'{{w}}');
eq('ws in tag',render('{{ #if a }}Y{{ /if }}',{a:1}),'Y');
eq('attr: a-capo non diventa <br/>',render('<input value="{{v}}">',{v:'a\nb'}),'<input value="a\nb">');
eq('attr: apice singolo',render("<i title='{{v}}'>",{v:"x'y"}),"<i title='x&#39;y'>");
eq('testo: a-capo diventa <br/>',render('<p>{{v}}</p>',{v:'a\nb'}),'<p>a<br/>b</p>');
eq('testo dopo tag chiuso',render('<b>x</b>{{v}}',{v:'a\nb'}),'<b>x</b>a<br/>b');
eq('attr poi testo',render('<a title="{{t}}">{{t}}</a>',{t:'1\n2'}),'<a title="1\n2">1<br/>2</a>');
// COMPATIBILITA' con il motore vecchio su tutti i template del progetto che usano solo each a un livello
// Compatibilita': node test.js <cartella-modelli> [altre...] confronta il motore nuovo con il vecchio sui modelli esistenti
const dirs=process.argv.slice(2).filter(d=>fs.existsSync(d));
const data={rows:[{id:3,name:'A&B',code:'<c>',description:'d\nx',members_label:'2 membri',members_hidden:'',inactive_hidden:'hidden'}],
 roles:[{id:1,name:'n',code:'c',description:'',system_badge_hidden:'',inactive_badge_hidden:'hidden',note_hidden:'',actions_hidden:'hidden',cmms_actions_hidden:''}],
 groups:[{id:1,name:'g',checked:'checked'}],members:[{id:1,name:'m'}],assignees:[{id:1,name:'a'}],kinds:[{id:1,code:'c',description:'d',checked:''}],title:'T'};
let n=0; for(const d of dirs) for(const f of fs.readdirSync(d)){ const t=fs.readFileSync(d+'/'+f,'utf8'); if(!/\{\{/.test(t))continue; n++; eq('compat '+f,render(t,data),oldRender(t,data)); }
console.log(n,'template confrontati; fallimenti:',fail); process.exit(fail?1:0);
