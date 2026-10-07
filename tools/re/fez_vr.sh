#!/bin/sh
# fez_vr.sh OUT [SCALE=300]: Fez (NPUB31448) has no loadable savestates (RSX access violation on load): boots the game on
# the OpenXR Simulator with VR on, drives to the village (slot 1, Continue, out of the room) and shoots the head poses
# (straight, yaw -20/+20, pitch 10/-10, roll 15) like posecheck.sh. Config restored after.
cd "$(dirname "$0")"
out=$1; sc=${2:-300}; L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log
py -3.13 cfgtemp.py NPUB31448 set "Video/VR/Enabled=true" "Video/VR/Frame Rate=Unlimited" "Video/Resolution Scale=$sc" "Audio/Renderer=Null" >/dev/null
py -3.13 simpose.py 0 0 0 >/dev/null
RPCS3_VR_FRAMESTATS=4 timeout 90 powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/dev_hdd0/game/NPUB31448/USRDIR/EBOOT.BIN" -Probe render=1 >/dev/null 2>&1
powershell -File simwin.ps1 >/dev/null 2>&1
# title (the PSN notice is gone by then), slot 1, Continue, the room; out of the door to the village
sleep 25
sh keys.sh 'X 400 6000
X 400 5000
X 400 4000
X 400 4000
X 400 22000
L 450 300
Up 400 2500
'
sleep 52
names=""
for p in "0 0 0" "-20 0 0" "20 0 0" "0 10 0" "0 -10 0" "0 0 15"; do
  py -3.13 simpose.py $p >/dev/null; sleep 1.5
  n=$(echo $p | tr ' ' '_'); py -3.13 simshot.py "${out}_$n" 960 >/dev/null 2>&1; names="$names $n"
done
py -3.13 simpose.py 0 0 0 >/dev/null
grep -a "VR frame stats" $L | tail -2 | sed 's/.*stats: //'
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force"
sleep 2; py -3.13 cfgtemp.py NPUB31448 restore >/dev/null
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
