#!/bin/sh
# carposes.sh TAG [NAME=VALUE...]: simulator: the in-car view on the race grid at head turns well past the usual check (yaw 30-70 either way, some pitch): left eye shots, montage out/TAG.png.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; RE=/f/rpsc3/source/plans/tools/re
TAG=$1; shift
st() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
tasklist | grep -qi pgr4.exe && { echo "pgr4 is running: stopping"; exit 1; }
NO_RACE=1 sh $T/vrrace.sh 2880x2880 SIMXR_HZ=90 "$@" >/dev/null 2>&1
$P wait 3s >/dev/null
st START 6s; st A 6s; st A 4s; st A 4s; st A 4s; st A 6s; st A 15s; st A 12s
st LB 2s; st LB 2s
$P trigger R 1 >/dev/null; sleep 3; $P trigger R 0 >/dev/null
st START 3s
i=0
for pose in "30 0 0" "40 -5 0" "50 -10 0" "60 -5 0" "70 0 0" "-30 0 0" "-40 -5 0" "-50 -10 0" "-60 -5 0" "-70 0 0" "35 -20 5" "-35 -20 -5"; do
    i=$((i+1))
    py -3 -I $RE/simpose.py $pose >/dev/null
    sleep 1
    $P shot H:/PGR4-ReGPU/out/${TAG}_$i.png >/dev/null
done
py -3 -I $RE/simpose.py 0 0 0 >/dev/null
$P stop >/dev/null 2>&1
sleep 3
py -3 - "$TAG" <<'EOF'
import sys
from PIL import Image
t = sys.argv[1]
O = 'H:/PGR4-ReGPU/out/'
m = Image.new('RGB', (1800, 1350))
for i in range(12):
    a = Image.open(O + '%s_%d.png' % (t, i + 1)).convert('RGB').resize((450, 450))
    m.paste(a, (450 * (i % 4), 450 * (i // 4)))
m.save(O + t + '.png')
EOF
