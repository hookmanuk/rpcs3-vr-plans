#!/usr/bin/env bash
# sess.sh: U2 VR session on the simulator from a copy of Matt's saves (H:/uc_tests/u2user; main menu -> Continue), eye ${EYE:-3584}. ROUTE= drive.py steps, HOLD= seconds.
S=$(dirname "$0")
printf '{"x":0,"y":0,"z":0,"yaw":0,"pitch":0,"roll":0}' > "$LOCALAPPDATA/OpenXR-Simulator/head_pose_command.json"
cd /h/uncharted_pc
G=${GAME:-u2}; EYE=${EYE:-3584}
# GAME=u1: a copy of Matt's U1 jungle save (H:/uc_tests/u1user); u2: his U2 cliff save (u2user).
export DRIVE_USER="H:\\uc_tests\\${G}user"
case $G in u1) EXE=eboot.bin;; u3) EXE=big3-ps4_Shipping.elf;; *) EXE=big2-ps4_Shipping.elf;; esac
export BB_VELOCITY_PS=f4b18264 BB_UPSCALE_BEFORE_CS=aec539f0 BB_HUDLESS_PS=484cdbf5 BB_JITTER_PS=f614041e,b2a42acf,1a08df2d BB_OFFLINE_NPID=1 BB_FRAME_STATS=1 BB_VR_STEREO=mv BB_VBLANK_HZ=240 BB_FRAME_GEN=off BB_UPSCALER=off BB_UPSCALE_PRESET=0 BB_PRESENT_MODE=Mailbox
export BB_VR_HEAD_AIM=1 BB_VR_LOCK_VERTICAL=always
export BB_VR=1 XRFG_DISABLE_OFXR_BRIDGE=1 ${SESSION_ENV}
# RUNTIME=steamvr: the system runtime (SteamVR, Matt's headset); otherwise the OpenXR Simulator.
[ "$RUNTIME" = steamvr ] || export XR_RUNTIME_JSON='F:\rpsc3\source\OpenXR-Simulator\bin\openxr_simulator.json'
(sleep 25; powershell -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$S/simwin.ps1")" >/dev/null 2>&1) &
python scripts/vr_resolution.py out/try/$G $EXE $EYE >/dev/null
export DRIVE_PATCHES="$(cygpath -w $PWD/out/try/$G/vr_patches.bin)" BB_VR_RENDER_SIZE=${EYE}x${EYE} BB_VR_EYE_RES=$EYE BB_DMEM_MB=$(cat out/try/$G/vr_patches.dmem 2>/dev/null || echo 5056)
exec python tools/drive.py $G "${ROUTE:-wait 50; shot menu0; wait 5; shot menu1}; wait ${HOLD:-1200}" 'H:\ROMs\uncharted\CUSA02343'
