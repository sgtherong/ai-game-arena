#!/usr/bin/env python3
"""Run one explicitly trusted QA job on a dedicated disposable test VM.
Do not run arbitrary public submissions: Docker alone is not a security boundary.
No worker token is passed to the browser container."""
import argparse, hashlib, json, os, pathlib, subprocess, tempfile, urllib.request, urllib.parse, uuid

MAX=2*1024*1024
p=argparse.ArgumentParser()
p.add_argument("--trusted-pilot",action="store_true",required=True)
p.add_argument("--image",default="arena-runtime-pilot:0.98")
p.add_argument("--fixture",type=pathlib.Path,help="Local trusted ZIP only; no remote job or credentials.")
args=p.parse_args()
def execute(data,plan=None):
    with tempfile.TemporaryDirectory(prefix="arena-qa-") as tmp:
        path=pathlib.Path(tmp)/"game.zip";path.write_bytes(data);path.chmod(0o444)
        name="arena-qa-"+uuid.uuid4().hex
        cmd=["docker","run","--rm","--name",name,"--network","none","--read-only","--cap-drop","ALL","--security-opt","no-new-privileges","--pids-limit","192","--memory","1g","--cpus","1","--shm-size","128m","--tmpfs","/tmp:rw,nosuid,nodev,size=384m","--env","HOME=/tmp","--env","ARENA_QA_PLAN="+json.dumps(plan or {},separators=(",",":")),"--mount","type=bind,src="+str(path)+",dst=/input/game.zip,readonly",args.image]
        try:
            out=subprocess.run(cmd,capture_output=True,text=True,timeout=65,check=False)
            lines=out.stdout.strip().splitlines()
            result=json.loads(lines[-1]) if lines else {}
            if result.get("sha")!=hashlib.sha256(data).hexdigest() or not isinstance(result.get("report"),dict):
                return {"outcome":"error","reason":"Pilot process failed or hash mismatch"}
            return result["report"]
        except Exception:
            return {"outcome":"error","reason":"Pilot process timeout or infrastructure failure"}
        finally:
            try:subprocess.run(["docker","rm","-f",name],capture_output=True,timeout=10,check=False)
            except Exception:pass
if args.fixture:
    data=args.fixture.read_bytes()
    if len(data)>MAX:raise SystemExit("Fixture too large")
    print(json.dumps(execute(data),ensure_ascii=False));raise SystemExit(0)
token=os.environ.get("ARENA_RUNTIME_WORKER_TOKEN","")
base=os.environ.get("ARENA_SUPABASE_URL","").rstrip("/")
if len(token)<32 or urllib.parse.urlsplit(base).scheme!="https":raise SystemExit("Set worker token and HTTPS project URL")
endpoint=base+"/functions/v1/arena-runtime-qa"
def call(body):
    req=urllib.request.Request(endpoint,data=json.dumps(body).encode(),headers={"Content-Type":"application/json","x-arena-worker-token":token},method="POST")
    with urllib.request.urlopen(req,timeout=30) as r:return json.load(r)
job=call({"action":"claim"}).get("job")
if not job:print("No QA jobs");raise SystemExit(0)
report={"outcome":"error","reason":"Package download or hash validation failed"}
try:
    u=urllib.parse.urlsplit(job["url"]);b=urllib.parse.urlsplit(base)
    if u.scheme!="https" or u.netloc!=b.netloc:raise ValueError("Unexpected signed URL")
    with urllib.request.urlopen(job["url"],timeout=25) as f:
        if urllib.parse.urlsplit(f.geturl()).netloc!=b.netloc:raise ValueError("Unexpected redirect")
        data=f.read(MAX+1)
    if len(data)>MAX or hashlib.sha256(data).hexdigest()!=job["sha"]:raise ValueError("Package mismatch")
    report=execute(data,job.get("plan"))
except Exception:pass
result=call({"action":"finish","version_id":job["version_id"],"lease":job["lease"],"sha":job["sha"],"report":report})
print("QA",job["version_id"],result.get("status"))
