#!/bin/sh
# rt_dumps.sh ID STATE RATE TAG [KEYS] [EXTRA_VIDEO]: real-time check from a savestate. Boots
# bin/savestates/ID/STATE.SAVESTAT.zst flat at Vblank RATE (temporary custom config, removed after; EXTRA_VIDEO adds
# more "Key: value" lines under Video:), sends KEYS (RPCS3_VR_KEYS script, e.g. 'I 7000 200\n'; needs a keyboard pad,
# made temporarily if missing) and writes two memory dumps 2.5 s apart to dumps/TAG.0 and .1.
# Compare runs with rthist.py BASE OTHER... (x1.0 = the same real-time speed). Env WAIT0 (6 s after the boot), WAIT1 (2 s
# after the keys) and GAP (2.5 s between the dumps).
id=$1; state=$2; rate=$3; tag=$4; keys=${5:-}; extra=${6:-}
cd "$(dirname "$0")"
W="$TEMP/rpcs3-vrprofile"
C=/f/rpsc3/source/rpcs3/bin/config/custom_configs/config_$id.yml
P=/f/rpsc3/source/rpcs3/bin/config/input_configs/$id
[ -f "$C" ] && { echo "a custom config exists for $id: not touching it"; exit 1; }
padhad=0; [ -d "$P" ] && padhad=1
[ $padhad = 0 ] && { mkdir -p "$P"; cp ../keyboard-pad-template.yml "$P/Default.yml"; }
printf 'Video:\n  Vblank Rate: %s\n' "$rate" > "$C"
[ -n "$extra" ] && printf '%b' "$extra" | sed 's/^/  /' >> "$C"
mkdir -p dumps; rm -f dumps/$tag.*
RPCS3_VR_MEMDUMP="$W/MEMDUMP" powershell -File ../launch.ps1 -Game "F:/rpsc3/source/rpcs3/bin/savestates/$id/$state.SAVESTAT.zst" -NoHeadset -Probe render=0 | tail -1
sleep ${WAIT0:-6}
[ -n "$keys" ] && sh keys.sh "$keys"
sleep ${WAIT1:-2}
touch "$W/MEMDUMP"; until [ ! -f "$W/MEMDUMP" ]; do sleep 0.1; done
sleep ${GAP:-2.5}
touch "$W/MEMDUMP"; until [ ! -f "$W/MEMDUMP" ]; do sleep 0.1; done
sleep 3
n=0; for f in $(ls -t "$W"/MEMDUMP.*.bin | head -2 | sort); do b=${f%.bin}; for x in bin idx txt; do mv "$b.$x" "dumps/$tag.$n.$x"; done; n=$((n + 1)); done
powershell -c "(Get-Process rpcs3).MainWindowTitle; Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; \$t=0; while ((Get-Process rpcs3 -ErrorAction SilentlyContinue | Where-Object { \$_.Threads.Count -gt 1 }) -and \$t -lt 150) { Start-Sleep -Milliseconds 200; \$t++ }"
rm -f "$C"; [ -f "$C" ] && echo "WARNING: temporary $C still present"
[ $padhad = 0 ] && rm -r "${P:?}"
true
