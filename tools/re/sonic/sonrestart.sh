#!/bin/sh
# sonrestart.sh TAG STATE: pause, Restart, YES, Cross (race card), Cross (skip fly-by), hold R2; flat shots at +20 and +26 s
S=/f/rpsc3/source/plans/tools/re/sonic
cd /f/rpsc3/source/plans/tools/re
CFGX="Video/Vblank Rate=${RATE:-90}" timeout 150 sh $S/up.sh BLUS30839 ${2:-vrtest_sonic_race} ${PROBE:-render=0} >/dev/null; sleep 3
sh keys.sh 'Return 150\nwait 1500\nDown 150\nwait 800\nX 150\nwait 1500\nDown 150\nwait 800\nX 150\n'; sleep 14
sh keys.sh 'X 200\nwait 5000\nX 200\nwait 2000\nW 40000\n'; sleep 20
SHOT_MOVE=1 py -3.13 shot.py BLUS30839 rs_$1_a 640 >/dev/null; sleep 6; SHOT_MOVE=1 py -3.13 shot.py BLUS30839 rs_$1_b 640 >/dev/null
sh $S/down.sh BLUS30839 >/dev/null
py -3.13 -c "
from PIL import Image
s=Image.new('RGB',(1280,360))
for k,p in enumerate(('rs_$1_a','rs_$1_b')):
    im=Image.open(p+'.png'); w,h=im.size; s.paste((im.crop((0,0,w//2,h)) if w>h*2.5 else im).resize((640,360)),(k*640,0))
s.save('rs_$1.png')"
