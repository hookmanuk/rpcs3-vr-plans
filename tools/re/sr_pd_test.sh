#!/bin/sh
# sr_pd_test.sh TAG: SEGA Rally head-pose test of the shadow map: in one run of vrtest_sr_birds, dump 0xc8250000 just
# before the first road draw (prog=1965d57fee836671) at pitch -15, -20, -15, -20 and print the differing pixel counts
# against the first dump (pose-independent: all similar and small; the 2026-10-08 bug: ~160k at -20, ~3k at -15).
cd "$(dirname "$0")"
W="$TEMP/rpcs3-vrprofile"; O=/f/rpsc3/source/plans/evidence/segarally/birds
sh sess.sh start BLUS30068 vrtest_sr_birds >/dev/null
for i in 1 2 3 4; do
  p=$([ $((i%2)) = 1 ] && echo -15 || echo -20)
  py -3.13 simpose.py 0 $p 0 >/dev/null; sleep 0.6
  rm -f "$TEMP"/rpcs3-vrprofile/RTDUMP.*c8250000*
  printf 'prog=1965d57fee836671\nc8250000\n' > "$W/RTDUMP.tmp" && mv "$W/RTDUMP.tmp" "$W/RTDUMP"; sleep 1.5
  f=$(ls "$W"/RTDUMP.*c8250000.left 2>/dev/null | head -1); [ -n "$f" ] && cp "$f" "$O/t_$1_$i.raw"
done
py -3.13 simpose.py 0 0 0 >/dev/null; sh sess.sh stop BLUS30068 >/dev/null
py -3.13 - "$O" "$1" <<'PY'
import numpy as np, sys
O,t=sys.argv[1:3]
ims=[np.fromfile('%s/t_%s_%d.raw'%(O,t,i),dtype=np.uint8).reshape(2736,2736,4)[...,1].astype(int) for i in range(1,5)]
print(t, 'vs -20:', [int(np.sum(np.abs(ims[0]-ims[i])>40)) for i in (1,3)], 'vs -15:', int(np.sum(np.abs(ims[0]-ims[2])>40)))
PY
rm -f "$O"/t_"$1"_*.raw
