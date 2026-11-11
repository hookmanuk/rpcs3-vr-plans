#!/bin/bash
# icovr_nullvr.sh SECONDS [HZ] [EYE]: the ICO VR port on real SteamVR with its null headset (no headset; a private
# VR_CONFIG_PATH, Matt's settings untouched). Only while Matt is away: it takes the machine's SteamVR. Refuses when a
# SteamVR is already running (his). Boots to gameplay (icovr-walk.txt), runs SECONDS, then closes the game and the
# SteamVR processes it started and deletes the private config. Prints the log's vr: lines.
S=${1:-60}; HZ=${2:-90}; EYE=${3:-2880}
C='H:\ico-pc\out\nullvr_config'
CU=/h/ico-pc/out/nullvr_config
if tasklist | grep -qi "vrserver\|vrcompositor\|vrmonitor"; then
    echo "a SteamVR is already running (Matt's?): not touching it"; exit 1
fi
mkdir -p $CU
cp "/c/Program Files (x86)/Steam/config/chaperone_info.vrchap" $CU/ 2>/dev/null
cat > $CU/steamvr.vrsettings <<EOF
{
  "steamvr": { "activateMultipleDrivers": true, "forcedDriver": "null", "requireHmd": false, "enableHomeApp": false, "showStartupWindow": false, "supersampleScale": 1.0, "supersampleManualOverride": true, "motionSmoothing": false },
  "driver_null": { "enable": true, "loadPriority": 999, "windowX": 0, "windowY": 0, "windowWidth": 1280, "windowHeight": 640, "renderWidth": $EYE, "renderHeight": $EYE, "secondsFromVsyncToPhotons": 0.0111, "displayFrequency": $HZ }
}
EOF
stopvr() {
    powershell.exe -NoProfile -Command "Get-Process | Where-Object { \$_.Path -like '*\\steamapps\\common\\SteamVR\\*' } | ForEach-Object { Stop-Process -Id \$_.Id -Force -ErrorAction SilentlyContinue }"
}
run() {
    powershell.exe -NoProfile -Command "\$id = & F:\\rpsc3\\source\\plans\\tools\\icovr_sim.ps1 -Steam -GameArgs '--pad-script icovr-walk.txt' -Env @{VR_CONFIG_PATH='$C'}; \$id"
}
run > /tmp/icovr_pid.txt # (a file: $(...) would wait for the game, which inherits its pipe)
PID=$(tr -d '\r' < /tmp/icovr_pid.txt)
echo "game $PID"
sleep 20
# a cold SteamVR opens room setup for the null headset, which ends the session: close it, start again
if ! tasklist //FI "PID eq $PID" | grep -q ico_pc; then
    echo "the game exited (room setup?): again"
    powershell.exe -NoProfile -Command "Get-Process steamvr_room_setup -ErrorAction SilentlyContinue | Stop-Process -Force"
    sleep 3
    run > /tmp/icovr_pid.txt
    PID=$(tr -d '\r' < /tmp/icovr_pid.txt)
    echo "game $PID"
fi
sleep $S
grep -a "^vr:" /h/ico-pc/dist/x64/logs/ico-pc.log | tail -12
powershell.exe -NoProfile -Command "Stop-Process -Id $PID -Force -ErrorAction SilentlyContinue"
sleep 2
stopvr
sleep 2
rm -rf $CU
tasklist | grep -i "vrserver\|vrcompositor\|vrmonitor\|ico_pc" || echo "SteamVR and the game closed"
