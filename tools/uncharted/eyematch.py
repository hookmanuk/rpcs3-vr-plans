import sys, numpy as np
# eyematch.py L.raw R.raw y0 y1 x0 x1 [N=2160]: 32 px blocks of the left eye matched in the right (shift -60..20):
# residual per block (mean |diff| at the best shift). Large residuals on smooth ground: something differs per eye.
L=np.fromfile(sys.argv[1],np.uint8)[8:]; N=int(sys.argv[7]) if len(sys.argv)>7 else 2160
L=L.reshape(N,N,4)[...,:3].astype(np.float32).mean(2)
R=np.fromfile(sys.argv[2],np.uint8)[8:].reshape(N,N,4)[...,:3].astype(np.float32).mean(2)
y0,y1,x0,x1=map(int,sys.argv[3:7])
B=32; out=[]
for ys in range(y0,y1-B+1,B):
  row=[]
  for xs in range(x0,x1-B+1,B):
    a=L[ys:ys+B,xs:xs+B]
    e=min(np.abs(a-R[ys:ys+B,xs+s:xs+s+B]).mean() for s in range(-60,21) if 0<=xs+s and xs+s+B<=N)
    row.append(e)
  out.append(row)
out=np.array(out); np.set_printoptions(linewidth=250)
print(np.round(out).astype(int)); print('mean',out.mean().round(2),'blocks>6',(out>6).sum(),'of',out.size)
