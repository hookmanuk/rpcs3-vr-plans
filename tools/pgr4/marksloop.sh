#!/bin/sh
# marksloop.sh COUNT [NAME=VALUE...]: simulator: boots to the race grid COUNT times; on each, a shot and how many yellow pixels the grid's yellow sign gives, and the frame's draws: the road markings and the sign go missing together in some runs. Keeps out/mkN.png and the log's tile lines out/mkN.txt. Stops if the game is already running (Matt's).
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; O=H:/PGR4-ReGPU/out; L=/h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log
COUNT=$1; shift
st() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
n=0
while [ $n -lt $COUNT ]; do
    n=$((n+1))
    tasklist | grep -qi pgr4.exe && { echo "pgr4 is running: stopping"; exit 1; }
    NO_RACE=1 sh $T/vrrace.sh 2880x2880 SIMXR_HZ=90 "$@" >/dev/null 2>&1
    $P wait 3s >/dev/null
    st START 6s; st A 6s; st A 4s; st A 4s; st A 4s; st A 6s; st A 15s; st A 12s
    $P wait 1s >/dev/null
    $P shot $O/mk$n.png >/dev/null
    s=$($P status | cut -c1-70)
    grep -a -E 'tile merge|tile pass' $L | tail -6 > /h/PGR4-ReGPU/out/mk$n.txt
    $P stop >/dev/null 2>&1
    sleep 3
    y=$(py -3 - $n <<'EOF'
import sys
import numpy as np
from PIL import Image
a = np.asarray(Image.open('H:/PGR4-ReGPU/out/mk%s.png' % sys.argv[1]).convert('RGB'), dtype=np.int16)
h, w = a.shape[:2]
c = a[int(h * .25):int(h * .40), int(w * .24):int(w * .38)]
yellow = (c[:, :, 0] > 110) & (c[:, :, 1] > 90) & (c[:, :, 2] < 60)
# Road dashes: bright pixels in the band of road to the left of the car.
r = a[int(h * .55):int(h * .80), 0:int(w * .5)]
bright = r.mean(axis=2) > 90
print('yellow %d road %.2f%%' % (yellow.sum(), 100 * bright.mean()))
EOF
)
    echo "run $n: $y $s"
done
