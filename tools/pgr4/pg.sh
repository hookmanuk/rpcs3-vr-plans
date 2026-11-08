#!/bin/sh
# pg.sh start [NAME=VALUE ...] : PGR4 with the debug server and the test user folder (never Matt's saves).
# pg.sh <regpuctl command>     : one debug command. pg.sh stop : quit, then kill by name.
R=/h/PGR4-ReGPU
export REGPU_GAME=${PGR4_EXE:-H:/PGR4-ReGPU/build/rel/pgr4.exe} REGPU_GAME_ARGS=game REGPU_GAME_CWD=H:/PGR4-ReGPU
export PGR4_USER_DIR=H:/PGR4-ReGPU/out/testuser PGR4_TITLE_UPDATE_DIR=H:/PGR4-ReGPU/out/tu2 PGR4_SKIP_INTRO=1
case "$1" in
start) shift; py -3 -I $R/thirdparty/ReGPU/tools/regpuctl.py start "$@";;
stop) py -3 -I $R/thirdparty/ReGPU/tools/regpuctl.py quit 2>/dev/null; sleep 3
      powershell -NoProfile -Command "Get-Process pgr4 -ErrorAction SilentlyContinue | Where-Object { @('H:\PGR4-ReGPU\build\rel\pgr4.exe', 'H:\PGR4-ReGPU\build\avx2\pgr4.exe') -contains \$_.Path } | Stop-Process -Force";;
*) py -3 -I $R/thirdparty/ReGPU/tools/regpuctl.py "$@";;
esac
