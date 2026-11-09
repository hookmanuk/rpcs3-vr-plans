"""pakmatch.py INDEX.tsv DUMPDIR: each shader the port translated (DUMPDIR/<hash>.bin) against the same hash in the game's files."""
import os, sys, struct, collections
G=r'H:\ROMs\uncharted\CUSA02343'
idx=collections.defaultdict(list)
for l in open(sys.argv[1]):
    f,off,length,h,crc=l.rstrip('\n').split('\t'); idx[h].append((f,int(off),int(length)))
res=collections.Counter(); bad=[]
for fn in sorted(os.listdir(sys.argv[2])):
    h=fn[:-4]; R=open(os.path.join(sys.argv[2],fn),'rb').read()
    rows=idx.get(h)
    if not rows: res['hash not in the game files']+=1; bad.append((h,'missing')); continue
    tok,dw1=struct.unpack_from('<II',R,0)
    same=0; diff=0
    for f,off,length in rows:
        start=off-(dw1+1)*8 if tok==0xBEEB03FF else off-len(R)
        with open(os.path.join(G,f),'rb') as fh:
            fh.seek(start); P=fh.read(len(R))
        if P==R: same+=1
        else: diff+=1
    res['all copies identical' if diff==0 else ('some copies differ' if same else 'no copy matches')]+=1
    if diff: bad.append((h,f'{same} same {diff} differ of {len(rows)}'))
    res['copies']+=len(rows)
print(dict(res)); print(bad[:10])
