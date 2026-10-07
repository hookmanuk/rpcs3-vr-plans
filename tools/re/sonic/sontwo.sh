#!/bin/sh
# sontwo.sh TAG RATE: fresh boot, first race (gated VR rate), pause 6 s and resume, quit to the menu, second race.
# Shots st_TAG.png: race 1 after resume (2 shots 4 s apart), race 2 (2 shots 4 s apart). Log lines: rate switches.
S=/f/rpsc3/source/plans/tools/re/sonic; cd /f/rpsc3/source/plans/tools/re
CFGX="Video/Vblank Rate=$2" timeout 150 sh $S/up.sh BLUS30839 "F:/rpsc3/games/sonic_asrt.iso" >/dev/null
for i in $(seq 1 12); do sleep 9; sh keys.sh 'X 150\n'; done
sleep 12; sh keys.sh 'X 150\n'; sleep 4; sh keys.sh 'W 8000 100\n'; sleep 9
sh keys.sh 'Return 200 100\n'; sleep 6; sh keys.sh 'X 200 100\n'; sleep 2; sh keys.sh 'W 9000 100\n'; sleep 2
SHOT_MOVE=1 py -3.13 shot.py BLUS30839 st_$1_1 640 >/dev/null; sleep 4; SHOT_MOVE=1 py -3.13 shot.py BLUS30839 st_$1_2 640 >/dev/null; sleep 4
sh keys.sh 'Return 200 1500\nDown 150 400\nDown 150 400\nDown 150 400\nX 150 2000\nDown 150 600\nX 150 2000\n'; sleep 25
sh keys.sh 'X 150 9000\nX 150 9000\nX 150 9000\nX 150 9000\n'; sleep 40
sh keys.sh 'X 150\n'; sleep 5; sh keys.sh 'W 30000\n'; sleep 10
SHOT_MOVE=1 py -3.13 shot.py BLUS30839 st_$1_3 640 >/dev/null; sleep 4; SHOT_MOVE=1 py -3.13 shot.py BLUS30839 st_$1_4 640 >/dev/null
grep -a "frame-rate words" /f/rpsc3/source/rpcs3/bin/log/RPCS3.log | cut -c1-120
sh $S/down.sh BLUS30839 >/dev/null
py -3.13 -c "
from PIL import Image
s=Image.new('RGB',(1280,720))
for k in range(4):
    try:
        im=Image.open('st_$1_%d.png'%(k+1)); w,h=im.size; s.paste((im.crop((0,0,w//2,h)) if w>h*2.5 else im).resize((640,360)),((k%2)*640,(k//2)*360))
    except Exception as e: print(e)
s.save('st_$1.png')"
