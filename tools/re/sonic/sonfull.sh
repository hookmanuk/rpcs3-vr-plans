#!/bin/sh
# sonfull.sh TAG RATE: fresh boot at RATE with the profile as it is (no key switching), 12 X presses into the first race,
# X on the grid, hold R2; shots sf_TAG.png (grid, +10 s, +15 s) and the frame-rate word switches from the log
S=/f/rpsc3/source/plans/tools/re/sonic; cd /f/rpsc3/source/plans/tools/re
CFGX="Video/Vblank Rate=$2" timeout 150 sh $S/up.sh BLUS30839 "F:/rpsc3/games/sonic_asrt.iso" >/dev/null
for i in $(seq 1 12); do sleep 9; sh keys.sh 'X 150\n'; done
sleep 12; SHOT_MOVE=1 py -3.13 shot.py BLUS30839 sf_$1_a 640 >/dev/null
sh keys.sh 'X 150\n'; sleep 4; sh keys.sh 'W 30000\n'; sleep 10
SHOT_MOVE=1 py -3.13 shot.py BLUS30839 sf_$1_b 640 >/dev/null; sleep 5; SHOT_MOVE=1 py -3.13 shot.py BLUS30839 sf_$1_c 640 >/dev/null
grep -a "frame-rate words" /f/rpsc3/source/rpcs3/bin/log/RPCS3.log | cut -c1-140 | head -6
sh $S/down.sh BLUS30839 >/dev/null
py -3.13 -c "
from PIL import Image
s=Image.new('RGB',(1920,360))
for k,p in enumerate(('sf_$1_a','sf_$1_b','sf_$1_c')):
    im=Image.open(p+'.png'); w,h=im.size; s.paste((im.crop((0,0,w//2,h)) if w>h*2.5 else im).resize((640,360)),(k*640,0))
s.save('sf_$1.png')"
