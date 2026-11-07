#!/bin/sh
# crashcar.sh TAG flat|vr [NAME=VALUE...]: in-car view, into the barrier, then 8 shots while driving on (head turned left in VR): stray triangles from a damaged car's interior. Montage out/TAG.png.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; RE=/f/rpsc3/source/plans/tools/re; O=H:/PGR4-ReGPU/out
TAG=$1; MODE=$2; shift 2
st() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
tasklist | grep -qi pgr4.exe && { echo "pgr4 is running: stopping"; exit 1; }
if [ "$MODE" = flat ]; then
    NO_RACE=1 sh $T/flatrace.sh 1920x1080 "$@" >/dev/null 2>&1
else
    NO_RACE=1 sh $T/vrrace.sh 3692x3692 SIMXR_HZ=90 "$@" >/dev/null 2>&1
    py -3 -I $RE/simpose.py 35 -8 3 >/dev/null
fi
$P wait 3s >/dev/null
st START 6s; st A 6s; st A 4s; st A 4s; st A 4s; st A 6s; st A 15s; st A 12s
st LB 2s; st LB 2s
$P trigger R 1 >/dev/null; sleep 6
$P stick L 0.5 0 >/dev/null; sleep 5
$P stick L -0.25 0 >/dev/null; sleep 6
$P stick L 0 0 >/dev/null
for i in 0 1 2 3 4 5 6 7; do
    $P shot $O/${TAG}_$i.png >/dev/null
    sleep 2
done
$P trigger R 0 >/dev/null
[ "$MODE" = flat ] || py -3 -I $RE/simpose.py 0 0 0 >/dev/null
$P stop >/dev/null 2>&1
sleep 3
py -3 - "$TAG" <<'EOF'
import sys
from PIL import Image
t = sys.argv[1]
O = 'H:/PGR4-ReGPU/out/'
m = Image.new('RGB', (1800, 900))
for i in range(8):
    a = Image.open(O + '%s_%d.png' % (t, i)).convert('RGB').resize((450, 450))
    m.paste(a, (450 * (i % 4), 450 * (i // 4)))
m.save(O + t + '.png')
EOF
