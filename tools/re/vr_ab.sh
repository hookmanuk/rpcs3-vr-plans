#!/bin/sh
# vr_ab.sh LABEL [STATE...]: A/B runs for renderer optimisation. Each state from vrtest_states.txt runs once in desktop
# stereo at RATE (default 72) Hz x its VPF, 300%, like vr_regress.sh; the summary lines (FPS, 1% low, late frames and
# the RSX thread's CPU ms per frame) are appended to plans/evidence/vrperf/LABEL.txt. Same states, same rate, compare
# LABELs. Default states: R&C 1 and 3, Dragon's Dogma.
cd "$(dirname "$0")"
label=$1; shift
[ $# -eq 0 ] && set -- vrtest_rc1_veldin vrtest_rc3_veldin_battle vrtest_ddda_prologue
O=/f/rpsc3/source/plans/evidence/vrperf; mkdir -p "$O"
for st in "$@"; do
  line=$(grep -v '^#' vrtest_states.txt | awk -v s="$st" '$2 == s')
  [ -z "$line" ] && { echo "unknown state $st"; continue; }
  set -- $line; id=$1; vpf=$3; walk=$4; settle=$5
  out=$(SETTLE=$settle sh vr1pct.sh "$id" "$st" $((${RATE:-72} * vpf)) "$walk")
  sum=$(echo "$out" | grep "=>" | sed 's/.*=> //')
  echo "$label $st ${RATE:-72}Hz: $sum" | tee -a "$O/$label.txt"
done
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force"
