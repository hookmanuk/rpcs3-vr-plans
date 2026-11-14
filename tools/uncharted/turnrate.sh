#!/usr/bin/env bash
# turnrate.sh: in a running Borneo session, the game camera's yaw (its own view's forward, CAMLOG) before and after 2 s
# of right stick (rx=255) and its pitch, for GAMEVIEW 0 / 2 at head yaw 0 and 35: does the head on the game's own view
# change how the stick turns the camera?
T=$(cd "$(dirname "$0")" && pwd); D="$TEMP/dcvr"; R=/h/uncharted_pc/out/try/u2/run.log
nap() { python -c "import time; time.sleep($1)"; }
yaw() { : > "$D/CAMLOG"; nap 0.6; grep -a "VR camera: build from +0x16605d" $R | tail -1 | python -c "
import sys, math, re
m = re.search(r' z (\S+) (\S+) (\S+) ', sys.stdin.read()); x, y, z = (float(v) for v in m.groups())
print('%.2f %.2f' % (math.degrees(math.atan2(x, z)), math.degrees(math.asin(y))))"; }
for h in 0 35 0 35; do for g in 0 2; do
    printf '%s' "$g" > "$D/GAMEVIEW.tmp"; mv "$D/GAMEVIEW.tmp" "$D/GAMEVIEW"; (python $T/simhold.py $h 0 0 6 &); nap 1.5
    a=$(yaw); bash $T/pad.sh "rx=255" 2; nap 0.5; b=$(yaw); echo "head $h gameview $g: yaw/pitch before $a after $b"; bash $T/pad.sh "rx=0" 2; nap 2.5
done; done
