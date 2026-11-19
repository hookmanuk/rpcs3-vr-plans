#!/usr/bin/env bash
# redcatch.sh [TRIES]: U3 bar fight, running session: fights (square / triangle on the pad file, the throw every 6th
# try for the tutorial after a death) and checks the desktop window for a thin saturated red horizontal streak (a band
# under 25 rows with 150+ red pixels a row, the rows 20 above and below without). When one shows: both eyes dumped at
# once (/h/uc_tests/red_{0,1}.raw), then the window again (red_win.png before, red_win2.png after).
F=/h/uncharted_pc/out/try/u3/pad.txt; D="$TEMP/dcvr"; S=$((3584*3584*4+8)); T=$(cd "$(dirname "$0")" && pwd)
put() { printf '%s' "$1" > $F.tmp; mv $F.tmp $F; }
streak() {
    python - "$1" <<'EOF'
import sys, numpy as np
from PIL import Image
a = np.asarray(Image.open(sys.argv[1]).crop((420, 0, 1500, 1080))).astype(int)
red = (a[..., 0] > 70) & (a[..., 0] > 2.8 * a[..., 1]) & (a[..., 0] > 2.8 * a[..., 2])
rows = red.sum(1)
for y in range(30, 1050):
    if rows[y] > 150 and rows[y - 25] < rows[y] / 4 and rows[y + 25] < rows[y] / 4:
        print('streak row', y, rows[y]); sys.exit(0)
sys.exit(1)
EOF
}
for k in $(seq 1 ${1:-40}); do
    [ $((k % 6)) = 1 ] && { put "ly=0 circle"; sleep 0.3; put ""; sleep 2; } # the throw tutorial after a death
    for i in 1 2; do put square; sleep 0.12; put ""; sleep 0.25; put triangle; sleep 0.12; put ""; sleep 0.25; done
    python "$T/winshot.py" H:/uc_tests/rc.png >/dev/null
    if streak H:/uc_tests/rc.png; then
        rm -f "$D"/eye_*.raw; : > "$D/EYES.tmp"; mv "$D/EYES.tmp" "$D/EYES"
        for i in $(seq 1 200); do [ "$(stat -c %s "$D/eye_1.raw" 2>/dev/null)" = $S ] && break; sleep 0.05; done
        python "$T/winshot.py" H:/uc_tests/red_win2.png >/dev/null; streak H:/uc_tests/red_win2.png
        mv "$D/eye_0.raw" /h/uc_tests/red_0.raw; mv "$D/eye_1.raw" /h/uc_tests/red_1.raw; cp H:/uc_tests/rc.png H:/uc_tests/red_win.png
        echo "caught at try $k"; exit 0
    fi
done
echo "no streak in ${1:-40} tries"
