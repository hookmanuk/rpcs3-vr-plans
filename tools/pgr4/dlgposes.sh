#!/bin/sh
# dlgposes.sh TAG [NAME=VALUE...]: simulator: the profile dialog at strong head turns: the panel's text close up, out/TAG.png.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; RE=/f/rpsc3/source/plans/tools/re
TAG=$1; shift
tasklist | grep -qi pgr4.exe && { echo "pgr4 is running: stopping"; exit 1; }
NO_RACE=1 sh $T/vrrace.sh 2880x2880 SIMXR_HZ=90 "$@" >/dev/null 2>&1
$P wait 3s >/dev/null
$P press START >/dev/null; $P wait 6s >/dev/null
i=0
for pose in "32 4 3" "38 -6 -8" "-30 -10 10" "15 18 12"; do
    i=$((i+1))
    py -3 -I $RE/simpose.py $pose >/dev/null
    sleep 1
    $P shot H:/PGR4-ReGPU/out/${TAG}_$i.png >/dev/null
done
py -3 -I $RE/simpose.py 0 0 0 >/dev/null
grep -a 'panel glass' /h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log | cut -c12-90 | sort -u
$P stop >/dev/null 2>&1
sleep 3
py -3 - "$TAG" <<'EOF'
import sys
from PIL import Image
t = sys.argv[1]
O = 'H:/PGR4-ReGPU/out/'
m = Image.new('RGB', (1800, 1800))
for i in range(4):
    a = Image.open(O + '%s_%d.png' % (t, i + 1)).convert('RGB').resize((900, 900))
    m.paste(a, (900 * (i % 2), 900 * (i // 2)))
m.save(O + t + '.png')
EOF
