#!/bin/sh
# vr1pct.sh ID STATE VBLANK [WALK=1]: desktop-stereo frame-time stats (fork hook RPCS3_VR_FRAMESTATS) from
# bin/savestates/ID/STATE.SAVESTAT.zst at a fixed Vblank rate.
# Env SCALE = resolution scale % (default 300), SETTLE = seconds before measuring (default 10).
# Only Vblank Rate and Resolution Scale are merged into the game's custom config for the run (other settings kept;
# the file is restored after). Walks back and forth ~25 s with a temporary keyboard pad unless WALK=0, prints the
# 8 s windows that start after the settle (load and warm-up excluded) and a summary: median avg FPS, 1% low and
# late (missed) frames = frames longer than 1.5x the median frame time. Screenshot: shot.py's p1_STATE_VBLANK.
C=/f/rpsc3/source/rpcs3/bin/config/custom_configs/config_$1.yml
had=0; [ -f "$C" ] && { had=1; cp "$C" "$C.vr1pct.bak"; }
py -3.13 - "$C" "$3" "${SCALE:-300}" <<'PY'
import sys, os, re
p, vblank, scale = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p, encoding='utf8').read() if os.path.exists(p) else ''
if not re.search(r'^Video:\s*$', s, re.M):
    s = s + ('' if s.endswith('\n') or not s else '\n') + 'Video:\n'
for key, val in (('Vblank Rate', vblank), ('Resolution Scale', scale)):
    if re.search(r'^  %s:.*$' % key, s, re.M):
        s = re.sub(r'^  %s:.*$' % key, '  %s: %s' % (key, val), s, flags=re.M)
    else:
        s = re.sub(r'^Video:\s*$', 'Video:\n  %s: %s' % (key, val), s, count=1, flags=re.M)
open(p, 'w', encoding='utf8', newline='\n').write(s)
PY
P=/f/rpsc3/source/rpcs3/bin/config/input_configs/$1; padhad=0; [ -d "$P" ] && padhad=1
if [ $padhad = 0 ] && [ "${4:-1}" = 1 ]; then mkdir -p "$P"; cp /f/rpsc3/source/plans/tools/keyboard-pad-template.yml "$P/Default.yml"; fi
RPCS3_VR_FRAMESTATS=8 powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/$1/$2.SAVESTAT.zst" -Probe 'render=1' >/dev/null
sleep "${SETTLE:-10}"
L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log
n0=$(grep -ac "VR frame stats" $L)
if [ "${4:-1}" = 1 ]; then
  sh keys.sh 'I 1500 50\nK 1500 50\nI 1500 50\nK 1500 50\nI 1500 50\nK 1500 50\nI 1500 50\nK 1500 50\nI 1500 50\nK 1500 50\nI 1500 50\nK 1500 50\nI 1500 50\nK 1500 50\nI 1500 50\nK 1500 50\n'
fi
sleep 26
py -3.13 shot.py "$1" "p1_$2_$3" 480 >/dev/null
# Windows that start after the settle: skip the one under way when measuring began.
lines=$(grep -a "VR frame stats" $L | tail -n +$((n0 + 2)) | sed -E 's/.*VR frame stats: //' | head -3)
echo "$1 $2 vblank $3 scale ${SCALE:-300}%:"; echo "$lines" | sed 's/^/   /'
med() { sort -n | awk '{a[NR]=$1} END{if(NR) printf "%s", a[int((NR+1)/2)]}'; }
low=$(echo "$lines" | grep -o "FPS, 1% low [0-9.]*" | grep -o "[0-9.]*$" | med)
late=$(echo "$lines" | grep -o "late [0-9.]*%" | grep -o "[0-9.]*" | med)
avg=$(echo "$lines" | grep -o "avg [0-9.]* FPS" | grep -o "[0-9.]*" | med)
n=$(echo "$lines" | grep -c "frames over")
if [ -n "$low" ]; then echo "   => median of $n windows: avg $avg FPS, 1% low $low, late frames $late%"; else echo "   => no frame stats (did not run)"; fi
if [ $had = 1 ]; then mv -f "$C.vr1pct.bak" "$C"; else rm -f "$C"; fi
[ $padhad = 0 ] && [ "${4:-1}" = 1 ] && rm -r "${P:?}"
true
