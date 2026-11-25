import { chromium } from 'playwright';
import { readFile } from 'node:fs/promises';
import { inflateRawSync } from 'node:zlib';
import { createServer } from 'node:http';
import { createHash } from 'node:crypto';
const MAX=2*1024*1024;
function unpack(b){
 if(b.length<22||b.length>MAX)throw Error('ZIP size');
 let end=-1;for(let i=b.length-22;i>=Math.max(0,b.length-65557);i--)if(b.readUInt32LE(i)===0x06054b50&&i+22+b.readUInt16LE(i+20)===b.length){end=i;break}
 if(end<0||b.readUInt16LE(end+4)||b.readUInt16LE(end+6))throw Error('ZIP directory');
 let count=b.readUInt16LE(end+10),p=b.readUInt32LE(end+16),stop=p+b.readUInt32LE(end+12),total=0,files=new Map();
 if(!count||count>100||stop>end)throw Error('ZIP limits');
 for(let i=0;i<count;i++){
  if(p+46>stop||b.readUInt32LE(p)!==0x02014b50)throw Error('ZIP entry');
  let flag=b.readUInt16LE(p+8),method=b.readUInt16LE(p+10),packed=b.readUInt32LE(p+20),size=b.readUInt32LE(p+24),nl=b.readUInt16LE(p+28),xl=b.readUInt16LE(p+30),cl=b.readUInt16LE(p+32),mode=b.readUInt32LE(p+38)>>>16,loc=b.readUInt32LE(p+42);
  if(p+46+nl+xl+cl>stop||flag&1||![0,8].includes(method)||(mode&0xf000)===0xa000)throw Error('Unsafe ZIP entry');
  let name=new TextDecoder('utf-8',{fatal:true}).decode(b.subarray(p+46,p+46+nl));p+=46+nl+xl+cl;
  if(!name||name.startsWith('/')||name.includes('\\')||name.includes(':')||/[\x00-\x1f]/.test(name)||name.split('/').some(s=>s==='..'||s==='.'))throw Error('Unsafe ZIP path');
  if(name.endsWith('/'))continue;
  if(files.has(name)||loc+30>stop||b.readUInt32LE(loc)!==0x04034b50)throw Error('Invalid ZIP entry');
  total+=size;if(total>MAX)throw Error('Expanded ZIP limit');
  let start=loc+30+b.readUInt16LE(loc+26)+b.readUInt16LE(loc+28);if(start+packed>stop)throw Error('ZIP data bounds');
  let data=b.subarray(start,start+packed);if(method===8)data=inflateRawSync(data,{maxOutputLength:Math.max(1,size)});
  if(data.length!==size)throw Error('ZIP size mismatch');files.set(name,data);
 }
 if(p!==stop)throw Error('ZIP directory mismatch');
 let entry=files.has('index.html')?'index.html':[...files.keys()].filter(x=>x.endsWith('/index.html')).length===1?[...files.keys()].find(x=>x.endsWith('/index.html')):null;
 if(!entry)throw Error('index missing');return {files,entry};
}
const mime={html:'text/html; charset=utf-8',htm:'text/html; charset=utf-8',js:'application/javascript',css:'text/css',json:'application/json',txt:'text/plain',png:'image/png',jpg:'image/jpeg',jpeg:'image/jpeg',webp:'image/webp',gif:'image/gif',mp3:'audio/mpeg',wav:'audio/wav',ogg:'audio/ogg',mp4:'video/mp4'};
async function main(){
 const b=await readFile('/input/game.zip');const {files,entry}=unpack(b);const sha=createHash('sha256').update(b).digest('hex');
 const server=createServer((req,res)=>{try{const u=new URL(req.url,'http://127.0.0.1'),path=decodeURIComponent(u.pathname.slice(1));const data=files.get(path),type=mime[path.split('.').pop()?.toLowerCase()];if(req.method!=='GET'||!data||!type){res.writeHead(404);return res.end()}res.writeHead(200,{'Content-Type':type,'X-Content-Type-Options':'nosniff','Cache-Control':'no-store','Content-Security-Policy':"default-src 'self' data: blob:; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src 'none'; object-src 'none'; frame-src 'none'; form-action 'none'; base-uri 'none'"});res.end(data)}catch{res.writeHead(400);res.end()}});
 await new Promise(ok=>server.listen(0,'127.0.0.1',ok));const origin='http://127.0.0.1:'+server.address().port, target=origin+'/'+entry.split('/').map(encodeURIComponent).join('/');
 let browser;try{
 browser=await chromium.launch({headless:true,chromiumSandbox:false,args:['--disable-dev-shm-usage','--disable-background-networking']});
 const report={outcome:'completed',policy:'runtime-smoke-v1',evidence_policy:'rqs-observation-v1',scope:'trusted pilot; screenshot change and browser rAF sample, not verified input causality, gameplay completion or malware certification',plan_source:'scripted'};
 for(let [name,viewport,mobile] of [['desktop',{width:1280,height:720},false],['mobile',{width:390,height:844},true]]){
  const ctx=await browser.newContext({viewport,hasTouch:mobile,isMobile:mobile,serviceWorkers:'block',acceptDownloads:false});let page=await ctx.newPage();let errors=0,blocked=0;
  const d={loaded:false,visible:false,input_dispatched:false,responsive:false,page_errors:0,blocked_requests:0,load_ms:0,actions:0,raf_fps:0,screen_changed:false,before_sha:'0'.repeat(64),after_sha:'0'.repeat(64)};
  await ctx.route('**/*',route=>{let u;try{u=new URL(route.request().url())}catch{};if(u?.origin===origin&&route.request().method()==='GET')return route.continue();blocked++;return route.abort()});
  page.on('pageerror',()=>errors++);page.on('response',r=>{if(r.status()>=400)errors++});page.on('popup',p=>{blocked++;p.close().catch(()=>{})});
  try{let start=Date.now();let response=await page.goto(target,{waitUntil:'domcontentloaded',timeout:10000});d.loaded=!!response?.ok();d.load_ms=Date.now()-start;await page.waitForTimeout(900);
   let check=await page.evaluate(()=>{const shown=e=>{let r=e.getBoundingClientRect(),s=getComputedStyle(e);return r.width>4&&r.height>4&&s.display!=='none'&&s.visibility!=='hidden'&&Number(s.opacity)>0};let els=[...document.querySelectorAll('canvas,svg,img,button,main,section')].filter(shown);let visible=els.length>0||!!document.body?.innerText.trim();return {visible,responsive:document.documentElement.scrollWidth<=innerWidth+4&&els.filter(e=>e.tagName==='CANVAS').every(e=>e.getBoundingClientRect().width<=innerWidth+4)}});
   d.visible=check.visible;d.responsive=check.responsive;
   const digest=buf=>createHash('sha256').update(buf).digest('hex');
   d.before_sha=digest(await page.screenshot({type:'png',timeout:4000}));
   const targetButton=page.getByRole('button',{name:/^(start( game)?|play( now)?|begin|시작|게임 시작|플레이)$/i}).first();
   if(await targetButton.isVisible().catch(()=>false)){await targetButton.click({timeout:1500}).catch(()=>{});d.actions++}
   for(const [rx,ry] of [[.5,.5],[.33,.5],[.67,.5]]){let x=Math.round(viewport.width*rx),y=Math.round(viewport.height*ry);if(mobile)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);d.actions++;await page.waitForTimeout(250)}
   if(!mobile){for(const key of ['ArrowLeft','ArrowRight','Space']){await page.keyboard.press(key);d.actions++}}
   d.input_dispatched=d.actions>0;
   d.raf_fps=await page.evaluate(()=>new Promise(resolve=>{let start=performance.now(),frames=0,done=false;const finish=()=>{if(done)return;done=true;resolve(Math.min(240,Math.round(1000*frames/Math.max(1,performance.now()-start)*100)/100))};setTimeout(finish,1100);function tick(){if(done)return;frames++;if(performance.now()-start>=1000)finish();else requestAnimationFrame(tick)}requestAnimationFrame(tick)}));
   d.after_sha=digest(await page.screenshot({type:'png',timeout:4000}));d.screen_changed=d.before_sha!==d.after_sha;
  }catch{errors++;if(d.before_sha==='0'.repeat(64)||d.after_sha==='0'.repeat(64))report.evidence_policy='incomplete-observation'}
  d.page_errors=Math.min(9999,errors);d.blocked_requests=Math.min(9999,blocked);report[name]=d;await ctx.close();
 }
 console.log(JSON.stringify({sha,report}));
 }finally{if(browser)await browser.close();server.close()}
}
main().catch(()=>{console.log(JSON.stringify({report:{outcome:'error',reason:'Pilot runner could not complete'}}));process.exitCode=1});
