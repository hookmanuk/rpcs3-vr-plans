"""menudiff.py snap NAME [BASE=0xb700000] [SIZE=0x1c00000] | menudiff.py find PLAY,... MENU,... [BASE]
snap: the running game's image (bb-probe.exe, guest image at BASE) as u32s to H:/uc_tests/snap_NAME.npy (unreadable
pages zero). find: the dwords that read 0 in every PLAY snapshot and one same small non-zero value in every MENU one
(a menu state as U2's +0xf2f364: 0 in play, 12 open), printed as image offsets with their values."""
import sys
import numpy as np

sys.path.insert(0, r'H:\uncharted_pc\tools\vr')
cmd = sys.argv[1]
if cmd == 'snap':
    import memscan
    name = sys.argv[2]
    base = int(sys.argv[3], 16) if len(sys.argv) > 3 else 0xb700000
    size = int(sys.argv[4], 16) if len(sys.argv) > 4 else 0x1c00000
    out = np.zeros(size // 4, np.uint32)
    step = 0x10000
    for off in range(0, size, step):
        data = memscan.read(base + off, step)
        if len(data) == step:
            out[off // 4:(off + step) // 4] = np.frombuffer(data, np.uint32)
    np.save(f'H:/uc_tests/snap_{name}.npy', out)
    print(f'snap {name}: {np.count_nonzero(out)} non-zero dwords')
elif cmd == 'find':
    plays = [np.load(f'H:/uc_tests/snap_{n}.npy') for n in sys.argv[2].split(',')]
    menus = [np.load(f'H:/uc_tests/snap_{n}.npy') for n in sys.argv[3].split(',')]
    ok = np.ones(plays[0].shape, bool)
    for p in plays:
        ok &= p == 0
    first = menus[0]
    ok &= (first != 0) & (first < 64)
    for m in menus[1:]:
        ok &= m == first
    idx = np.nonzero(ok)[0]
    print(f'{len(idx)} candidates')
    for i in idx[:80]:
        print(f'  +{i * 4:#x}: {int(first[i])}')
