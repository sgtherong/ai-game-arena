import { chromium } from 'playwright';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { resolve, extname } from 'node:path';
const root=process.cwd(), types={'.html':'text/html; charset=utf-8','.js':'application/javascript','.xml':'application/xml'};
const server=createServer(async(req,res)=>{try{let url=new URL(req.url,'http://localhost');let path=resolve(root,'.'+url.pathname+(url.pathname.endsWith('/')?'index.html':''));if(!path.startsWith(root+'/'))throw Error('invalid path');let data=await readFile(path);res.writeHead(200,{'content-type':types[extname(path)]||'text/plain'});res.end(data)}catch{res.writeHead(404);res.end('Not found')}});
await new Promise(ok=>server.listen(0,'127.0.0.1',ok));const base='http://127.0.0.1:'+server.address().port+'/';
const source=await readFile('index.html','utf8');for(const m of source.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g))if(m[1].trim())new Function(m[1]);
const browser=await chromium.launch({headless:true});
try{
for(const [name,viewport,role] of [['desktop',{width:1440,height:900},null],['mobile',{width:390,height:844},null],['admin',{width:1280,height:900},'admin']]){
const context=await browser.newContext({viewport});const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
await page.route('https://cdn.jsdelivr.net/**',async route=>{if(!route.request().url().includes('supabase'))return route.abort();const body='('+function(role){
const user=role?{id:'11111111-1111-4111-8111-111111111111',email:'qa@example.invalid'}:null;
const games=['neon','orbit','tiles'].map(id=>({id,active:id+'-version',owner:null,paused:false}));
const versions=games.map(g=>({id:g.active,game_id:g.id,status:'approved',kind:'demo',created:new Date().toISOString()}));
if(role==='admin'){games.push({id:'qa-cqs-game',active:null,owner:user.id,paused:false});versions.push({id:'qa-cqs-v1',game_id:'qa-cqs-game',name:'CQS QA fixture',label:'1.0',genre:'Arcade',description:'Temporary test fixture',status:'pending',kind:'zip',created:new Date().toISOString(),thumb_path:'qa/thumb.png',ai_status:'passed',ai_score:100,cqs_status:'waiting'});versions.push({id:'qa-runtime-v2',game_id:'qa-cqs-game',name:'Runtime QA fixture',label:'2.0',genre:'Arcade',description:'Queued test fixture',status:'pending',kind:'zip',created:new Date().toISOString(),thumb_path:'qa/thumb.png',ai_status:'passed',ai_score:100,cqs_status:'completed',cqs_score:73,cqs_grade:'B',release_class:'service',runtime_status:'queued'});}
function builder(table){let rows=table==='games'?games:table==='versions'?versions:table==='profiles'?[{id:user?.id,role}]:[];let one=false;let b={select(){return b},eq(k,v){rows=rows.filter(x=>x[k]===v);return b},order(){return b},limit(n){rows=rows.slice(0,n);return b},lte(){return b},gt(){return b},single(){one=true;return b},then(ok,fail){return Promise.resolve({data:one?rows[0]:rows,error:null}).then(ok,fail)}};return b}
window.supabase={createClient(){return {auth:{getSession:async()=>({data:{session:user?{user}:null},error:null})},from:builder,storage:{from:()=>({createSignedUrl:async()=>({data:{signedUrl:''},error:null})})},rpc:async(n)=>({data:n==='admin_overview'?{games:3,users:1,pending:0,published:3,plays:0,ratings:0,members:1,developers:0,applications:0}:[],error:null})}}};
}.toString()+')('+JSON.stringify(role)+');';await route.fulfill({contentType:'application/javascript',body})});
await page.goto(base);await page.waitForSelector('.arena-profile').catch(async e=>{throw Error('Portal load failed: '+(await page.locator('#app').innerText())+' / '+errors.join('; ')+' / '+e.message)});await page.locator('#app .hero').waitFor();
assert.equal(await page.locator('#cards .card').count(),3);
await page.locator('.cqs-tabs96 button').filter({hasText:'Service games'}).click();assert.equal(await page.locator('#cards .card').count(),0);await page.locator('.cqs-tabs96 button').filter({hasText:'Test Lab'}).click();assert.equal(await page.locator('#cards .card').count(),3);
assert.equal(await page.locator('#nav button').filter({hasText:/Admin|Developer|Studio/}).count(),0);
if(name==='mobile'){assert(await page.locator('#arenaBottom8').isVisible());assert(!(await page.locator('#nav .portal-link').first().isVisible()));}
await page.locator('#cards button').first().click();await page.locator('#game').waitFor();assert(await page.locator('#start').isVisible());assert(await page.getByRole('heading',{name:'Independent evaluation'}).isVisible());
await page.locator('header .logo').click();await page.locator('#cards').waitFor();
if(role==='admin'){await page.locator('.arena-profile summary').click();await page.locator('.arena-profile button').filter({hasText:'Admin Console'}).click();await page.locator('#arenaSide8').waitFor();assert(await page.locator('#arenaSide8').isVisible());assert.equal(await page.locator('#nav .portal-link').count(),0);await page.locator('#arenaSide8 button').filter({hasText:'Review queue'}).click();await page.getByText('CQS must complete with ≥60 before approval.').waitFor();await page.getByText('Requested runtime QA must pass before approval.').waitFor();assert.equal(await page.getByRole('button',{name:'Approve',exact:true}).count(),0);await page.locator('.arena-profile summary').click();await page.locator('.arena-profile button').filter({hasText:'Creator Studio'}).click();await page.locator('#arenaSide8 button').filter({hasText:'My games / Submit'}).click();await page.locator('.cqs-form96').waitFor();assert.equal(await page.locator('.cqs-form96 input[type=file]').getAttribute('multiple'),'');}
assert.deepEqual(errors,[],name+' page errors');await context.close();console.log('PASS '+name);
}
for(const path of ['games/neon/','games/orbit/','games/tiles/','sitemap.xml','policies/terms.html','policies/privacy.html','policies/submissions.html']){let r=await fetch(base+path);assert.equal(r.status,200,path);console.log('PASS '+path)}
}finally{await browser.close();server.close()}
