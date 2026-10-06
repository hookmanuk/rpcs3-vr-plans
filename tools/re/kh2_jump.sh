#!/bin/sh
# kh2_jump.sh STATE RATE TAG [PRE_KEYS]: boot bin/savestates/BLUS31460/STATE flat at Vblank RATE (temporary custom config,
# removed after), send PRE_KEYS (e.g. to clear tutorial messages), then jump (Circle) and log Roxas's height
# (0x25e4084, f32) every frame with RPCS3_VR_PEEK. Prints the jump's apex height above the start and its airtime.
state=$1; rate=$2; tag=$3; pre=${4:-}
cd "$(dirname "$0")"
W="$TEMP/rpcs3-vrprofile"
C=/f/rpsc3/source/rpcs3/bin/config/custom_configs/config_BLUS31460.yml
P=/f/rpsc3/source/rpcs3/bin/config/input_configs/BLUS31460
[ -f "$C" ] && { echo "a custom config exists: not touching it"; exit 1; }
padhad=0; [ -d "$P" ] && padhad=1
[ $padhad = 0 ] && { mkdir -p "$P"; cp ../keyboard-pad-template.yml "$P/Default.yml"; }
printf 'Video:\n  Vblank Rate: %s\n' "$rate" > "$C"
printf '25e4084\n' > "$W/peek_jump.txt"
RPCS3_VR_PEEK="$W/peek_jump.txt" RPCS3_VR_PEEK_EVERY=1 powershell -File ../launch.ps1 -Game "F:/rpsc3/source/rpcs3/bin/savestates/BLUS31460/$state.SAVESTAT.zst" -NoHeadset -Probe render=0 | tail -1
sleep 5
[ -n "$pre" ] && { sh keys.sh "$pre"; sleep 8; }
mark=$(grep -ac 'VR peek' /f/rpsc3/source/rpcs3/bin/log/RPCS3.log)
sh keys.sh 'C 300 100\n'
sleep 4
powershell -c "Get-Process rpcs3 -ErrorAction SilentlyContinue | Stop-Process -Force; \$t=0; while ((Get-Process rpcs3 -ErrorAction SilentlyContinue | Where-Object { \$_.Threads.Count -gt 1 }) -and \$t -lt 150) { Start-Sleep -Milliseconds 200; \$t++ }"
rm -f "$C"; [ -f "$C" ] && echo "WARNING: temporary $C still present"
[ $padhad = 0 ] && rm -r "${P:?}"
grep -a 'VR peek' /f/rpsc3/source/rpcs3/bin/log/RPCS3.log | tail -n +$((mark + 1)) | py -3.13 -c "
import sys, re, struct
pts = []
for line in sys.stdin:
    m = re.search(r't=([\d.]+).* 25e4084=([0-9a-f]{8})', line)
    if m: pts.append((float(m.group(1)), struct.unpack('>f', bytes.fromhex(m.group(2)))[0]))
if not pts: sys.exit('no samples')
y0 = pts[0][1]
dev = [(t, y - y0) for t, y in pts]
peak = max(dev, key=lambda p: abs(p[1]))
air = [t for t, d in dev if abs(d) > 1.0]
print('$tag: %d frames, ground y %.1f, apex %+.1f at %.3f s, airtime %.3f s' % (len(pts), y0, peak[1], peak[0] - pts[0][0], (air[-1] - air[0]) if air else 0))
"
