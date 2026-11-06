#!/usr/bin/env bash
# borun_vp.sh NAME [args]: Burnout (Xerenge) in VR on the OpenXR simulator (72 Hz unless SIMXR_HZ), plume; the log in this
# folder (NAME.log), LIMIT seconds. Recreated 2026-11-06.
S=/c/Users/matt/AppData/Local/Temp/claude/f--rpsc3-source/4ada4739-f604-4e4a-99d4-1521d85f84f7/scratchpad/bo
N=$1; shift
python /f/rpsc3/source/plans/tools/re/simpose.py 0 0 0 > /dev/null
cd /h/Xerenge/rexglue
GAME=$(sed -n 's/^game_root *= *"\(.*\)"/\1/p' burnout_manifest.toml | head -1)
export PATH="$(pwd)/build:/h/Xerenge/rexglue-sdk/out/win-amd64:$PATH"
export XERENGE_VR_RENDERER=plume XERENGE_SKIP_LOGOS=1 SIMXR_HZ=${SIMXR_HZ:-72}
export XR_RUNTIME_JSON='F:\rpsc3\source\OpenXR-Simulator\bin\openxr_simulator.json' XRFG_DISABLE_OFXR_BRIDGE=1
export MCLA_VR_EYE_SHOT=$(cygpath -w $S/eyeshot.bmp)
export MCLA_PAD_FILE=$(cygpath -w $S/pad.txt); : > $S/pad.txt
timeout ${LIMIT:-120} ./build/burnout.exe --no-fullscreen --game_data_root "$GAME" --gpu_plugin plume \
  --no-vulkan_async_skip_incomplete_frames --log_level info --log_file "$(cygpath -w $S/$N.log)" \
  --vr=true "$@" > $S/$N.out 2>&1
