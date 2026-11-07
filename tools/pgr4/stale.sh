#!/bin/sh
# stale.sh TAG: looks for stale vertex data: scrolls through cars in car select (a shot of each), then a race on St Petersburg, abandons it, a race on another chapter's track,
# burnout on its grid (skid marks), a shot each. Game just started. Shots out/TAG_<n>.png, montage out/TAG.png. Works flat or VR.
P=/f/rpsc3/source/plans/tools/pgr4/pg.sh; O=H:/PGR4-ReGPU/out; TAG=${1:-st}
st() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
shot() { $P shot $O/${TAG}_$1.png >/dev/null; }
$P wait 3s >/dev/null
st START 6s; st A 6s; st A 4s; st A 4s; st A 4s; st A 6s
shot 0
st DOWN 4s; shot 1
st DOWN 4s; shot 2
st DOWN 4s; shot 3
st UP 4s; st UP 4s; st UP 4s; shot 4
st A 6s; st A 15s; st A 12s
shot 5
# Pause, down to Abandon Event, confirm: back in the menus.
st START 3s; st DOWN 1s; st DOWN 1s; st DOWN 1s; st DOWN 1s; st DOWN 1s; shot 6
st A 3s; st A 12s
shot 7
# Another track over the same memory: chapter 2, event 3, Las Vegas.
st RIGHT 2s; st A 4s; st RIGHT 2s; st RIGHT 2s; st A 4s; st A 4s; st A 6s; st A 15s; st A 12s
shot 8
$P trigger R 1 >/dev/null; sleep 7; shot 9; sleep 3; shot 10; $P trigger R 0 >/dev/null; shot 11
$P status | cut -c1-90
python - "$TAG" <<EOF
import sys
from PIL import Image
t = sys.argv[1]
m = Image.new('RGB', (1600, 675))
for i in range(12):
    im = Image.open('H:/PGR4-ReGPU/out/%s_%d.png' % (t, i)).convert('RGB')
    W, H = im.size
    if W == H:
        im = im.crop((int(W * .1), int(H * .15), int(W * .9), int(H * .6)))
    m.paste(im.resize((400, 225)), ((i % 4) * 400, (i // 4) * 225))
m.save('H:/PGR4-ReGPU/out/%s.png' % t)
EOF
