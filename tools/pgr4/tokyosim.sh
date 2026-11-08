#!/bin/sh
# tokyosim.sh LABEL [NAME=VALUE...]: the simulator paced at 90 Hz, Tokyo night heavy rain, in-car, 30 s driving with REGPU_VR_TRACE:
# how many headset frames were late and why (the game late to its swap, the command processor, the GPU). POKE="ADDR BYTE" sets a byte first.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; L=/h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log
LABEL=$1; shift
tasklist | grep -qi pgr4.exe && { echo "pgr4 is running: stopping"; exit 1; }
SIMXR_HZ=90 NO_RACE=1 sh $T/vrrace.sh 5120x5120 REGPU_PERF=1 REGPU_VR_TRACE=1 SIMXR_HZ=90 "$@" >/dev/null 2>&1
sh $T/rainroute.sh
$P press LB >/dev/null; sleep 2; $P press LB >/dev/null; sleep 4
[ -n "$POKE" ] && $P poke $POKE >/dev/null
$P trigger R 1 >/dev/null; sleep 3
py -3 -I $T/vrperf.py 30 "$LABEL sim Tokyo in-car driving" | sed -E 's/, p50 [0-9.]+ ms//; s/, [0-9]+ frames.*//' | cut -c1-110
$P trigger R 0 >/dev/null
$P stop >/dev/null 2>&1; sleep 2
py -3 - "$LABEL" <<'PYEOF'
import re, sys
rows = []
for l in open('H:/PGR4-ReGPU/thirdparty/ReGPU/out/live.log', errors='replace'):
    m = re.search(r'\[ *([0-9.]+)\] vr late: ([0-9.]+) ms since the last end \| xrWait ([0-9.]+) \| from the token: title in swap ([-0-9.]+), out ([-0-9.]+), published ([-0-9.]+), got it ([-0-9.]+), finished ([-0-9.]+), ended ([-0-9.]+)', l)
    if m:
        rows.append(tuple(float(x) for x in m.groups()))
if not rows:
    print('   no late frames logged'); sys.exit()
T = max(r[0] for r in rows)
rows = [r for r in rows if r[0] > T - 31 and r[1] < 90]
game = sum(1 for r in rows if r[3] > 0)
cp = sum(1 for r in rows if r[3] <= 0 and r[5] > 6)
gpu = sum(1 for r in rows if r[3] <= 0 and r[5] <= 6 and r[7] - max(r[5], 0) > 7)
print('   %s: %d late headset frames in 30 s (over 14 ms): game late %d, command processor %d, GPU %d, over 20 ms %d' % (sys.argv[1], len(rows), game, cp, gpu, sum(1 for r in rows if r[1] > 20)))
PYEOF
