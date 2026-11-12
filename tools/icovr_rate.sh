#!/bin/bash
# icovr_rate.sh HZ SECONDS [SCRIPT] (ICOVR_ENV="NAME=VALUE ..." extra env): the ICO VR port on the simulator at HZ
# (SIMXR_HZ), the pad script (default icovr-walk.txt: boot to the first hall, then walk), stopped after SECONDS; prints
# the headset lines (FPS, 1% low, late %) and the renderer's 10 s perf lines.
HZ=$1; S=$2; SC=${3:-icovr-walk.txt}
L=/h/ico-pc/dist/x64/logs/ico-pc.log
ENVS="SIMXR_HZ='$HZ'"
for kv in $ICOVR_ENV; do ENVS="$ENVS; ${kv%%=*}='${kv#*=}'"; done
powershell.exe -NoProfile -Command "\$id = & F:\rpsc3\source\plans\tools\icovr_sim.ps1 -Env @{$ENVS} -GameArgs '--pad-script $SC'; Start-Sleep $S; Stop-Process -Id \$id -Force" >/dev/null
grep -a "headset .* FPS" $L | tail -4
grep -a "rd: perf\|render thread" $L | tail -2
