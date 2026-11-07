#!/bin/sh
# ab.sh LABEL SWITCH [rounds=3]: alternates a live REGPU_ switch on the running game, 6 s windows; frame rate and GPU time each.
P=/f/rpsc3/source/plans/tools/pgr4/pg.sh; T=/f/rpsc3/source/plans/tools/pgr4; L=/h/PGR4-ReGPU/thirdparty/ReGPU/out/live.log
LABEL=$1; SW=$2; N=${3:-3}
for r in $(seq 1 $N); do
  for v in 0 1; do
    $P switch $SW $v >/dev/null; sleep 3
    python $T/vrperf.py 6 "$LABEL $SW=$v" | cut -c1-96
    grep -E 'GPU time' $L | tail -1 | sed -E 's/.*(GPU time [0-9.]+).*/   \1/'
  done
done
$P switch $SW 0 >/dev/null
