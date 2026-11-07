#!/bin/sh
# menus.sh TAG: on a game just started: the screens from the title on, one shot each (out/TAG_<n>.png): profile dialog, main menu, arcade, chapter, event, car.
# Stops before starting a race. In VR the shots are the left eye.
P=/f/rpsc3/source/plans/tools/pgr4/pg.sh; O=H:/PGR4-ReGPU/out; TAG=${1:-menu}
st() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; $P shot $O/${TAG}_$3.png >/dev/null; }
$P wait 3s >/dev/null
st START 6s 0
st A 6s 1
st A 4s 2
st A 4s 3
st A 4s 4
st A 4s 5
st A 5s 6
st A 5s 7
python - "$TAG" <<EOF
import sys
from PIL import Image
t = sys.argv[1]
m = Image.new('RGB', (1600, 900 if t.startswith('fl') else 1600))
for i in range(8):
    im = Image.open('H:/PGR4-ReGPU/out/%s_%d.png' % (t, i)).convert('RGB')
    im = im.resize((400, 225 if t.startswith('fl') else 400))
    m.paste(im, ((i % 4) * 400, (i // 4) * im.height))
m = m.crop((0, 0, 1600, 2 * (225 if t.startswith('fl') else 400)))
m.save('H:/PGR4-ReGPU/out/%s.png' % t)
EOF
