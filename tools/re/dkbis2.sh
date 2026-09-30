#!/bin/sh
# dkbis2.sh 'probe options': stereo + options, shot; prints red-excess of the right-edge region and haze of the left band (right eye)
W="$TEMP/rpcs3-vrprofile"; printf "render=1,$1" > "$W/probe.txt"; sleep 2
py -3.13 shot.py BLUS30035 dkbis 640 >/dev/null
py -3.13 -c "
from PIL import Image; import numpy as np
a=np.asarray(Image.open('dkbis.full.png').convert('RGB')).astype(float); h,w,_=a.shape; R=a[:,w//2:]; hw=w//2
red=lambda x:(x[:,:,0]-(x[:,:,1]+x[:,:,2])/2).clip(0).mean()
print('edge red %.1f  hand red %.1f  band lum %.1f'%(red(R[400:700,int(hw*.9):]),red(R[350:720,int(hw*.7):int(hw*.9)]),R[:,int(hw*.3):int(hw*.45)].mean()))"
