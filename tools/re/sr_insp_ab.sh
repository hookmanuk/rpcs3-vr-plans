#!/bin/sh
# sr_insp_ab.sh TAG YAW: load vrtest_sr_birds in VR, set the simulator head yaw, arm one inspector capture at a fixed
# delay after the first frame stats, copy it to scratchpad/sr_insp_TAG.jsonl.
cd "$(dirname "$0")"
I="$TEMP/rpcs3-vrprofile/insp"; S="C:/Users/matt/AppData/Local/Temp/claude/f--rpsc3-source/8cd89833-9bdf-46e0-a6c8-4341eafebcce/scratchpad"
PROBE=${PROBE:-render=1} sh sess.sh start BLUS30068 vrtest_sr_birds >/dev/null
py -3.13 simpose.py $2 0 0 >/dev/null; sleep 4
touch "$I/ARM"; sleep 4
cp "$(ls -t "$I"/BLUS30068_*.jsonl | head -1)" "$S/sr_insp_$1.jsonl"
py -3.13 simpose.py 0 0 0 >/dev/null; sh sess.sh stop BLUS30068 >/dev/null
