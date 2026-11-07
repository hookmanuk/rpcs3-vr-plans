#!/bin/sh
# flickrun.sh TAG [NAME=VALUE...]: simulator, warm cache assumed: looks for frame-to-frame flicker. Main menu: 8 shots, crops of the menu text in out/TAG_menutext.png. Race, in-car view (LB twice), paused: 10 shots, flick.py's changes in out/TAG_car.png.
T=/f/rpsc3/source/plans/tools/pgr4; P=$T/pg.sh; O=H:/PGR4-ReGPU/out
TAG=$1; shift
st() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
NO_RACE=1 sh $T/vrrace.sh 2880x2880 "$@" | tail -1 | cut -c1-70
$P wait 3s >/dev/null
st START 6s; st A 6s   # to the main menu
files=""
for i in 1 2 3 4 5 6 7 8; do
    $P shot $O/${TAG}_menu_$i.png >/dev/null
    files="$files $O/${TAG}_menu_$i.png"
done
py -3 - $O/${TAG}_menutext.png $files <<'EOF'
import sys
from PIL import Image
out, shots = sys.argv[1], sys.argv[2:]
m = Image.new('RGB', (1800, 200 * ((len(shots) + 1) // 2)))
for i, p in enumerate(shots):
    a = Image.open(p).convert('RGB')
    s = a.size[0] / 900
    c = a.crop((int(280 * s), int(410 * s), int(900 * s), int(530 * s))).resize((900, 174))
    m.paste(c, (900 * (i % 2), 200 * (i // 2)))
m.save(out)
EOF
for f in $files; do rm -f "$f"; done
st A 4s; st A 4s; st A 4s; st A 6s; st A 15s; st A 12s   # single player, arcade, chapter, event, car: the grid
st LB 2s; st LB 2s    # the in-car view
$P trigger R 1 >/dev/null; sleep 5; $P trigger R 0 >/dev/null
st START 3s           # paused: a still scene
files=""
for i in 1 2 3 4 5 6 7 8 9 10; do
    $P shot $O/${TAG}_car_$i.png >/dev/null
    files="$files $O/${TAG}_car_$i.png"
done
echo "--- $TAG car paused"
py -3 $T/flick.py $O/${TAG}_car.png $files 2>&1 | grep -v -i 'deprecat\|getdata'
for f in $files; do rm -f "$f"; done
$P stop >/dev/null 2>&1
sleep 3
