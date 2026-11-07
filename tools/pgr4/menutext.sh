#!/bin/sh
# menutext.sh TAG [NAME=VALUE...]: simulator, main menu: the left eye's menu text at several small head poses, close up: out/TAG_text.png. To compare a depth fight in the menu's layers with and without a fix.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; RE=/f/rpsc3/source/plans/tools/re
TAG=$1; shift
st() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
NO_RACE=1 sh $T/vrrace.sh 3692x3692 SIMXR_HZ=90 "$@" >/dev/null 2>&1
$P wait 3s >/dev/null
st START 6s; st A 6s
i=0
for pose in "3 1 0.5" "-4 2 -1" "7 -3 1.5" "-9 -1 2"; do
    i=$((i+1))
    py -3 -I $RE/simpose.py $pose >/dev/null
    sleep 1
    $P shot H:/PGR4-ReGPU/out/${TAG}_t$i.png >/dev/null
done
py -3 -I $RE/simpose.py 0 0 0 >/dev/null
$P stop >/dev/null 2>&1
sleep 3
py -3 - "$TAG" <<'EOF'
import sys
import numpy as np
from PIL import Image
t = sys.argv[1]
O = 'H:/PGR4-ReGPU/out/'
m = Image.new('RGB', (1800, 1240))
for i in range(4):
    a = Image.open(O + '%s_t%d.png' % (t, i + 1)).convert('RGB')
    w, h = a.size
    # The band of the frame with the menu's red and white text.
    n = np.asarray(a, dtype=np.int16)
    red = (n[:, :, 0] > 120) & (n[:, :, 1] < 90) & (n[:, :, 2] < 90)
    row = int(np.argmax(red[:, :w // 2].sum(axis=1)))
    box = (0, max(0, row - int(h * .06)), w, min(h, row + int(h * .07)))
    c = a.crop(box)
    m.paste(c.resize((1800, int(1800 * c.size[1] / c.size[0]))), (0, 310 * i))
m.save(O + t + '_text.png')
EOF
