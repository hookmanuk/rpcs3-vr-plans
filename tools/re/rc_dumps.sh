#!/bin/sh
# rc_dumps.sh: memory dumps of R&C 3 from ${STATE:-rc3_open_cutscene} (flat, Vblank 60, pad): 3 in the opening cutscene
# (2, 5, 8 s), then 3 in gameplay (after 40 s), into dumps/${PFX:-rc3}cut{0,1,2} and dumps/${PFX:-rc3}play{0,1,2}.
cd "$(dirname "$0")"
W="$TEMP/rpcs3-vrprofile"; L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log
P=/f/rpsc3/source/rpcs3/bin/config/input_configs/BCUS98282; mkdir -p "$P"; cp ../keyboard-pad-template.yml "$P/Default.yml"
py -3.13 cfgtemp.py BCUS98282 set "Video/VR/Enabled=false" "Video/Vblank Rate=60" "Audio/Renderer=Null" >/dev/null
RPCS3_VR_FRAMESTATS=1 timeout 60 powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/BCUS98282/${STATE:-rc3_open_cutscene}.SAVESTAT.zst" -Desktop >/dev/null 2>&1
for i in $(seq 1 240); do grep -aq "VR frame stats" $L && break; sleep 0.5; done
for t in 2 3 3; do sleep $t; touch "$W/g_dump"; sleep 3; done
sleep ${PLAYWAIT:-30}
for t in 1 3 3; do sleep $t; touch "$W/g_dump"; sleep 3; done
SHOT_MOVE=1 py -3.13 shot.py BCUS98282 rc_dump_end 640 >/dev/null 2>&1
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force"; sleep 2
py -3.13 cfgtemp.py BCUS98282 restore >/dev/null; rm -r "${P:?}"
mkdir -p dumps
for i in 0 1 2; do mv "$W/g_dump.$i.bin" dumps/${PFX:-rc3}cut$i.bin; mv "$W/g_dump.$i.idx" dumps/${PFX:-rc3}cut$i.idx 2>/dev/null; done
for i in 3 4 5; do j=$((i-3)); mv "$W/g_dump.$i.bin" dumps/${PFX:-rc3}play$j.bin; mv "$W/g_dump.$i.idx" dumps/${PFX:-rc3}play$j.idx 2>/dev/null; done
ls dumps | grep ${PFX:-rc3}
