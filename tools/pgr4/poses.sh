#!/bin/sh
# poses.sh: VR on the simulator at 2880: main menu, race (HUD), pause menu, each at head poses straight, yaw -20, yaw +20, pitch 10, roll 15 (simpose.py, the simulator's real pose).
# Shots: out/pose_<place>_<n>.png (both eyes), montage out/pose_<place>.png.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; POSE=/f/rpsc3/source/plans/tools/re/simpose.py; SHOT=/f/rpsc3/source/plans/tools/re/simshot.py
O=H:/PGR4-ReGPU/out
st() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
round() { # PLACE
    n=0
    for pose in "0 0 0" "-20 0 0" "20 0 0" "0 10 0" "0 0 15"; do
        py -3 -I $POSE $pose >/dev/null
        sleep 1.5
        py -3 $SHOT pose_$1_$n 1400 >/dev/null
        cp /f/rpsc3/source/plans/tools/re/pose_$1_$n.png $O/ 2>/dev/null
        rm -f /f/rpsc3/source/plans/tools/re/pose_$1_$n.png /f/rpsc3/source/plans/tools/re/pose_$1_$n.full.png
        n=$((n+1))
    done
    py -3 -I $POSE 0 0 0 >/dev/null
    python - "$1" <<EOF
import sys
from PIL import Image
place = sys.argv[1]
ims = [Image.open('H:/PGR4-ReGPU/out/pose_%s_%d.png' % (place, i)).convert('RGB') for i in range(5)]
w, h = ims[0].size
s = 900 / w
t = (900, int(h * s))
m = Image.new('RGB', (1800, t[1] * 3))
for i, im in enumerate(ims):
    m.paste(im.resize(t), ((i % 2) * 900, (i // 2) * t[1]))
m.save('H:/PGR4-ReGPU/out/pose_%s.png' % place)
EOF
}
NO_RACE=1 sh $T/vrrace.sh 2880x2880
$P wait 3s >/dev/null
st START 6s
round menu
st A 5s; st A 4s; st A 4s; st A 4s; st A 4s; st A 6s; st A 15s; st A 12s
round grid
$P trigger R 1 >/dev/null; sleep 4; $P trigger R 0 >/dev/null
st START 3s
round pause
$P status | cut -c1-100
