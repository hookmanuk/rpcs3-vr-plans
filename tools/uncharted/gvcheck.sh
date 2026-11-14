#!/usr/bin/env bash
# gvcheck.sh GAME LABEL: on a running session of GAME (u1|u2|u3, in play, eye 2880), the game view fix (dev trigger
# GAMEVIEW 0 off / 2 on) checked two ways:
#  still: head held 20 degrees left, standing: dumps for 0 / 2 / 0 / 2; the picture must be the same on and off (the
#         head once, not twice): prints the mean difference between the dumps (left eye, 8x smaller).
#  turn:  head held 35 left, right stick turning the camera 3 s: two dumps each for 0 / 2 / 0 / 2
#         (/h/uc_tests/gv_LABEL_turn<n>_g<G>_{a,b}.raw) for a sheet: holes at the left are the culling.
T=$(cd "$(dirname "$0")" && pwd); G=$1; L=$2; D="$TEMP/dcvr"; F=/h/uncharted_pc/out/try/$G/pad.txt; U=/h/uc_tests
nap() { python -c "import time; time.sleep($1)"; }
pad() { printf '%s' "$1" > $F.tmp; mv $F.tmp $F; nap $2; printf '' > $F.tmp; mv $F.tmp $F; }
trig() { printf '%s' "$2" > "$D/$1.tmp"; mv "$D/$1.tmp" "$D/$1"; nap 0.5; }
eye() { rm -f "$D"/eye_*.raw; : > "$D/EYES.tmp"; mv "$D/EYES.tmp" "$D/EYES"
    for i in $(seq 1 100); do [ "$(stat -c %s "$D/eye_1.raw" 2>/dev/null)" = 33177608 ] && break; nap 0.05; done; nap 0.3; mv "$D/eye_0.raw" "$1"; }
n=0; for g in 0 2 0 2; do n=$((n+1)); trig GAMEVIEW $g; (python $T/simhold.py 20 0 0 3 &); nap 1.5; eye $U/gv_${L}_still${n}_g$g.raw; nap 2; done
python - "$U/gv_${L}_still" <<'EOF'
import sys, numpy as np
N = 2880
ld = lambda p: np.fromfile(p, np.uint8)[8:8 + N * N * 4].reshape(N, N, 4)[::8, ::8, :3].astype(np.float32)
a = [ld(sys.argv[1] + '%d_g%d.raw' % (n, g)) for n, g in ((1, 0), (2, 2), (3, 0), (4, 2))]
d = lambda x, y: float(np.abs(x - y).mean())
print('still, mean difference: off-on %.2f %.2f %.2f, off-off %.2f, on-on %.2f' % (d(a[0], a[1]), d(a[1], a[2]), d(a[2], a[3]), d(a[0], a[2]), d(a[1], a[3])))
EOF
n=0; for g in 0 2 0 2; do n=$((n+1)); trig GAMEVIEW $g; (python $T/simhold.py 35 0 0 7 &); nap 1.5
    (pad "rx=255" 3 &); nap 0.8; eye $U/gv_${L}_turn${n}_g${g}_a.raw; eye $U/gv_${L}_turn${n}_g${g}_b.raw; nap 1.5; pad "rx=0" 3; nap 2.5; done
trig GAMEVIEW ""
grep -a "Frame rate" /h/uncharted_pc/out/try/$G/run.log | tail -1
