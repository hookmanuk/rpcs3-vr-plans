#!/bin/bash
# icovr_flatcmp.sh SECONDS STAGE...: for each stage, the flat game (window capture, DPI aware) and the VR port with
# ICO_VR_TEST_GAMEFOV=1 (both eyes the camera's own picture) after SECONDS from ICO_START_STAGE, side by side in
# flatcmp_<STAGE>.png (eyes folder; the eye squeezed back to 4:3). Same ticks, not the same wall moment: compare the
# look (effects, fog, glow, transparency), not the exact frame.
S=$1; shift
E=/c/Users/matt/AppData/Local/Temp/claude/4d94c0b8726ad438/a2506519-9380-442c-9fe4-e4dd90a66203/scratchpad/eyes
D='C:\Users\matt\AppData\Local\Temp\claude\4d94c0b8726ad438\a2506519-9380-442c-9fe4-e4dd90a66203\scratchpad\eyes'
for st in "$@"; do
    rm -f $E/pid.txt
    powershell.exe -NoProfile -Command "\$id = & F:\rpsc3\source\plans\tools\icovr_sim.ps1 -Flat -Env @{ICO_START_STAGE='$st'}; Start-Sleep $S; & F:\rpsc3\source\plans\tools\icovr_shot.ps1 -ProcId \$id -Title ICO -Out '$D\flat_$st.png' | Out-Null; Stop-Process -Id \$id -Force" </dev/null >/dev/null 2>&1
    rm -f $E/eye_*.png
    bash /f/rpsc3/source/plans/tools/icovr_dump.sh $S 1 ICO_START_STAGE=$st ICO_VR_TEST_GAMEFOV=1 >/dev/null 2>&1
    l=$(ls -t $E/eye_*_L.png 2>/dev/null | head -1)
    [ -n "$l" ] && mv "$l" $E/gamefov_$st.png
    rm -f $E/eye_*.png $E/chain_*.png
    python3 - "$st" <<'PY'
import sys
from PIL import Image
st = sys.argv[1]
E = 'C:/Users/matt/AppData/Local/Temp/claude/4d94c0b8726ad438/a2506519-9380-442c-9fe4-e4dd90a66203/scratchpad/eyes'
try:
    f = Image.open(f'{E}/flat_{st}.png').convert('RGB')
    w, h = f.size
    f = f.crop((0, 40, w, h))  # the title bar off (approximate)
    v = Image.open(f'{E}/gamefov_{st}.png').convert('RGB').resize((640, 480))
    f = f.resize((640, 480))
    o = Image.new('RGB', (1280, 480)); o.paste(f, (0, 0)); o.paste(v, (640, 0)); o.save(f'{E}/flatcmp_{st}.png')
    print(f'stage {st}: flatcmp_{st}.png')
except Exception as e:
    print(f'stage {st}: {e}')
PY
done
