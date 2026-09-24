#!/bin/sh
# ico_ab.sh SCALE OUT [AUDIT]: set the ICO "Wider view" patch value, boot to the cage hall with stereo + audit, screenshot OUT.
py -3.13 /f/rpsc3/source/plans/tools/re/ico_scale.py "$1"
W="$TEMP/rpcs3-vrprofile"
RPCS3_VR_AUDIT_FOV=1.0 powershell -c "& F:\rpsc3\source\plans\tools\re\ico_boot.ps1 -Probe 'render=1' -Audit '${3:-40}'" > /dev/null
sleep 20; printf 'Return 150 2500\nX 150 2500\nReturn 150 2500\n' > "$W/KEYS"; sleep ${4:-20}
sh /f/rpsc3/source/plans/tools/re/lastshot.sh "$2"
