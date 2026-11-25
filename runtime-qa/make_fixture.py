#!/usr/bin/env python3
"""Generate a first-party smoke fixture only; never substitute user uploads in CI."""
import pathlib, zipfile, sys
target=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "trusted-fixture.zip")
html='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><link rel="icon" href="data:,"><title>Arena Runtime Fixture</title><style>body{margin:0;font:16px system-ui;background:#172338;color:white}main{max-width:100%;padding:12px;box-sizing:border-box;text-align:center}canvas{width:min(100%,600px);height:auto;display:block;margin:auto;background:#213e49}button{margin:8px;padding:10px}</style><main><h1>Trusted smoke fixture</h1><canvas width="600" height="300"></canvas><button>Tap</button><p id="score">0</p></main><script>let n=0,c=document.querySelector("canvas"),x=c.getContext("2d");x.fillStyle="#b8f178";x.fillRect(260,100,80,80);function hit(){document.querySelector("#score").textContent=++n}document.querySelector("button").onclick=hit;c.onclick=hit;document.onkeydown=hit;</script></html>'''
with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as z:z.writestr('index.html',html)
print(target)
