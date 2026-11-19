#!/usr/bin/env bash
# dmgcatch.sh [TRIES]: U3 bar fight, running session: fights (square / triangle, as redcatch.sh; SKIPTHROW=1: no throw
# first) and, when the red damage strip shows in the desktop window (redcatch.sh's test), logs the frame's draws (DRAWLOG) and
# shoots the display buffer after each HUD draw (TSHOT display): run.log "VR draws" lines and $TEMP/dcvr/tshot_*.raw.
F=/h/uncharted_pc/out/try/u3/pad.txt; D="$TEMP/dcvr"; T=$(cd "$(dirname "$0")" && pwd)
put() { printf '%s' "$1" > $F.tmp; mv $F.tmp $F; }
trig() { printf '%s' "$2" > "$D/$1.tmp"; mv "$D/$1.tmp" "$D/$1"; }
streak() {
    python - "$1" <<'PY'
import sys, numpy as np
from PIL import Image
a = np.asarray(Image.open(sys.argv[1]).crop((420, 0, 1500, 1080))).astype(int)
red = (a[..., 0] > 70) & (a[..., 0] > 2.8 * a[..., 1]) & (a[..., 0] > 2.8 * a[..., 2])
rows = red.sum(1)
for y in range(30, 1050):
    if rows[y] > 150 and rows[y - 25] < rows[y] / 4 and rows[y + 25] < rows[y] / 4:
        print('streak row', y, rows[y]); sys.exit(0)
sys.exit(1)
PY
}
[ "$SKIPTHROW" = 1 ] || { put "ly=0 circle"; sleep 0.3; put ""; sleep 2; }
for k in $(seq 1 ${1:-120}); do
    [ $((k % 6)) = 0 ] && { put "ly=0 circle"; sleep 0.3; put ""; sleep 2; }
    for i in 1 2; do put square; sleep 0.12; put ""; sleep 0.25; put triangle; sleep 0.12; put ""; sleep 0.25; done
    python "$T/winshot.py" H:/uc_tests/dmg_win.png >/dev/null
    if streak H:/uc_tests/dmg_win.png; then
        rm -f "$D"/tshot_*; trig DRAWLOG ""; trig TSHOT display
        sleep 3; python "$T/winshot.py" H:/uc_tests/dmg_win2.png >/dev/null
        echo "caught at try $k"; exit 0
    fi
done
echo "no streak in ${1:-120} tries"
