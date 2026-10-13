#!/bin/sh
# gt5_dump3.sh RATE LABEL: GT5 busy race, Frame Rate RATE, 100%, DLSS/FG off, Null audio; resume (X); three guest memory dumps
# ~2 s apart -> $OUT_DIR/dumps/LABEL.0/.1/.2 (.bin .idx .txt). Compare runs with posspeed.py (object speeds) and rateratio.py.
r=$1; label=$2
S=${OUT_DIR:-/c/Users/matt/AppData/Local/Temp/rpcs3-dumps}; mkdir -p $S/dumps
W="$TEMP/rpcs3-vrprofile"
cd /f/rpsc3/source/plans/tools/re || exit 1
rm -f "$W"/g_dump.*
EXTRA="\"Video/VR/Frame Rate=$r\" \"Video/VR/DLSS Frame Generation (experimental)=false\" \"Video/VR/DLSS (experimental)=Off\"" sh sess.sh start BCUS98114 gt5_busy_race_2_17 100 >/dev/null
sleep 3; ./keys.sh 'X 150 50'; sleep 3
for n in 0 1 2; do b=$(sh dumpnow.sh g_dump); for x in bin idx txt; do mv "$b.$x" $S/dumps/$label.$n.$x; done; sleep 2; done
cp /f/rpsc3/source/rpcs3/bin/log/RPCS3.log $S/dumps/$label.log
sh sess.sh stop BCUS98114 >/dev/null
