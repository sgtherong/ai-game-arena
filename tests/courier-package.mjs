import { chromium } from 'playwright';
import { mkdir, stat, readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
const file=resolve('games/skyline-courier/index.html'),out=resolve('courier-review');await mkdir(out,{recursive:true});
const source=await readFile(file,'utf8');assert(Buffer.byteLength(source)<60000);
assert(!/\b(eval\s*\(|new\s+Function\s*\(|WebSocket\s*\(|XMLHttpRequest\b|sendBeacon\s*\(|fetch\s*\(|serviceWorker\b|document\.cookie\b|indexedDB\b|localStorage\b|sessionStorage\b|window\.open\s*\()/i.test(source));
for(const m of source.matchAll(/<script>([\s\S]*?)<\/script>/g))new Function(m[1]);
const browser=await chromium.launch({headless:true});
try{
 const page=await browser.newPage({viewport:{width:1000,height:850}});let errors=[];page.on('pageerror',e=>errors.push(e.message));await page.addInitScript(()=>{Math.random=()=>.4});
 await page.goto(pathToFileURL(file).href);await page.locator('#districts button').first().waitFor();
 const capture=async(name,p=page)=>{const f=resolve(out,name+'.jpg');await p.screenshot({path:f,type:'jpeg',quality:78,fullPage:false});assert((await stat(f)).size<=1024*1024,name+' size');};
 await capture('thumbnail');await capture('01-menu');
 await page.locator('#start').click();
 const advance=async(seconds)=>page.evaluate(seconds=>{cancelAnimationFrame(raf);for(let n=0;n<Math.ceil(seconds/.04)&&phase==='play';n++)update(.04);draw();return {phase,parcels:s.parcels,score:s.score,hp:s.hp,time:s.time}},seconds);
 let first=await advance(8);assert.equal(first.phase,'play');assert(first.parcels>0);await capture('02-gameplay');
 first=await advance(45);assert.equal(first.phase,'result');assert(await page.locator('#next').isEnabled());assert.match(await page.locator('#result-title').innerText(),/Delivery complete/);await capture('03-result');
 await page.locator('#next').click();assert.equal(await page.locator('[data-route="1"]').getAttribute('aria-pressed'),'true');assert(await page.locator('[data-upgrade="0"]').isEnabled());await page.locator('[data-upgrade="0"]').click();assert.match(await page.locator('[data-upgrade="0"]').innerText(),/Lv.1/);await capture('04-garage');
 await page.locator('#start').click();assert.equal(await page.locator('#hp').innerText(),'4/4');let second=await advance(50);assert.equal(second.phase,'result');assert(await page.locator('#next').isEnabled());await page.locator('#next').click();await page.locator('#start').click();let third=await advance(55);assert.equal(third.phase,'result');assert.match(await page.locator('#result-title').innerText(),/Delivery complete/);assert(await page.locator('#next').isDisabled());
 await page.locator('#garage').click();assert.match(await page.locator('#rank').innerText(),/3\/3/);assert.deepEqual(errors,[]);
 const mobile=await browser.newPage({viewport:{width:390,height:844},hasTouch:true,isMobile:true});let mobileErrors=[];mobile.on('pageerror',e=>mobileErrors.push(e.message));await mobile.goto(pathToFileURL(file).href);await mobile.locator('#start').tap();await mobile.locator('#board').waitFor({state:'visible'});await mobile.locator('#right').tap();assert.match(await mobile.locator('#status').innerText(),/Lane 3/);await capture('05-mobile',mobile);assert(await mobile.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2));assert.deepEqual(mobileErrors,[]);
 const report={kind:'first-party-candidate',source_sha256:createHash('sha256').update(source).digest('hex'),desktop:'passed',mobile:'passed',campaign:'deterministic accelerated simulation: 3 districts cleared, armor upgrade verified',screenshots:5,commercial_approval:'not assessed',sqs:'not run',cqs:'not run'};
 await writeFile(resolve(out,'qa-report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
}finally{await browser.close()}
