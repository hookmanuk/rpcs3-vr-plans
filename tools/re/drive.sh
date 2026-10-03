# drive.sh ID STATE TAG "STEP;STEP;..." [SETTLE]: scripted play from a savestate, the flat game against the headset.
# A temporary keyboard pad and custom config (VR on, Null audio). For the stereo run (OpenXR Simulator) and the flat
# run (render=0): boot the state, then per step send its keys and take a desktop shot (plus a simulator capture in
# stereo). STEP = name=keys: keys.sh lines joined by a backslash-n, e.g. V 600 2000; I+C 900 holds both keys;
# name=- only shoots.
# Env MODES="stereo flat" (default; either alone), OUT=<dir> (default tools/re/drive_TAG). Refuses to run over an
# existing custom config or pad for the title and removes its own on exit. Grid: drivegrid.py OUT STEP,STEP.
# KEEPCFG=1: use the title's own custom config unchanged (it must have VR enabled) instead of a temporary one.
# Stereo and flat runs drift apart in cutscenes (different boot timing): compare steps taken in gameplay.
id=$1; st=$2; tag=$3; steps=$4; settle=${5:-15}
OUT=${OUT:-/f/rpsc3/source/plans/tools/re/drive_$3}
B=/f/rpsc3/source/rpcs3/bin; CF=$B/config; C=$CF/custom_configs/config_$id.yml; P=$CF/input_configs/$id; D="$LOCALAPPDATA/OpenXR-Simulator"; O=$OUT
mkdir -p $O; cd /f/rpsc3/source/plans/tools/re
kill_rpcs3() { powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; while (Get-Process rpcs3 -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 200 }"; }
[ "${KEEPCFG:-0}" = 1 ] && [ ! -f "$C" ] && { echo "KEEPCFG=1 but no custom config for $id"; exit 1; }
[ "${KEEPCFG:-0}" != 1 ] && [ -f "$C" ] && { echo "custom config exists for $id: not touching it"; exit 1; }
[ -d "$P" ] && { echo "input config exists for $id: not touching it"; exit 1; }
cleanup() { kill_rpcs3; [ "${KEEPCFG:-0}" != 1 ] && rm -f "$C"; rm -rf "$P"; [ -d "$P" ] && echo "WARNING: temp pad left"; }
trap cleanup EXIT
mkdir -p "$P" && cp /f/rpsc3/source/plans/tools/keyboard-pad-template.yml "$P/Default.yml"
[ "${KEEPCFG:-0}" != 1 ] && printf 'Audio:\n  Renderer: "Null"\nVideo:\n  VR:\n    Enabled: true\n' > "$C"
for mode in ${MODES:-stereo flat}; do
  kill_rpcs3
  printf '{"x": 0, "y": 0, "z": 0, "yaw": 0, "pitch": 0, "roll": 0}' > "$D/head_pose_command.json"
  probe=render=1; [ $mode = flat ] && probe=render=0
  powershell -File simboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/$id/$st.SAVESTAT.zst" -Probe $probe | tail -1 | cut -c1-60
  sleep "$settle"; powershell -File simwin.ps1 >/dev/null 2>&1; sleep 1
  IFS=';'; set -f
  for step in $steps; do
    name=${step%%=*}; k=${step#*=}
    if [ "$k" != "-" ]; then sh keys.sh "$k"; tot=$(printf "$k" | awk '{s+=$2+$3} END {print int(s/1000)+2}'); sleep $tot; fi
    rm -f "khd_$tag.full.png"; SHOT_MOVE=1 py -3.13 shot.py "$id" "khd_$tag" 1920 >/dev/null 2>&1
    [ -f "khd_$tag.full.png" ] && mv -f "khd_$tag.full.png" "$O/${mode}_$name.png"; rm -f "khd_$tag.png"
    [ $mode = stereo ] && py -3.13 simshot.py "khs_$tag" 960 >/dev/null 2>&1 && mv -f "khs_$tag.full.png" "$O/sim_$name.png" && rm -f "khs_$tag.png"
    echo "$mode $name: $(powershell -c "(Get-Process rpcs3 -ErrorAction SilentlyContinue).MainWindowTitle" | cut -c1-24)"
  done
  unset IFS; set +f
done
cp $B/log/RPCS3.log $O/last.log
ls $O
