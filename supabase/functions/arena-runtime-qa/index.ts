import { createClient } from "npm:@supabase/supabase-js@2.89.0";
const reply=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:{"Content-Type":"application/json","Cache-Control":"no-store"}});
async function equal(a:string,b:string){const x=new Uint8Array(await crypto.subtle.digest("SHA-256",new TextEncoder().encode(a))),y=new Uint8Array(await crypto.subtle.digest("SHA-256",new TextEncoder().encode(b)));let diff=0;for(let i=0;i<x.length;i++)diff|=x[i]^y[i];return diff===0}
Deno.serve(async req=>{
 if(req.method!=="POST")return reply({error:"POST required"},405);
 const secret=Deno.env.get("ARENA_RUNTIME_WORKER_TOKEN"),url=Deno.env.get("SUPABASE_URL"),key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
 if(!secret||secret.length<32||!url||!key)return reply({error:"Worker not configured"},503);
 const received=req.headers.get("x-arena-worker-token")||"";
 if(!received||received.length>256||!await equal(received,secret))return reply({error:"Unauthorized"},401);
 let b;try{if(Number(req.headers.get("content-length"))>16000)return reply({error:"Payload too large"},413);const raw=await req.text();if(raw.length>16000)return reply({error:"Payload too large"},413);b=JSON.parse(raw)}catch{return reply({error:"Invalid request"},400)}
 const db=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
 if(b?.action==="claim"){
  const {data:j,error}=await db.rpc("runtime_claim");if(error)return reply({error:"Claim failed"},503);if(!j)return reply({job:null});
  const {data:s,error:e}=await db.storage.from("arena-private").createSignedUrl(j.path,120);
  if(e||!s?.signedUrl){await db.rpc("runtime_finish",{p_version:j.version_id,p_lease:j.lease,p_sha:j.sha,p_report:{outcome:"error",reason:"Package unavailable"}});return reply({error:"Package unavailable"},503)}
  return reply({job:{version_id:j.version_id,lease:j.lease,sha:j.sha,genre:j.genre,url:s.signedUrl}});
 }
 if(b?.action==="finish"){
  if(!/^[0-9a-f-]{36}$/i.test(b.version_id||"")||!/^[0-9a-f-]{36}$/i.test(b.lease||"")||!/^[0-9a-f]{64}$/.test(b.sha||"")||!b.report)return reply({error:"Invalid completion"},400);
  const {data,status,error}=await db.rpc("runtime_finish",{p_version:b.version_id,p_lease:b.lease,p_sha:b.sha,p_report:b.report});if(error)return reply({error:"Completion rejected"},409);return reply({status:data});
 }
 return reply({error:"Unknown action"},400);
});