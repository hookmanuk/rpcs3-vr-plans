#!/bin/sh
# crash.sh TAG [both]: from a race grid: full throttle, steer into the barrier, then along it: shots out/TAG_0..7.png (with "both", the simulator's two eyes as well, out/TAG_e0..3.png), montage out/TAG.png.
P=/f/rpsc3/source/plans/tools/pgr4/pg.sh; O=H:/PGR4-ReGPU/out; TAG=${1:-crash}; BOTH=$2
RE=/f/rpsc3/source/plans/tools/re
$P trigger R 1 >/dev/null
sleep 6
$P stick L 0.5 0 >/dev/null
i=0
while [ $i -lt 8 ]; do
    $P shot $O/${TAG}_$i.png >/dev/null
    [ "$i" = 3 ] && $P stick L -0.25 0 >/dev/null
    sleep 1
    i=$((i+1))
done
if [ -n "$BOTH" ]; then
    $P stick L 0.5 0 >/dev/null
    for e in 0 1 2 3; do
        sleep 1
        py -3 $RE/simshot.py ${TAG}_e$e 1400 >/dev/null
        mv $RE/${TAG}_e$e.png $O/ 2>/dev/null
        rm -f $RE/${TAG}_e$e.full.png
    done
fi
$P trigger R 0 >/dev/null
$P stick L 0 0 >/dev/null
python - "$TAG" <<EOF
import sys
from PIL import Image
t = sys.argv[1]
m = Image.new('RGB', (1600, 800))
for i in range(8):
    im = Image.open('H:/PGR4-ReGPU/out/%s_%d.png' % (t, i)).convert('RGB')
    W, H = im.size
    if W == H:
        im = im.crop((0, H // 5, W, H * 4 // 5))
    m.paste(im.resize((400, 400 * 9 // 16 if W != H else 240)), ((i % 4) * 400, (i // 4) * 300))
m.save('H:/PGR4-ReGPU/out/%s.png' % t)
EOF
