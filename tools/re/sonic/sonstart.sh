#!/bin/sh
# sonstart.sh TAG: from BLUS30839_1_1 (fly-by) press Cross, wait for the countdown, hold R2; flat screenshots at 14 and 20 s
S=/f/rpsc3/source/plans/tools/re/sonic
cd /f/rpsc3/source/plans/tools/re
CFGX="Video/Vblank Rate=${RATE:-90}" timeout 150 sh $S/up.sh BLUS30839 BLUS30839_1_1 >/dev/null; sleep 2
sh keys.sh 'X 150\nwait 1500\nX 150\nwait 3000\nW 30000\n'
sleep 14; SHOT_MOVE=1 py -3.13 shot.py BLUS30839 st_$1_a 640 >/dev/null; sleep 6; SHOT_MOVE=1 py -3.13 shot.py BLUS30839 st_$1_b 640 >/dev/null
sh $S/down.sh BLUS30839 >/dev/null
py -3.13 -c "
from PIL import Image
s=Image.new('RGB',(1280,360))
for k,p in enumerate(('st_$1_a','st_$1_b')): s.paste(Image.open(p+'.png').resize((640,360)),(k*640,0))
s.save('st_$1.png')"
