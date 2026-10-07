#!/bin/sh
# sonmask.sh TAG [STATE] [POSE]: two-draw, unpause, optional simpose, dump both eyes' shadow mask; sheet flat|left|right -> TAG.png
S=/f/rpsc3/source/plans/tools/re/sonic
cd /f/rpsc3/source/plans/tools/re; W="$TEMP/rpcs3-vrprofile"
RPCS3_VR_MULTIVIEW=0 timeout 150 sh $S/up.sh BLUS30839 ${2:-BLUS30839_1_2} >/dev/null; sleep 2
[ -n "$3" ] && py -3.13 $S/pose.py $3
sh keys.sh 'Return 150\n'; sleep 1.5
rm -f "$W"/RTDUMP.*; printf 'c1d38000\nc1270000\n' > "$W/RTDUMP.tmp"; mv -f "$W/RTDUMP.tmp" "$W/RTDUMP"; until [ ! -f "$W/RTDUMP" ]; do sleep 0.2; done; sleep 2
rm -f $1_c*; py -3.13 rtdump2png.py "$W/RTDUMP.0." $1 >/dev/null 2>&1
py -3.13 $S/pose.py 0 0 0; sh $S/down.sh BLUS30839 >/dev/null
py -3.13 -c "
from PIL import Image
s=Image.new('RGB',(1920,720))
s.paste(Image.open('s12f_c1270000_left.png').convert('RGB').resize((640,360)),(0,0))
s.paste(Image.open('s12f_c1d38000_left.png').convert('RGB').resize((640,360)),(0,360))
for k,e in enumerate(('left','right')):
    s.paste(Image.open('$1_c1270000_%s.png' % e).convert('RGB').resize((640,360)),(640+k*640,0))
    s.paste(Image.open('$1_c1d38000_%s.png' % e).convert('RGB').resize((640,360)),(640+k*640,360))
s.save('$1.png')"
