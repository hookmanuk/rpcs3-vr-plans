import numpy as np, sys
L=lambda n: np.fromfile(f'snaps/{n}.bin', np.uint8)
menu=[L(n) for n in sys.argv[1].split(',')]; play=[L(n) for n in sys.argv[2].split(',')]
M=np.stack(menu); P=np.stack(play)
mc=(M==M[0]).all(0); pc=(P==P[0]).all(0)
cand=np.nonzero(mc & pc & (M[0]!=P[0]))[0]
print(len(cand),'bytes')
# group into runs
runs=[]; 
for a in cand:
    if runs and a-runs[-1][1]<=4: runs[-1][1]=a
    else: runs.append([a,a])
for a,b in runs[:80]:
    off=0xe64000+a
    print(hex(off), 'menu', M[0][a:b+1].tobytes().hex(), 'play', P[0][a:b+1].tobytes().hex())
