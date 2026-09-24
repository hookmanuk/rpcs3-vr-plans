import json, sys, collections
recs=[json.loads(l) for l in open(sys.argv[1])]
draws=[r for r in recs if r['type']=='draw']
shaders={r['vp_storage_hash']:r for r in recs if r['type']=='shader'}
print('draws',len(draws))
# render targets in order (runs)
runs=[]
for d in draws:
    key=(d['rt']['width'],d['rt']['height'],d['rt']['color_addresses'][0] if any(d['rt']['color_write_enabled']) else None, d['rt']['zeta_address'])
    if runs and runs[-1][0]==key: runs[-1][2]=d['draw']; runs[-1][3]+=1
    else: runs.append([key,d['draw'],d['draw'],1])
for k,a,b,n in runs: print(f"draws {a:4}-{b:4} n={n:4} rt {k[0]}x{k[1]} color={hex(k[2]) if k[2] else '-'} z={hex(k[3])}")
# slot usage
use=collections.Counter()
for d in draws:
    for c in d['constants']: use[c['c']]+=1
print('slot usage (top 60):', sorted(use.items(), key=lambda x:-x[1])[:60])
