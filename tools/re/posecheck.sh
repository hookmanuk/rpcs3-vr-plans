#!/bin/sh
# posecheck.sh ID STATE OUT [SCALE=300] ["KEYS"]: head-pose check on the OpenXR Simulator (AGENTS.md profile step 5).
# Boots bin/savestates/ID/STATE.SAVESTAT.zst with the game's own config (cfgtemp: VR on, Frame Rate Unlimited, scale,
# Null audio; restored after), optionally sends KEYS (keys.sh script, e.g. 'W 20000 100\n'), then turns the simulator's
# real head (simpose.py) through: straight, yaw -20, yaw +20, pitch 10, pitch -10, roll 15. Shots OUT_<pose>.png and a
# left-eye contact sheet OUT_sheet.png (in pose order, two per row). Env SETTLE (s after the first frame stats, default 4).
cd "$(dirname "$0")"
id=$1; st=$2; out=$3; sc=${4:-300}; keys=$5
L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log
P=/f/rpsc3/source/rpcs3/bin/config/input_configs/$id
padhad=0; [ -d "$P" ] && padhad=1
[ $padhad = 0 ] && { mkdir -p "$P"; cp ../keyboard-pad-template.yml "$P/Default.yml"; }
py -3.13 cfgtemp.py $id set "Video/VR/Enabled=true" "Video/VR/Frame Rate=Unlimited" "Video/Resolution Scale=$sc" "Audio/Renderer=Null" >/dev/null
py -3.13 simpose.py 0 0 0 >/dev/null
RPCS3_VR_FRAMESTATS=1 timeout 60 powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/$id/$st.SAVESTAT.zst" -Probe render=1 >/dev/null 2>&1
sleep 8; powershell -File simwin.ps1 >/dev/null 2>&1
for i in $(seq 1 240); do grep -aq "VR frame stats" $L && break; sleep 0.5; done
[ -n "$keys" ] && sh keys.sh "$keys"
sleep ${SETTLE:-4}
names=""
for p in "0 0 0" "-20 0 0" "20 0 0" "0 10 0" "0 -10 0" "0 0 15"; do
  py -3.13 simpose.py $p >/dev/null; sleep 1.5
  n=$(echo $p | tr ' ' '_'); py -3.13 simshot.py "${out}_$n" 960 >/dev/null 2>&1; names="$names $n"
done
py -3.13 simpose.py 0 0 0 >/dev/null
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; \$t=0; while ((Get-Process rpcs3 -ErrorAction SilentlyContinue | Where-Object { \$_.Threads.Count -gt 1 }) -and \$t -lt 150) { Start-Sleep -Milliseconds 200; \$t++ }"
sleep 1
py -3.13 cfgtemp.py $id restore >/dev/null
[ $padhad = 0 ] && rm -r "${P:?}"
py -3.13 - "$out" $names <<'PY'
import sys
from PIL import Image, ImageDraw
out, names = sys.argv[1], sys.argv[2:]
ims = []
for n in names:
    try: ims.append((n, Image.open(f'{out}_{n}.full.png')))
    except Exception: pass
if ims:
    w, h = ims[0][1].size; cw = w // 2
    s = Image.new('RGB', (cw * 2, h * ((len(ims) + 1) // 2)))
    for k, (n, im) in enumerate(ims):
        tile = im.crop((0, 0, cw, h)); ImageDraw.Draw(tile).text((8, 8), n, fill=(255, 255, 0))
        s.paste(tile, ((k % 2) * cw, (k // 2) * h))
    s.resize((s.width // 2, s.height // 2)).save(f'{out}_sheet.png')
PY
true
