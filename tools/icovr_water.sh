#!/bin/bash
# icovr_water.sh SECONDS STAGE...: each stage start in VR on the simulator for SECONDS (no input); prints the last
# "VR: water" line (reflection draws: pool and puddle cameras; pool grids by kind; puddle ripples = shifted screen
# draws; shadow lists).
S=$1; shift
L=/h/ico-pc/dist/x64/logs/ico-pc.log
for st in "$@"; do
    ICOVR_ENV="ICO_START_STAGE=$st" bash /f/rpsc3/source/plans/tools/icovr_rate.sh 90 $S icovr-idle.txt >/dev/null
    echo "WATER stage $st: $(grep -a 'VR: water' $L | tail -1 | sed 's/.*water: //; s/; shadow.*//')"
done
