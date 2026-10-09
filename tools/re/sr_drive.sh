#!/bin/sh
# sr_drive.sh OUT [PROBE]: SEGA Rally (BLUS30068) VR session at Vblank 90 from vrtest_segarally_race, R2 (W) held 60 s;
# Env EXTRA="Section/Key=value": one more config key for the run.
# Env SCALE: resolution scale (default 300).
# writes the per-second frame stats (fps, rsx ms) to OUT. Env passes through (dev switches).
cd "$(dirname "$0")"
L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log
py -3.13 cfgtemp.py BLUS30068 set "Video/Vblank Rate=90" ${EXTRA:+"$EXTRA"} ${EXTRA2:+"$EXTRA2"} >/dev/null
PROBE=${2:-render=1} sh sess.sh start BLUS30068 vrtest_segarally_race ${SCALE:-300} >/dev/null
sh keys.sh "W 60000 50\n"; sleep 52
grep -a "VR frame stats" $L | sed -E 's/.*avg ([0-9.]+) FPS.*late ([0-9.]+)%, RSX thread ([0-9.]+) ms.*/\1 \2 \3/' > "$1"
sh sess.sh stop BLUS30068 >/dev/null
