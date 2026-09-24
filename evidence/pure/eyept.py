import json, sys, numpy as np, collections
recs=[json.loads(l) for l in open(sys.argv[1])]
draws=[r for r in recs if r['type']=='draw']
res=collections.Counter(); persp=collections.Counter(); samples=[]
for d in draws:
    c={x['c']:x['f'] for x in d['constants']}
    if not all(26+k in c for k in range(4)): continue
    M=np.array([c[26+k] for k in range(4)])
    isp = not np.allclose(M[3],[0,0,0,1],atol=1e-6)
    persp[(d['rt']['width'],d['rt']['height'],isp)]+=1
    if not isp: continue
    # eye point in object space: rows 0,1,3 dot (p,1) = 0
    A=M[[0,1,3],:3]; b=-M[[0,1,3],3]
    p=np.linalg.solve(A,b)
    # to world via c[22..25] if present (affine world, DP4 rows)
    if all(22+k in c for k in range(4)):
        W=np.array([c[22+k] for k in range(4)]); pw=W[:3,:3]@p+W[:3,3]
    else: pw=p
    samples.append((d['draw'],d['vp_storage_hash'][:8],np.round(pw,2),'18' if 18 in c else ''))
print(persp)
for s in samples[::25]: print(s)
