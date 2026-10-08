#!/bin/sh
# rc_dumps1.sh STATE PFX: three memory dumps (2, 5, 8 s after the first frame) of an R&C savestate, flat at Vblank 60
# with a pad, into dumps/PFX{0,1,2}.
cd "$(dirname "$0")"
W="$TEMP/rpcs3-vrprofile"; L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log
P=/f/rpsc3/source/rpcs3/bin/config/input_configs/BCUS98282; mkdir -p "$P"; cp ../keyboard-pad-template.yml "$P/Default.yml"
py -3.13 cfgtemp.py BCUS98282 set "Video/VR/Enabled=false" "Video/Vblank Rate=60" "Audio/Renderer=Null" >/dev/null
rm -f "$W"/g_dump.*
RPCS3_VR_FRAMESTATS=1 timeout 60 powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/BCUS98282/$1.SAVESTAT.zst" -Desktop >/dev/null 2>&1
for i in $(seq 1 240); do grep -aq "VR frame stats" $L && break; sleep 0.5; done
for t in 2 1 1; do sleep $t; touch "$W/g_dump"; sleep 2; done
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force"; sleep 2
py -3.13 cfgtemp.py BCUS98282 restore >/dev/null; rm -r "${P:?}"
mkdir -p dumps; for i in 0 1 2; do mv "$W/g_dump.$i.bin" dumps/$2$i.bin; mv "$W/g_dump.$i.idx" dumps/$2$i.idx; done
