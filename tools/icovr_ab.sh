#!/bin/bash
# icovr_ab.sh SECONDS SWITCH NAME [ENV=VALUE ...] (ICOVR_ARGS: the game's arguments): an in-run A/B of the ICO VR port on
# the simulator. After SECONDS dumps both eyes (A), creates the trigger file SWITCH in the eyes folder (rd_vr.c reads
# it every 32 pictures, e.g. "onesided"), dumps (B), removes it, dumps again (A2, the drift control). Files
# NAME_A_L.png, NAME_B_L.png, NAME_A2_L.png (and _R) in the eyes folder.
S=$1; SW=$2; N=$3; shift 3
E=/c/Users/matt/AppData/Local/Temp/claude/4d94c0b8726ad438/a2506519-9380-442c-9fe4-e4dd90a66203/scratchpad/eyes
D='C:\Users\matt\AppData\Local\Temp\claude\4d94c0b8726ad438\a2506519-9380-442c-9fe4-e4dd90a66203\scratchpad\eyes'
ENVS="ICO_VR_DUMP_DIR='$D'"
for kv in "$@"; do ENVS="$ENVS; ${kv%%=*}='${kv#*=}'"; done
rm -f "$E/$SW" $E/eye_*.png $E/pid.txt
powershell.exe -NoProfile -Command "& F:\rpsc3\source\plans\tools\icovr_sim.ps1 -Env @{$ENVS} -GameArgs '${ICOVR_ARGS:-}' | Out-File -Encoding ascii '$D\pid.txt'" </dev/null >/dev/null 2>&1
id=$(tr -d '\r\n' < $E/pid.txt)
sleep $S
take() {
    printf 1 > $E/dump
    sleep 3
    l=$(ls -t $E/eye_*_L.png 2>/dev/null | head -1); r=$(ls -t $E/eye_*_R.png 2>/dev/null | head -1)
    if [ -n "$l" ]; then mv "$l" $E/${N}_$1_L.png; mv "$r" $E/${N}_$1_R.png; echo "$1 dumped"; else echo "$1: no dump"; fi
}
take A
touch "$E/$SW"; sleep 1
take B
rm -f "$E/$SW"; sleep 1
take A2
taskkill //F //PID $id >/dev/null 2>&1
rm -f $E/chain_*.png
