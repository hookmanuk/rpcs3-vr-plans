#!/bin/sh
# sonwalk.sh TAG [RATE] [N]: fresh boot, N X presses 9 s apart with a shot before each press -> sw_TAG_sheet.png
S=/f/rpsc3/source/plans/tools/re/sonic
cd /f/rpsc3/source/plans/tools/re
CFGX="Video/Vblank Rate=${2:-60}" timeout 150 sh $S/up.sh BLUS30839 "F:/rpsc3/games/sonic_asrt.iso" >/dev/null
N=${3:-14}
for i in $(seq 1 $N); do sleep 8; SHOT_MOVE=1 py -3.13 shot.py BLUS30839 sw_$1_$i 480 >/dev/null; sh keys.sh 'X 150\n'; done
sleep 8; SHOT_MOVE=1 py -3.13 shot.py BLUS30839 sw_$1_$((N+1)) 480 >/dev/null
[ -n "$KEEP" ] || sh $S/down.sh BLUS30839 >/dev/null
py -3.13 -c "
from PIL import Image
n=$N+1; s=Image.new('RGB',(1280,180*((n+3)//4)))
for k in range(n):
    im=Image.open('sw_$1_%d.png'%(k+1)); w,h=im.size; s.paste((im.crop((0,0,w//2,h)) if w>h*2.5 else im).resize((320,180)),((k%4)*320,(k//4)*180))
s.save('sw_$1_sheet.png')"
