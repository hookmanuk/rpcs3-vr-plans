#!/bin/sh
# vr1pct.sh ID STATE VBLANK [WALK=1]: frame-time stats (fork hook RPCS3_VR_FRAMESTATS) from
# bin/savestates/ID/STATE.SAVESTAT.zst at a fixed Vblank rate, with a headset session on the OpenXR Simulator (gboot.ps1;
# VR Enabled and Frame Rate Unlimited for the run, so the Vblank Rate paces the game; audio Null so a locked desktop
# cannot stop it). Env DESKTOP=1: the old desktop-only stereo instead.
# Env PROBE = probe options (default render=1; render=0 measures flat), SCALE = resolution scale % (default 300), SETTLE = seconds before measuring (default 10), VIDEO_EXTRA = more Video
# settings for the run, "Key=value;Key=value" (e.g. "Relaxed ZCULL Sync=true").
# Only Vblank Rate and Resolution Scale are merged into the game's custom config for the run (other settings kept;
# the file is restored after). Walks back and forth ~25 s with a temporary keyboard pad (WALK=1), holds one pad key
# for 25 s instead (WALK=<key>, e.g. W = R2 to accelerate in a racing game), plays vrtest_boot/STATE.walk (an
# RPCS3_VR_KEYS script) from the boot on (WALK=script: Super Stardust HD fires in circles to stay alive) or sends
# nothing (WALK=0); prints the 8 s windows that start after the settle (load and warm-up excluded) and a summary: median avg FPS, 1% low and
# late (missed) frames = frames longer than 1.5x the median frame time. Screenshots: shot.py's p1_STATE_VBLANK (desktop
# side by side) and simshot.py's sim_STATE_VBLANK (what the simulator composited for the headset).
# Games that cannot savestate: if vrtest_boot/STATE.keys exists, the disc from games.yml is booted instead and that
# RPCS3_VR_KEYS script is played from the start (it drives the menus; SETTLE must cover them).
C=/f/rpsc3/source/rpcs3/bin/config/custom_configs/config_$1.yml
had=0; [ -f "$C" ] && { had=1; cp "$C" "$C.vr1pct.bak"; }
py -3.13 - "$C" "$3" "${SCALE:-300}" "${VIDEO_EXTRA:-}" "${DESKTOP:-0}" <<'PY'
import sys, os, re
p, vblank, scale, extra, desktop = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5] == '1'
s = open(p, encoding='utf8').read() if os.path.exists(p) else ''
if not re.search(r'^Video:\s*$', s, re.M):
    s = s + ('' if s.endswith('\n') or not s else '\n') + 'Video:\n'
pairs = [('Vblank Rate', vblank), ('Resolution Scale', scale)] + [tuple(x.split('=', 1)) for x in extra.split(';') if '=' in x]
for key, val in pairs:
    if re.search(r'^  %s:.*$' % key, s, re.M):
        s = re.sub(r'^  %s:.*$' % key, '  %s: %s' % (key, val), s, flags=re.M)
    else:
        s = re.sub(r'^Video:\s*$', 'Video:\n  %s: %s' % (key, val), s, count=1, flags=re.M)
def nested(section, sub, key, val):
    # "Section:" / "  Sub:" / "    Key: val" (sub None: "  Key: val" directly under the section)
    global s
    if not re.search(r'^%s:\s*$' % section, s, re.M):
        s = s + ('' if s.endswith('\n') or not s else '\n') + section + ':\n'
    start = re.search(r'^%s:\s*$' % section, s, re.M).end()
    end_m = re.search(r'^\S', s[start + 1:], re.M); end = start + 1 + end_m.start() if end_m else len(s)
    body = s[start:end]
    if sub:
        if not re.search(r'^  %s:\s*$' % sub, body, re.M):
            body = '\n  %s:' % sub + body if body.startswith('\n') else '\n  %s:\n' % sub + body
        bs = re.search(r'^  %s:\s*$' % sub, body, re.M).end()
        be_m = re.search(r'^  \S', body[bs + 1:], re.M); be = bs + 1 + be_m.start() if be_m else len(body)
        sb = body[bs:be]
        if re.search(r'^    %s:.*$' % re.escape(key), sb, re.M):
            sb = re.sub(r'^    %s:.*$' % re.escape(key), '    %s: %s' % (key, val), sb, flags=re.M)
        else:
            sb = '\n    %s: %s' % (key, val) + sb
        body = body[:bs] + sb + body[be:]
    else:
        if re.search(r'^  %s:.*$' % re.escape(key), body, re.M):
            body = re.sub(r'^  %s:.*$' % re.escape(key), '  %s: %s' % (key, val), body, flags=re.M)
        else:
            body = '\n  %s: %s' % (key, val) + body
    s = s[:start] + body + s[end:]
if not desktop:
    nested('Video', 'VR', 'Enabled', 'true')
    nested('Video', 'VR', 'Frame Rate', 'Unlimited')
    nested('Audio', None, 'Renderer', '"Null"')
