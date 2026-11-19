#!/usr/bin/env bash
# skipregion.sh "X0 Y0 X1 Y1" "PGM ..." : on a running VR session, each shader skipped live (dev trigger SKIP), both
# eyes dumped (dev trigger EYES), and the mean change against no skip in the box (left-eye pixels) and over the eye.
# Finds which pass draws an artifact at a spot. Dumps go to /h/uc_tests/skr_<pgm>_{0,1}.raw (none = no skip).
BOX=$1; D="$TEMP/dcvr"; mkdir -p "$D"; S=$(( ${EYE:-3584} * ${EYE:-3584} * 4 + 8 ))
set_skip() { printf '%s' "$1" > "$D/SKIP.tmp"; mv "$D/SKIP.tmp" "$D/SKIP"; sleep 1.2; }
dump() {
    rm -f "$D"/eye_*.raw; : > "$D/EYES.tmp"; mv "$D/EYES.tmp" "$D/EYES"
    for i in $(seq 1 200); do [ "$(stat -c %s "$D/eye_1.raw" 2>/dev/null)" = $S ] && break; sleep 0.05; done
    mv "$D/eye_0.raw" /h/uc_tests/skr_$1_0.raw; mv "$D/eye_1.raw" /h/uc_tests/skr_$1_1.raw
}
set_skip ""; dump none
for p in $2; do
    set_skip $p; dump $p
    python - "$BOX" $p <<'EOF'
import sys, struct, numpy as np
box = [int(v) for v in sys.argv[1].split()]; p = sys.argv[2]
def eye(n):
    d = open(n, 'rb').read(); w, h = struct.unpack('<II', d[:8])
    return np.frombuffer(d[8:8 + w * h * 4], np.uint8).reshape(h, w, 4)[..., :3].astype(np.int16)
a, b = eye('H:/uc_tests/skr_none_0.raw'), eye('H:/uc_tests/skr_%s_0.raw' % p)
x0, y0, x1, y1 = box
d = np.abs(a - b)
print('%-10s box %5.2f  eye %5.2f' % (p, d[y0:y1, x0:x1].mean(), d.mean()), flush=True)
EOF
done
set_skip ""
