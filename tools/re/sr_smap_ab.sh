#!/bin/sh
# sr_smap_ab.sh TAG: SEGA Rally shadow-map head-pose test: load vrtest_sr_birds, dump the shadow map (0xc8250000) at
# ~t+6.5 s with the simulator head at yaw 25 (as the control run ctl_y0 at yaw 0), print the differing pixel count.
cd "$(dirname "$0")"
W="$TEMP/rpcs3-vrprofile"; O=/f/rpsc3/source/plans/evidence/segarally/birds
PROBE=${PROBE:-render=1} sh sess.sh start BLUS30068 vrtest_sr_birds >/dev/null
py -3.13 simpose.py 0 0 0 >/dev/null; sleep 1.5; rm -f "$TEMP"/rpcs3-vrprofile/RTDUMP.*c8250000*; printf 'c8250000' > "$W/RTDUMP.tmp" && mv "$W/RTDUMP.tmp" "$W/RTDUMP"; sleep 3
py -3.13 simpose.py ${YAW:-25} 0 0 >/dev/null; sleep 1.5; rm -f "$TEMP"/rpcs3-vrprofile/RTDUMP.*c8250000*; printf 'c8250000' > "$W/RTDUMP.tmp" && mv "$W/RTDUMP.tmp" "$W/RTDUMP"; sleep 3
f=$(ls "$W"/RTDUMP.*c8250000.left | head -1); cp "$f" "$O/v_$1.raw"
py -3.13 simpose.py 0 0 0 >/dev/null; sh sess.sh stop BLUS30068 >/dev/null
py -3.13 - "$O" "$1" <<'PY'
import numpy as np, glob, sys
O,t=sys.argv[1:3]
c=sorted(glob.glob(O+'/ctl_y*.raw'))
cc=[np.fromfile(f,dtype=np.uint8).reshape(2736,2736,4)[...,1].astype(int) for f in c]
v=np.fromfile(O+'/v_%s.raw'%t,dtype=np.uint8).reshape(2736,2736,4)[...,1].astype(int)
print(t, 'diff vs control t1:', min(int(np.sum(np.abs(v-x)>40)) for x in cc))
PY
