#!/usr/bin/env bash
# greycatch.sh [TRIES]: U3 bar fight, running session: fights until the picture goes grey (Drake near death: the window's
# mean colour spread under 6), then logs the draws (DRAWLOG) and shoots the display buffer per draw (TSHOT display);
# the grey window as /h/uc_tests/grey_win.png.
F=/h/uncharted_pc/out/try/u3/pad.txt; D="$TEMP/dcvr"; T=$(cd "$(dirname "$0")" && pwd)
put() { printf '%s' "$1" > $F.tmp; mv $F.tmp $F; }
trig() { printf '%s' "$2" > "$D/$1.tmp"; mv "$D/$1.tmp" "$D/$1"; }
for k in $(seq 1 ${1:-60}); do
    [ $((k % 8)) = 0 ] && { put "ly=0 circle"; sleep 0.3; put ""; sleep 1.5; }
    put square; sleep 0.12; put ""; sleep 0.3
    python "$T/winshot.py" H:/uc_tests/grey_win.png >/dev/null
    s=$(python -c "
import numpy as np; from PIL import Image
a=np.asarray(Image.open('H:/uc_tests/grey_win.png').convert('RGB').crop((420,0,1500,1080))).astype(int)
print(int((abs(a[...,0]-a[...,1])+abs(a[...,1]-a[...,2])).mean()))")
    if [ "$s" -lt 6 ]; then
        [ "$NOSHOT" = 1 ] || { rm -f "$D"/tshot_*; trig DRAWLOG ""; trig TSHOT display; sleep 3; }
        echo "grey at try $k (spread $s)"; exit 0
    fi
done
echo "never grey"
