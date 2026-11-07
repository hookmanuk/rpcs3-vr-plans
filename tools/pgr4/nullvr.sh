#!/bin/sh
# nullvr.sh [HZ] [RENDER_EYE] [NAME=VALUE...]: PGR4 on real SteamVR with its null headset (no headset needed: pacing and frame rate through the real
# compositor). A private config folder (VR_CONFIG_PATH): Matt's Steam settings are not touched. NO_RACE=1 stops at the title screen.
# The game's log goes to out/exit_out.txt (regpuctl start did not survive here: started directly by exitcode.py).
# nullvr.sh stop: closes the game and the SteamVR processes, by path under SteamVR.
P=/f/rpsc3/source/plans/tools/pgr4/pg.sh
T=/f/rpsc3/source/plans/tools/pgr4
C=H:/PGR4-ReGPU/out/nullvr_config
stopvr() {
    powershell -NoProfile -Command "Get-Process | Where-Object { \$_.Path -like '*\\steamapps\\common\\SteamVR\\*' } | ForEach-Object { Stop-Process -Id \$_.Id -Force -ErrorAction SilentlyContinue }"
}
if [ "$1" = stop ]; then
    $P stop >/dev/null 2>&1
    stopvr
    exit 0
fi
HZ=${1:-90}; EYE=${2:-5120}; [ $# -gt 0 ] && shift; [ $# -gt 0 ] && shift
$P stop >/dev/null 2>&1
stopvr
sleep 2
mkdir -p $C
cp "/c/Program Files (x86)/Steam/config/chaperone_info.vrchap" $C/ 2>/dev/null
cat > $C/steamvr.vrsettings <<EOF
{
  "steamvr": { "activateMultipleDrivers": true, "forcedDriver": "null", "requireHmd": false, "enableHomeApp": false, "showStartupWindow": false, "supersampleScale": 1.0, "supersampleManualOverride": true, "motionSmoothing": false },
  "driver_null": { "enable": true, "loadPriority": 999, "windowX": 0, "windowY": 0, "windowWidth": 1280, "windowHeight": 640, "renderWidth": $EYE, "renderHeight": $EYE, "secondsFromVsyncToPhotons": 0.0111, "displayFrequency": $HZ }
}
EOF
# A cold SteamVR opens room setup for the null headset, which ends the OpenXR session (the game exits): let that happen, close it, start again.
R=$(py -3 -I $T/exitcode.py 25 PGR4_VR=1 REGPU_VR_EYE=${EYE}x${EYE} "VR_CONFIG_PATH=H:\\PGR4-ReGPU\\out\\nullvr_config" "XR_RUNTIME_JSON=C:\\Program Files (x86)\\Steam\\steamapps\\common\\SteamVR\\steamxr_win64.json" "$@" | head -1)
echo "$R"
case "$R" in
exited*)
    powershell -NoProfile -Command "Get-Process steamvr_room_setup -ErrorAction SilentlyContinue | Stop-Process -Force"
    sleep 2
    py -3 -I $T/exitcode.py 3 PGR4_VR=1 REGPU_VR_EYE=${EYE}x${EYE} "VR_CONFIG_PATH=H:\\PGR4-ReGPU\\out\\nullvr_config" "XR_RUNTIME_JSON=C:\\Program Files (x86)\\Steam\\steamapps\\common\\SteamVR\\steamxr_win64.json" "$@" | head -1;;
esac
for i in $(seq 1 60); do
    f=$($P status 2>/dev/null | sed -E 's/.*"frame": ([0-9]+).*/\1/')
    [ "${f:-0}" -gt 1500 ] 2>/dev/null && break
    sleep 5
done
[ -n "$NO_RACE" ] && exit 0
step() { $P press "$1" >/dev/null; $P wait "$2" >/dev/null; }
step START 5s; step A 5s; step A 4s; step A 4s; step A 4s; step A 4s; step A 4s; step A 6s; step A 15s; step A 12s
$P status | cut -c1-120
