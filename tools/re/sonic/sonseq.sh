#!/bin/sh
# sonseq.sh TAG STATE [RATE]: Sonic state, X (skip fly-by), shots every 1.5 s for 12 shots -> sq_TAG_sheet.png
S=/f/rpsc3/source/plans/tools/re/sonic
cd /f/rpsc3/source/plans/tools/re
CFGX="Video/Vblank Rate=${3:-60}" timeout 150 sh $S/up.sh BLUS30839 $2 render=0 >/dev/null; sleep 3
sh keys.sh "${PRE:-X 200\n}"
for i in $(seq 10 21); do SHOT_MOVE=1 py -3.13 shot.py BLUS30839 sq_$1_$i 480 >/dev/null; sleep 1; done
sh $S/down.sh BLUS30839 >/dev/null
py -3.13 -c "
from PIL import Image
s=Image.new('RGB',(1280,720*2))
for k in range(12):
    im=Image.open('sq_$1_%d.png'%(k+10)); w,h=im.size; s.paste((im.crop((0,0,w//2,h)) if w>h*2.5 else im).resize((320,180)),((k%4)*320,(k//4)*180))
s.crop((0,0,1280,540)).save('sq_$1_sheet.png')"
