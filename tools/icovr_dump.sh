#!/bin/bash
# icovr_dump.sh SECONDS COUNT [ENV=VALUE ...] (ICOVR_ARGS: the game's arguments, e.g. '--pad-script icovr-gameplay.txt'): boot the ICO VR port on the simulator, after SECONDS dump COUNT eye pairs
# into the scratch eyes folder ($ICOVR_EYES, default below), stop the game. Prints the files.
D="${ICOVR_EYES:-C:\Users\matt\AppData\Local\Temp\claude\4d94c0b8726ad438\a2506519-9380-442c-9fe4-e4dd90a66203\scratchpad\eyes}"
S=$1; N=$2; shift 2
ENVS="ICO_VR_DUMP_DIR='$D'"
for kv in "$@"; do ENVS="$ENVS; ${kv%%=*}='${kv#*=}'"; done
powershell.exe -NoProfile -Command "\$id = & F:\rpsc3\source\plans\tools\icovr_sim.ps1 -Env @{$ENVS} -GameArgs '${ICOVR_ARGS:-}'; Start-Sleep $S; Set-Content -Path '$D\dump' -Value '$N' -Encoding ascii; Start-Sleep 6; Stop-Process -Id \$id -Force"
ls "$(cygpath "$D")" | tail -$((N*2))
