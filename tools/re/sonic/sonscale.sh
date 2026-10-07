#!/bin/sh
# sonscale.sh VALUE TAG: Sonic BLUS30839_1_0 fly-by series with Wider view Scale=VALUE (bin patch default, restored)
S=/f/rpsc3/source/plans/tools/re/sonic
B=/f/rpsc3/source/rpcs3/bin/patches/BLUS30839_patch.yml
cp $B $S/son_patch.run.bak
py -3.13 - "$1" <<'PY'
import sys
p='F:/rpsc3/source/rpcs3/bin/patches/BLUS30839_patch.yml'; s=open(p,'rb').read().decode('utf8')
i=s.index('"Wider view (VR culling)"'); j=s.index('Value: 3.0',i); s=s[:j]+'Value: '+sys.argv[1]+s[j+10:]
open(p,'wb').write(s.encode('utf8'))
PY
cd /f/rpsc3/source/plans/tools/re
sh $S/up.sh BLUS30839 BLUS30839_1_0 >/dev/null
for i in 1 2 3 4 5 6 7 8; do py -3.13 simshot.py son_$2$i 1904 >/dev/null; sleep 1; done
sh $S/down.sh BLUS30839 >/dev/null
cp $S/son_patch.run.bak $B
py -3.13 -c "
from PIL import Image
ims=[Image.open(f'son_$2{i}.png').resize((960,514)) for i in range(1,9)]
s=Image.new('RGB',(1920,514*4))
for k,i in enumerate(ims): s.paste(i,((k%2)*960,(k//2)*514))
s.save('son_$2_sheet.png')"
grep -c "Value: 3.0" $B