open(p, 'w', encoding='utf8', newline='\n').write(s)
PY
P=/f/rpsc3/source/rpcs3/bin/config/input_configs/$1; padhad=0; [ -d "$P" ] && padhad=1
KS=/f/rpsc3/source/plans/tools/re/vrtest_boot/$2.keys; pad=0; { [ "${4:-1}" != 0 ] || [ -f "$KS" ]; } && pad=1
if [ $padhad = 0 ] && [ $pad = 1 ]; then mkdir -p "$P"; cp /f/rpsc3/source/plans/tools/keyboard-pad-template.yml "$P/Default.yml"; fi
GB=; [ "${DESKTOP:-0}" = 1 ] && GB=-Desktop
SIMD="$LOCALAPPDATA/OpenXR-Simulator"
[ -z "$GB" ] && printf '{"x": 0, "y": 0, "z": 0, "yaw": 0, "pitch": 0, "roll": 0}' > "$SIMD/head_pose_command.json"
if [ -f "$KS" ]; then
  G=$(grep -a "^$1:" /f/rpsc3/source/rpcs3/bin/config/games.yml | sed -E 's/^[^:]+: *//; s/^"//; s/"\s*$//')
  RPCS3_VR_FRAMESTATS=8 powershell -File gboot.ps1 -Iso "$G" -Probe "${PROBE:-render=1}" $GB >/dev/null
  W="$TEMP/rpcs3-vrprofile"; grep -v '^#' "$KS" > "$W/KEYS.tmp" && mv -f "$W/KEYS.tmp" "$W/KEYS"
else
  RPCS3_VR_FRAMESTATS=8 powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/$1/$2.SAVESTAT.zst" -Probe "${PROBE:-render=1}" $GB >/dev/null
fi
if [ "${4:-1}" = script ]; then
  W="$TEMP/rpcs3-vrprofile"; grep -v '^#' "/f/rpsc3/source/plans/tools/re/vrtest_boot/$2.walk" > "$W/KEYS.tmp" && mv -f "$W/KEYS.tmp" "$W/KEYS"
fi
sleep "${SETTLE:-10}"
[ -z "$GB" ] && powershell -File simwin.ps1 >/dev/null 2>&1
L=/f/rpsc3/source/rpcs3/bin/log/RPCS3.log
n0=$(grep -ac "VR frame stats" $L)
if [ "${4:-1}" = 1 ]; then
  sh keys.sh 'I 1500 50\nK 1500 50\nI 1500 50\nK 1500 50\nI 1500 50\nK 1500 50\nI 1500 50\nK 1500 50\nI 1500 50\nK 1500 50\nI 1500 50\nK 1500 50\nI 1500 50\nK 1500 50\nI 1500 50\nK 1500 50\n'
elif [ "${4:-1}" != 0 ] && [ "${4:-1}" != script ]; then
  sh keys.sh "$4 25000 50\n"
fi
sleep 26
SHOT_MOVE=1 py -3.13 shot.py "$1" "p1_$2_$3" 480 >/dev/null
[ -z "$GB" ] && py -3.13 simshot.py "sim_$2_$3" 960 >/dev/null 2>&1
# Windows that start after the settle: skip the one under way when measuring began.
lines=$(grep -a "VR frame stats" $L | tail -n +$((n0 + 2)) | sed -E 's/.*VR frame stats: //' | head -3)
echo "$1 $2 vblank $3 scale ${SCALE:-300}%:"; echo "$lines" | sed 's/^/   /'
med() { sort -n | awk '{a[NR]=$1} END{if(NR) printf "%s", a[int((NR+1)/2)]}'; }
low=$(echo "$lines" | grep -o "FPS, 1% low [0-9.]*" | grep -o "[0-9.]*$" | med)
late=$(echo "$lines" | grep -o "late [0-9.]*%" | grep -o "[0-9.]*" | med)
avg=$(echo "$lines" | grep -o "avg [0-9.]* FPS" | grep -o "[0-9.]*" | med)
rsx=$(echo "$lines" | grep -o "RSX thread [0-9.]* ms" | grep -o "[0-9.]* ms" | grep -o "[0-9.]*" | med)
n=$(echo "$lines" | grep -c "frames over")
if [ -n "$low" ]; then echo "   => median of $n windows: avg $avg FPS, 1% low $low, late frames $late%${rsx:+, RSX thread $rsx ms/frame}"; else echo "   => no frame stats (did not run)"; fi
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; while (Get-Process rpcs3 -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 200 }"
if [ $had = 1 ]; then mv -f "$C.vr1pct.bak" "$C"; else rm -f "$C"; fi
[ $had = 0 ] && [ -f "$C" ] && echo "   WARNING: temporary $C still present"
[ $padhad = 0 ] && [ $pad = 1 ] && rm -r "${P:?}"
true
