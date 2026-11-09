import sys, numpy as np
from scipy.ndimage import gaussian_filter as G, binary_dilation as D
from PIL import Image, ImageDraw
N=2160
def e(n,k): return np.fromfile(f'ds_{n}_{k}.raw',np.uint8)[8:].reshape(N,N,4)[...,:3].astype(np.float32)
def marks(on,off):
    d=(off-on).mean(2); bad=D((off.mean(2)<130)|(np.abs(d)>45),iterations=8); d=G(np.clip(d,0,45),1.0); d[bad]=0; return d,bad
def best(A,B,x0,y0,W,H):
    p=A[y0:y0+H,x0:x0+W]; p=p-p.mean(); r=(-2,0)
    for s in range(-100,41):
        q=B[y0:y0+H,x0+s:x0+s+W]; q=q-q.mean(); c=(p*q).sum()/np.sqrt((p*p).sum()*(q*q).sum()+1e-6)
        if c>r[0]: r=(c,s)
    return r
rows=[]
for v in sys.argv[1:]:
    L0,R0,Ls,Rs=e(v+'_on',0),e(v+'_on',1),e(v+'_off',0),e(v+'_off',1)
    dL,bL=marks(L0,Ls); dR,bR=marks(R0,Rs)
    sL=Ls.mean(2)-G(Ls.mean(2),8); sR=Rs.mean(2)-G(Rs.mean(2),8); sL[bL]=0; sR[bR]=0
    out=[]
    for y0 in range(1340,1740,64):
        for x0 in range(620,1660,128):
            if dL[y0:y0+64,x0:x0+128].std()<1.2: continue
            m=best(dL,dR,x0,y0,128,64); t=best(sL,sR,x0,y0,128,64)
            if m[0]>0.5 and t[0]>0.5: out.append(m[1]-t[1])
    print(f'DECAL {v:>5}: blocks {len(out):3d}  median marks-minus-snow {np.median(out) if out else 0:+.1f} px  spread {np.percentile(out,25) if out else 0:+.0f}..{np.percentile(out,75) if out else 0:+.0f}')
    a=np.clip(L0,0,255).astype(np.uint8)[1380:1720,700:1560]; b=np.clip(R0,0,255).astype(np.uint8)[1380:1720,660:1520]
    im=Image.fromarray(np.concatenate([a,b],0)).resize((645,510)); ImageDraw.Draw(im).text((3,3),'DECAL '+v,fill=(255,0,0)); rows.append(np.asarray(im))
Image.fromarray(np.concatenate(rows,1)).save('ds_sheet.png')
