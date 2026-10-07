#!/bin/sh
# sondump.sh TAG STATE [RATE]: Sonic state, [PRE keys], hold accelerate, two memory dumps 4 s apart into plans/tools/re/dumps/sd_TAG_{a,b}
S=/f/rpsc3/source/plans/tools/re/sonic
R=/f/rpsc3/source/plans/tools/re; cd $R
W="$TEMP/rpcs3-vrprofile"; mkdir -p "$W"; rm -f "$W"/MEMDUMP* "$W"/g_dump*
CFGX="Video/Vblank Rate=${3:-60}" timeout 150 sh $S/up.sh BLUS30839 $2 render=0 >/dev/null; sleep 3
if [ -n "$PRE" ]; then sh keys.sh "$PRE"; sleep ${PREWAIT:-10}; fi
sh keys.sh 'W 40000\n'; sleep 6
for k in a b; do
  touch "$W/g_dump"; for i in $(seq 1 100); do [ -f "$W/g_dump" ] || break; sleep 0.1; done; sleep 3
  b=$(ls -t "$W"/g_dump.*.bin | head -1); b=${b%.bin}
  for x in bin idx txt; do mv "$b.$x" "dumps/sd_$1_$k.$x"; done
  SHOT_MOVE=1 py -3.13 shot.py BLUS30839 sd_$1_$k 640 >/dev/null; sleep 1
done
sh $S/down.sh BLUS30839 >/dev/null
ls -la dumps/sd_$1_*.bin | awk '{print $5, $9}'
py -3.13 -c "
from PIL import Image
s=Image.new('RGB',(1280,360))
for k,p in enumerate(('sd_$1_a','sd_$1_b')):
    im=Image.open(p+'.png'); w,h=im.size; s.paste((im.crop((0,0,w//2,h)) if w>h*2.5 else im).resize((640,360)),(k*640,0))
s.save('sd_$1.png')"
