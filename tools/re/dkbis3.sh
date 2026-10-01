#!/bin/sh
# dkbis3.sh 'probe options': stereo + options, shot; prints the blown-out (near white) fraction of the left eye
W="$TEMP/rpcs3-vrprofile"; printf "render=1,$1" > "$W/probe.txt"; sleep 2
py -3.13 shot.py BLUS30035 dkbis 640 >/dev/null
py -3.13 -c "
from PIL import Image; import numpy as np
a=np.asarray(Image.open('dkbis.full.png').convert('L')).astype(float); h,w=a.shape; L=a[:,:w//2]
print('white %.3f  black %.3f  mean %.1f'%((L>245).mean(),(L<8).mean(),L.mean()))"
