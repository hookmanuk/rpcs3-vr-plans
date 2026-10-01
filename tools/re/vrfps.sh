#!/bin/sh
# vrfps.sh ID STATE VBLANK [SAMPLES] [PROBE]: stereo FPS from bin/savestates/ID/STATE.SAVESTAT.zst at a vblank rate
# (probe default render=1). Prints min / avg of the title FPS over SAMPLES seconds after a 14 s settle. The game's
# custom config is restored afterwards (only its Vblank Rate is changed for the run).
C=/f/rpsc3/source/rpcs3/bin/config/custom_configs/config_$1.yml
had=0; [ -f "$C" ] && { had=1; cp "$C" "$C.vrfps.bak"; }
py -3.13 - "$C" "$3" <<'PY'
import sys, os, re
p, v = sys.argv[1], sys.argv[2]
s = open(p, encoding='utf8').read() if os.path.exists(p) else ''
if re.search(r'^  Vblank Rate:.*$', s, re.M): s = re.sub(r'^  Vblank Rate:.*$', '  Vblank Rate: ' + v, s, flags=re.M)
elif re.search(r'^Video:\s*$', s, re.M): s = re.sub(r'^Video:\s*$', 'Video:\n  Vblank Rate: ' + v, s, count=1, flags=re.M)
else: s = s + ('' if s.endswith('\n') or not s else '\n') + 'Video:\n  Vblank Rate: ' + v + '\n'
open(p, 'w', encoding='utf8', newline='\n').write(s)
PY
powershell -File gboot.ps1 -Iso "F:/rpsc3/source/rpcs3/bin/savestates/$1/$2.SAVESTAT.zst" -Probe "${5:-render=1}" >/dev/null
sleep 14
vals=$(powershell -File fps.ps1 -N ${4:-8} | grep -o "[0-9][0-9.]*")
echo "$1 $2 vblank $3: $(echo $vals | tr ' ' '\n' | awk '{s+=$1; if(min==""||$1<min)min=$1} END{printf "min %.1f avg %.1f", min, s/NR}')"
if [ $had = 1 ]; then mv -f "$C.vrfps.bak" "$C"; else rm -f "$C"; fi
