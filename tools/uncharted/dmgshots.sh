#!/usr/bin/env bash
# dmgshots.sh [TRIES]: U3 bar fight, running session: fights (square / triangle on the pad file) and after each combo
# grabs the desktop window and the OpenXR Simulator's composite; keeps the pair with the most pure-red pixels (the
# damage indicator's spray: R > 40, G and B under a quarter of R) as /h/uc_tests/dmgbest_win.png / dmgbest_sim.full.png.
F=/h/uncharted_pc/out/try/u3/pad.txt; T=$(cd "$(dirname "$0")" && pwd)
put() { printf '%s' "$1" > $F.tmp; mv $F.tmp $F; }
best=0
for k in $(seq 1 ${1:-30}); do
    [ $((k % 8)) = 0 ] && { put "ly=0 circle"; sleep 0.3; put ""; sleep 1.5; }
    for i in 1 2; do put square; sleep 0.12; put ""; sleep 0.25; put triangle; sleep 0.12; put ""; sleep 0.25; done
    python "$T/winshot.py" H:/uc_tests/dmgw.png >/dev/null
    python "$T/simshot.py" H:/uc_tests/dmgs >/dev/null 2>&1
    n=$(python - <<'PY'
import numpy as np
from PIL import Image
a = np.asarray(Image.open('H:/uc_tests/dmgw.png').convert('RGB')).astype(int)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
print(int(((r > 40) & (g * 4 < r) & (b * 4 < r)).sum()))
PY
)
    echo "try $k: $n red"
    if [ "$n" -gt "$best" ]; then best=$n; cp H:/uc_tests/dmgw.png H:/uc_tests/dmgbest_win.png; cp H:/uc_tests/dmgs.full.png H:/uc_tests/dmgbest_sim.full.png 2>/dev/null; fi
done
echo "best $best"
