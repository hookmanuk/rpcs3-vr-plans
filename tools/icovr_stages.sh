#!/bin/bash
# icovr_stages.sh SECONDS STAGE...: for each stage, boot the ICO VR port straight into it (ICO_START_STAGE) on the
# simulator, dump one eye pair after SECONDS (stage_<N>_L/R.png in the eyes folder), close it. Extra env: ICOVR_ENV
# ("NAME=VALUE ...").
E=/c/Users/matt/AppData/Local/Temp/claude/4d94c0b8726ad438/a2506519-9380-442c-9fe4-e4dd90a66203/scratchpad/eyes
S=$1; shift
for st in "$@"; do
    rm -f $E/eye_*.png
    /f/rpsc3/source/plans/tools/icovr_dump.sh $S 1 ICO_START_STAGE=$st $ICOVR_ENV >/dev/null 2>&1
    l=$(ls $E/eye_*_L.png 2>/dev/null | head -1); r=$(ls $E/eye_*_R.png 2>/dev/null | head -1)
    [ -n "$l" ] && mv "$l" $E/stage_${st}_L.png && mv "$r" $E/stage_${st}_R.png && echo "stage $st dumped" || echo "stage $st: no dump"
done
