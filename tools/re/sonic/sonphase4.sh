#!/bin/sh
# sonphase4.sh TAG RATE N: fresh boot at RATE; 60 simulation from boot up to the Nth menu X press, then the VR rate (rate keys
# removed) through the rest of the menus and the race load; VR rate again on the grid. Shots sp4_TAG.png
S=/f/rpsc3/source/plans/tools/re/sonic; cd /f/rpsc3/source/plans/tools/re
J=/f/rpsc3/source/rpcs3/bin/vr_profiles/BLUS30839.json
set_rate() { if [ "$1" = 60 ]; then grep -v '"game_refresh_rate_f32"\|"game_frame_time_f32"' $S/BLUS30839.full.json > $J; else cp $S/BLUS30839.full.json $J; fi; }
set_rate 60
CFGX="Video/Vblank Rate=$2" timeout 150 sh $S/up.sh BLUS30839 "F:/rpsc3/games/sonic_asrt.iso" >/dev/null
for i in $(seq 1 12); do sleep 9; [ $i = $(($3 + 1)) ] && set_rate vr; sh keys.sh 'X 150\n'; done
sleep 12; SHOT_MOVE=1 py -3.13 shot.py BLUS30839 sp4_$1_a 640 >/dev/null
set_rate vr; sleep 3
sh keys.sh 'X 150\n'; sleep 4; sh keys.sh 'W 30000\n'; sleep 10
SHOT_MOVE=1 py -3.13 shot.py BLUS30839 sp4_$1_b 640 >/dev/null; sleep 5; SHOT_MOVE=1 py -3.13 shot.py BLUS30839 sp4_$1_c 640 >/dev/null
sh $S/down.sh BLUS30839 >/dev/null; cp $S/BLUS30839.full.json $J
py -3.13 -c "
from PIL import Image
s=Image.new('RGB',(1920,360))
for k,p in enumerate(('sp4_$1_a','sp4_$1_b','sp4_$1_c')):
    im=Image.open(p+'.png'); w,h=im.size; s.paste((im.crop((0,0,w//2,h)) if w>h*2.5 else im).resize((640,360)),(k*640,0))
s.save('sp4_$1.png')"
