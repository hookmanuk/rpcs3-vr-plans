#!/bin/sh
# sonphase.sh TAG RATE MENU LOAD: fresh boot at RATE; simulation step during the menus = MENU (60|vr) and from the race
# confirm on (race load, fly-by, race) = LOAD (60|vr), switched by removing/restoring the profile's rate keys (live reload);
# at the grid the VR rate always. Shots: sp_TAG.png (grid, +10 s holding R2, +15 s)
S=/f/rpsc3/source/plans/tools/re/sonic; cd /f/rpsc3/source/plans/tools/re
J=/f/rpsc3/source/rpcs3/bin/vr_profiles/BLUS30839.json
set_rate() { if [ "$1" = 60 ]; then grep -v '"game_refresh_rate_f32"\|"game_frame_time_f32"' $S/BLUS30839.full.json > $J; else cp $S/BLUS30839.full.json $J; fi; }
set_rate $3
CFGX="Video/Vblank Rate=$2" timeout 150 sh $S/up.sh BLUS30839 "F:/rpsc3/games/sonic_asrt.iso" >/dev/null
for i in $(seq 1 11); do sleep 9; sh keys.sh 'X 150\n'; done
sleep 9
if [ -n "$DUMPMENU" ]; then
  SHOT_MOVE=1 py -3.13 shot.py BLUS30839 sp_$1_m 640 >/dev/null
  W="$TEMP/rpcs3-vrprofile"; rm -f "$W"/g_dump*; touch "$W/g_dump"; for i in $(seq 1 100); do [ -f "$W/g_dump" ] || break; sleep 0.1; done; sleep 3
  b=$(ls -t "$W"/g_dump.*.bin | head -1); b=${b%.bin}; for x in bin idx txt; do mv "$b.$x" "dumps/spm_$1.$x"; done
  sh $S/down.sh BLUS30839 >/dev/null; cp $S/BLUS30839.full.json $J; exit 0
fi
set_rate $4; sleep 1; sh keys.sh 'X 150
'
sleep 12; SHOT_MOVE=1 py -3.13 shot.py BLUS30839 sp_$1_a 640 >/dev/null
if [ -n "$DUMP" ]; then
  W="$TEMP/rpcs3-vrprofile"; rm -f "$W"/g_dump*; touch "$W/g_dump"; for i in $(seq 1 100); do [ -f "$W/g_dump" ] || break; sleep 0.1; done; sleep 3
  b=$(ls -t "$W"/g_dump.*.bin | head -1); b=${b%.bin}; for x in bin idx txt; do mv "$b.$x" "dumps/sp_$1.$x"; done
  sh $S/down.sh BLUS30839 >/dev/null; cp $S/BLUS30839.full.json $J; exit 0
fi
set_rate vr; sleep 3
sh keys.sh 'X 150\n'; sleep 4; sh keys.sh 'W 30000\n'; sleep 10
SHOT_MOVE=1 py -3.13 shot.py BLUS30839 sp_$1_b 640 >/dev/null; sleep 5; SHOT_MOVE=1 py -3.13 shot.py BLUS30839 sp_$1_c 640 >/dev/null
sh $S/down.sh BLUS30839 >/dev/null; cp $S/BLUS30839.full.json $J
py -3.13 -c "
from PIL import Image
s=Image.new('RGB',(1920,360))
for k,p in enumerate(('sp_$1_a','sp_$1_b','sp_$1_c')):
    im=Image.open(p+'.png'); w,h=im.size; s.paste((im.crop((0,0,w//2,h)) if w>h*2.5 else im).resize((640,360)),(k*640,0))
s.save('sp_$1.png')"
