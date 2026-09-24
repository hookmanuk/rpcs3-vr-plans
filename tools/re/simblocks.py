import json, sys, numpy as np
from collections import Counter
cap=sys.argv[1]; order=[int(x) for x in sys.argv[2].split(",")]; ASP=len(sys.argv)>3
recs=[json.loads(l) for l in open(cap)]
d=[r for r in recs if r.get('type')=='draw' and r['rt']['width']==1280 and r['rt']['height']==720]
def blk(cs,b):
    if not all(k in cs for k in range(b,b+4)): return None
    if not all(np.isfinite(cs[b+k]).all() for k in range(4)): return None
    return np.stack([cs[b+k] for k in range(4)])
def persp(M): return not np.allclose(M[:,3],[0,0,0,1],atol=1e-6)
def rigid(M):
    x,y,w=M[:3,0],M[:3,1],M[:3,3]; n=[np.linalg.norm(v) for v in (x,y,w)]
    if min(n)<1e-8: return False
    return max(abs(x@y)/n[0]/n[1],abs(x@w)/n[0]/n[2],abs(y@w)/n[1]/n[2])<=0.1
def aspect(M):
    x,y,w=M[:3,0],M[:3,1],M[:3,3]; return abs((np.linalg.norm(y)/np.linalg.norm(x))/1.7778-1)<0.1
res=Counter(); bad=[]
for r in d:
    cs={c['c']:np.array([np.nan if v is None else v for v in c['f']],dtype=float) for c in r['constants']}
    ref=None
    for b in range(250,280):
        M=blk(cs,b)
        if M is not None and persp(M) and rigid(M) and aspect(M): ref=b; break
    got=None
    for b in order:
        M=blk(cs,b)
        if M is not None and persp(M) and rigid(M) and (not ASP or aspect(M)): got=b; break
    res[(ref,got)]+=1
    if ref!=got: bad.append((r['draw'],r['vp_session_id'],ref,got))
for k,v in sorted(res.items(),key=lambda x:-x[1]): print(k,v)
print('mismatch',len(bad),bad[:10])
