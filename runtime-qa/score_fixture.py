#!/usr/bin/env python3
"""Validate trusted runtime observations and calculate the same RQS as the DB."""
import json, re, sys
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

def score(report):
    assert report['outcome']=='completed' and report['policy']=='runtime-smoke-v1' and report['evidence_policy']=='rqs-observation-v1', report
    values={}
    for k in ('desktop','mobile'):
        d=report[k]
        for x in ('loaded','visible','input_dispatched','responsive','screen_changed'):
            assert type(d[x]) is bool, (k,x)
        for x in ('page_errors','blocked_requests','load_ms','actions'):
            assert type(d[x]) is int and d[x]>=0,(k,x)
        assert 0<d['actions']<=12 and 0<=d['raf_fps']<=240,d
        assert re.fullmatch('[0-9a-f]{64}',d['before_sha']) and re.fullmatch('[0-9a-f]{64}',d['after_sha']),d
        assert d['screen_changed']==(d['before_sha']!=d['after_sha']),d
        assert all(d[x] for x in ('loaded','visible','input_dispatched','responsive')),d
        assert d['page_errors']==0 and d['blocked_requests']==0,d
        f=d['raf_fps'];ms=d['load_ms']
        values[k]=20+15+15+20+10+(5 if d['screen_changed'] else 0)+(10 if f>=50 else 7 if f>=30 else 3 if f>=15 else 0)+(5 if ms<=2000 else 3 if ms<=5000 else 0)
    return {'desktop':values['desktop'],'mobile':values['mobile'],'rqs':int((Decimal(sum(values.values()))/2).quantize(Decimal('1'),rounding=ROUND_HALF_UP))}
if __name__=='__main__':
    report=json.loads(Path(sys.argv[1]).read_text())
    print(json.dumps(score(report)))
