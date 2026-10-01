#!/bin/sh
# mkvrstate.sh ID SRC_STATE NEW_NAME 'KEYS' WAIT: boot bin/savestates/ID/SRC_STATE (flat, temporary keyboard pad),
# send KEYS, wait WAIT s, screenshot (st_NEW_NAME), Ctrl+S, copy the new savestate to bin/savestates/ID/NEW_NAME.
id=${1:?}; src=${2:?}; name=${3:?}
S="/f/rpsc3/source/rpcs3/bin/savestates/${id:?}"
P="/f/rpsc3/source/rpcs3/bin/config/input_configs/${id:?}"
padhad=0; [ -d "$P" ] && padhad=1
[ $padhad = 0 ] && { mkdir -p "$P"; cp ../keyboard-pad-template.yml "$P/Default.yml"; }
powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/$id/$src.SAVESTAT.zst" >/dev/null
sleep 6; sh keys.sh "$4"; sleep "${5:-3}"
py -3.13 shot.py "$id" "st_$name" 480 >/dev/null
touch "$TEMP/mark_$name"
powershell -File ../keys.ps1 -Keys "Ctrl+S" >/dev/null 2>&1
until [ -n "$(find "$S" -name "${id}_*.SAVESTAT.zst" -newer "$TEMP/mark_$name")" ]; do sleep 2; done; sleep 8
f=$(ls -t "$S"/"${id}"_*.SAVESTAT.zst | head -1)
cp -f "$f" "$S/$name.SAVESTAT.zst"; echo "$name <- $(basename "$f")"
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force"
[ $padhad = 0 ] && rm -r "${P:?}"
true
