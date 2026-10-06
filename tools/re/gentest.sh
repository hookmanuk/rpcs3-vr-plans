#!/bin/sh
# gentest.sh ID STATE: runs the profile generator on a savestate with the game's profile moved aside; saves the
# generated profile and the VRGEN log lines to $OUT (default %TEMP%/rpcs3-vrprofile/gentest); restores profile, config and pad.
SP=${OUT:-$(cygpath -u "$TEMP")/rpcs3-vrprofile/gentest}; mkdir -p "$SP"
cd /f/rpsc3/source/plans/tools/re
id=$1; st=$2
B=/f/rpsc3/source/rpcs3/bin; L=$B/log/RPCS3.log; J=$B/vr_profiles/$id.json
P=$B/config/input_configs/$id
padhad=0; [ -d "$P" ] && padhad=1
[ $padhad = 0 ] && { mkdir -p "$P"; cp ../keyboard-pad-template.yml "$P/Default.yml"; }
cp "$J" "$SP/$id.keep.json" && rm "$J"
C=$B/config/custom_configs/config_$id.yml; cfghad=0; [ -f "$C" ] && cfghad=1
[ $cfghad = 1 ] && py -3.13 cfgtemp.py $id set "Video/VR/Enabled=false" "Audio/Renderer=Null" >/dev/null
py -3.13 simpose.py 0 0 0 >/dev/null
G=$(cygpath -u "$TEMP")/rpcs3-vrprofile/GEN; rm -f "$G"
timeout 60 powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/$id/$st.SAVESTAT.zst" >/dev/null 2>&1
sleep 40; touch "$G"
for i in $(seq 1 120); do grep -aq "VR profile written\|VRGEN.*fail\|cannot write" $L && break; sleep 1; done
sleep 2
grep -a "VRGEN" $L | cut -c1-600 > "$SP/$id.genlog.txt"
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; \$t=0; while ((Get-Process rpcs3 -ErrorAction SilentlyContinue | Where-Object { \$_.Threads.Count -gt 1 }) -and \$t -lt 150) { Start-Sleep -Milliseconds 200; \$t++ }"
sleep 1
for f in $B/vr_profiles/$id.json $B/vr_profiles/$id.*.json; do [ -f "$f" ] && mv "$f" "$SP/$id.gen.$(basename $f)"; done
cp "$SP/$id.keep.json" "$J"
rm -f "$G"
if [ $cfghad = 1 ]; then py -3.13 cfgtemp.py $id restore >/dev/null; else rm -f "$C"; fi
[ $padhad = 0 ] && rm -r "${P:?}"
ls "$SP" | grep "$id.gen"; tail -3 "$SP/$id.genlog.txt"
