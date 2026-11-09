import sys, struct, numpy as np
# ringflat.py RING...: flicker on flat surfaces only (edges excluded, where head jitter moves the image): pixels whose
# median frame has a local gradient under 2 levels, the share with a 90th-percentile frame-to-frame change over 4.
for p in sys.argv[1:]:
    d=open(p,'rb').read(); w,h,n=struct.unpack('<III',d[:12])
    f=np.frombuffer(d[12:12+w*h*4*n],np.uint8).reshape(n,h,w,4)[:,:, :w//2,:3].astype(np.float32).mean(3)
    med=np.median(f,axis=0)
    gx=np.abs(np.diff(med,axis=1,prepend=med[:,:1])); gy=np.abs(np.diff(med,axis=0,prepend=med[:1]))
    g=np.maximum(gx,gy)
    from scipy.ndimage import maximum_filter
    flat=(maximum_filter(g,5)<2)&(med>20)
    p90=np.percentile(np.abs(np.diff(f,axis=0)),90,axis=0)
    print(f'{p:32s} flat px {flat.mean()*100:.1f}%  flicker>4 {(p90[flat]>4).mean()*100:.2f}%  >8 {(p90[flat]>8).mean()*100:.3f}%')
