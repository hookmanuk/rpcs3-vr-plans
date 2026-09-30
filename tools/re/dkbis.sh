#!/bin/sh
# dkbis.sh 'probe options': stereo + options, shot; prints mean red excess of the right eye vs the left
W="$TEMP/rpcs3-vrprofile"; printf "render=1,$1" > "$W/probe.txt"; sleep 2
py -3.13 shot.py BLUS30035 dkbis 640 >/dev/null
py -3.13 -c "
from PIL import Image; import numpy as np
a=np.asarray(Image.open('dkbis.full.png').convert('RGB')).astype(float); h,w,_=a.shape
def red(x): return (x[:,:,0]-(x[:,:,1]+x[:,:,2])/2).mean()
print('red L %.1f R %.1f'%(red(a[:,:w//2]),red(a[:,w//2:])))"
