#!/bin/sh
# ddbis2.sh 'probe options' : stereo on plus the options, shot, print right/left brightness of the hole region
W="$TEMP/rpcs3-vrprofile"; printf "render=1,$1" > "$W/probe.txt"; sleep 2
py -3.13 shot.py BLUS31155 ddbis 640 >/dev/null
py -3.13 -c "
from PIL import Image; import numpy as np
a=np.asarray(Image.open('ddbis.full.png').convert('L')).astype(float)
L=a[80:500,1000:1250].mean(); R=a[80:500,2280:2530].mean(); print('L %.1f R %.1f ratio %.2f'%(L,R,R/max(L,.1)))"
