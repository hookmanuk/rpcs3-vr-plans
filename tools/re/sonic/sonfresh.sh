#!/bin/sh
# sonfresh.sh TAG [RATE]: fresh boot, Cross through intro/menus into the first career race, hold R2; flat-left shots
S=/f/rpsc3/source/plans/tools/re/sonic
cd /f/rpsc3/source/plans/tools/re
CFGX="Video/Vblank Rate=${2:-90}" timeout 150 sh $S/up.sh BLUS30839 "F:/rpsc3/games/sonic_asrt.iso" >/dev/null
for i in $(seq 1 14); do sleep 9; sh keys.sh 'X 150\n'; done
sleep 4; sh keys.sh 'W 30000\n'; sleep 6; SHOT_MOVE=1 py -3.13 shot.py BLUS30839 fs_$1_a 640 >/dev/null; sleep 6; SHOT_MOVE=1 py -3.13 shot.py BLUS30839 fs_$1_b 640 >/dev/null
grep -a "Applied patch" /f/rpsc3/source/rpcs3/bin/log/RPCS3.log | grep -o "description='[^']*'" | tr '\n' ' '; echo
sh $S/down.sh BLUS30839 >/dev/null
py -3.13 -c "
from PIL import Image
s=Image.new('RGB',(1280,360))
for k,p in enumerate(('fs_$1_a','fs_$1_b')):
    im=Image.open(p+'.png'); w,h=im.size; s.paste((im.crop((0,0,w//2,h)) if w>h*2.5 else im).resize((640,360)),(k*640,0))
s.save('fs_$1.png')"
