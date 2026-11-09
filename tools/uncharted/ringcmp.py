import sys, glob, struct, numpy as np
from PIL import Image
imgs=[]
for p in sys.argv[2:]:
    d=open(p,'rb').read(); w,h,n=struct.unpack('<III',d[:12])
    f=np.frombuffer(d[12:12+w*h*4*n],np.uint8).reshape(n,h,w,4)[...,:3].astype(np.float32).mean(3)
    df=np.abs(np.diff(f,axis=0)); p90=np.percentile(df,90,axis=0)
    med=np.median(f,axis=0); dev=np.abs(f-med)
    frac=(dev>15).mean(0)  # per pixel fraction of frames off the median by >15
    L=p90[:, :w//2]; R=p90[:, w//2:]
    print(f'{p:40s} n={n} p90>10: L {(L>10).mean()*100:.2f}% R {(R>10).mean()*100:.2f}%  off-median>15 in >3% frames: {(frac>0.03).mean()*100:.2f}%')
    imgs.append(np.clip(p90[:, :w//2]*8,0,255).astype(np.uint8)[::2,::2])
Image.fromarray(np.concatenate([np.concatenate(imgs[i:i+3],1) for i in range(0,len(imgs),3)],0)).save(sys.argv[1])
