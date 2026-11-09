"""pakindex.py OUT.tsv: every PS4 shader footer (OrbShdr) in the game's files: file, footer offset, code length, hash, crc."""
import os, sys, mmap, struct, time
G=r'H:\ROMs\uncharted\CUSA02343'; out=open(sys.argv[1],'w'); n=0; t=time.time(); size=0
for r,_,fs in os.walk(G):
    for f in fs:
        p=os.path.join(r,f); sz=os.path.getsize(p)
        if sz<64: continue
        with open(p,'rb') as h:
            m=mmap.mmap(h.fileno(),0,access=mmap.ACCESS_READ); i=m.find(b'OrbShdr')
            while i>=0:
                if i+28<=len(m):
                    bits=struct.unpack_from('<I',m,i+8)[0]; length=bits>>8
                    hsh,crc=struct.unpack_from('<QI',m,i+16)
                    out.write(f'{os.path.relpath(p,G)}\t{i}\t{length}\t{hsh:016x}\t{crc:08x}\n'); n+=1
                i=m.find(b'OrbShdr',i+7)
            m.close()
        size+=sz
print('footers',n,'GB',round(size/1e9,1),'s',round(time.time()-t))
