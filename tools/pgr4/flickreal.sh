#!/bin/sh
# flickreal.sh TAG EYE [NAME=VALUE...]: as flickrun.sh, but shots from the simulator (simshot.py: both eyes as sent to the runtime, no sync with the game). Main menu: 8 shots, out/TAG_m<n>.png. In-car view, paused, still head: 8 shots through flick.py, out/TAG_car.png. Head moved, paused: out/TAG_y<n>.png. Driving: out/TAG_d<n>.png.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; O=/h/PGR4-ReGPU/out; RE=/f/rpsc3/source/plans/tools/re
TAG=$1; EYE=$2; shift 2
st() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
sim() { py -3 $RE/simshot.py $1 2000 >/dev/null; mv $RE/$1.png $O/; rm -f $RE/$1.full.png; }
NO_RACE=1 sh $T/vrrace.sh $EYE "$@" | tail -1 | cut -c1-70
$P wait 3s >/dev/null
st START 6s; st A 6s
for i in 1 2 3 4 5 6 7 8; do sim ${TAG}_m$i; done
st A 4s; st A 4s; st A 4s; st A 6s; st A 15s; st A 12s
st LB 2s; st LB 2s
$P trigger R 1 >/dev/null; sleep 4
for i in 1 2 3 4 5 6; do sim ${TAG}_d$i; done
$P trigger R 0 >/dev/null
st START 3s
files=""
for i in 1 2 3 4 5 6 7 8; do sim ${TAG}_c$i; files="$files H:/PGR4-ReGPU/out/${TAG}_c$i.png"; done
echo "--- $TAG car paused, both eyes"
py -3 $T/flick.py H:/PGR4-ReGPU/out/${TAG}_car.png $files 2>&1 | grep -v -i 'deprecat\|getdata'
py -3 -I $RE/simpose.py -20 5 0 >/dev/null; sleep 1; sim ${TAG}_y1
py -3 -I $RE/simpose.py 20 -5 0 >/dev/null; sleep 1; sim ${TAG}_y2
py -3 -I $RE/simpose.py 0 -25 0 >/dev/null; sleep 1; sim ${TAG}_y3
py -3 -I $RE/simpose.py 0 0 0 >/dev/null
$P stop >/dev/null 2>&1
sleep 3
