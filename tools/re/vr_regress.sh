#!/bin/sh
# vr_regress.sh [FILTER]: VR regression run over tools/re/vrtest_states.txt (lines matching FILTER, a grep pattern).
# Each savestate runs in desktop stereo at Resolution Scale 300% (env SCALE) like a headset: at a fixed rate, climbing
# RATES (default "72 90 120" Hz) and stopping at the first rate that fails: >= 1% late frames (> 1.5x the median
# frame time) or an average under 99% of the rate (frames that miss their vblank present late in RPCS3). The game's
# sustainable rate is the highest passing one. Results and screenshots go to plans/evidence/vrtest/<date-time>/.
cd "$(dirname "$0")"
D=/f/rpsc3/source/plans/evidence/vrtest/$(date +%Y-%m-%d-%H%M); mkdir -p "$D"
grep -v '^#' vrtest_states.txt | grep -- "${1:-.}" | while read id st vpf walk settle rest; do
  [ -z "$id" ] && continue
  echo "# $id $st: $rest" | tee -a "$D/results.txt"
  best=none
  # A scene text tag "rates=30" (comma list) replaces the default rates: frame-locked games (ICO runs at 30).
  tag=$(echo "$rest" | grep -o "rates=[0-9,]*" | cut -d= -f2 | tr , ' ')
  for rate in ${RATES:-${tag:-72 90 120}}; do
    out=$(SETTLE=$settle sh vr1pct.sh "$id" "$st" $((rate * vpf)) "$walk")
    echo "$out" | tee -a "$D/results.txt"
    # No stats at all = the game stalled before measuring (Ridge Racer 7's menu-video freeze): one retry.
    if echo "$out" | grep -q "no frame stats"; then
      echo "   (no frame stats: retrying once)" | tee -a "$D/results.txt"
      out=$(SETTLE=$settle sh vr1pct.sh "$id" "$st" $((rate * vpf)) "$walk")
      echo "$out" | tee -a "$D/results.txt"
    fi
    [ -f "p1_${st}_$((rate * vpf)).png" ] && cp "p1_${st}_$((rate * vpf)).png" "$D/${st}_$rate.png"
    late=$(echo "$out" | grep -o "late frames [0-9.]*%" | grep -o "[0-9.]*")
    avg=$(echo "$out" | grep -o "median of [0-9]* windows: avg [0-9.]*" | grep -o "[0-9.]*$")
    if [ -n "$late" ] && awk "BEGIN{exit !($late < 1.0 && $avg >= $rate * 0.99)}"; then best=$rate; else break; fi
  done
  echo "SUSTAINABLE $id $st: $best Hz" | tee -a "$D/results.txt"
done
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force"
echo "DONE $D" | tee -a "$D/results.txt"
