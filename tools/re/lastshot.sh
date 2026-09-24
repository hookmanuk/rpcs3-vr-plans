#!/bin/sh
# lastshot.sh OUT: take a SHOT, wait for the (large) png, save a 640px copy to plans/tools/re/OUT.png
W="$TEMP/rpcs3-vrprofile"; S=F:/rpsc3/source/rpcs3/bin/screenshots/${SHOT_ID:-BCUS98259}
before=$(ls -t "$S"/*.png 2>/dev/null | head -1); touch "$W/SHOT"
for i in $(seq 1 60); do sleep 1; n=$(ls -t "$S"/*.png | head -1); [ "$n" != "$before" ] && break; done
sleep 12
py -3.13 -c "
from PIL import Image; im=Image.open(r'$n'); im.resize((640,360)).save(r'F:/rpsc3/source/plans/tools/re/$1.png')"
