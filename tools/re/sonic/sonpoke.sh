#!/bin/sh
# sonpoke.sh TAG "POKELINES": Matt's Sonic fly-by state, poke lines right after load, 8 shots 1 s apart
S=/f/rpsc3/source/plans/tools/re/sonic
cd /f/rpsc3/source/plans/tools/re
CFGX="${CFGX:-}" sh $S/up.sh BLUS30839 BLUS30839_1_0 >/dev/null
W="$TEMP/rpcs3-vrprofile"
[ -n "$2" ] && { printf "$2" > $W/POKE.tmp; mv -f $W/POKE.tmp $W/POKE; }
for i in 1 2 3 4 5 6 7 8; do py -3.13 simshot.py son_$1$i 1904 >/dev/null; sleep ${GAP:-1}; done
grep -a "VR poke" /f/rpsc3/source/rpcs3/bin/log/RPCS3.log | head -6 | cut -c40-160
sh $S/down.sh BLUS30839 >/dev/null
py -3.13 -c "
from PIL import Image
ims=[Image.open(f'son_$1{i}.png').resize((960,514)) for i in range(1,9)]
s=Image.new('RGB',(1920,514*4))
for k,i in enumerate(ims): s.paste(i,((k%2)*960,(k//2)*514))
s.save('son_$1_sheet.png')"
