"""ppcfn.py ADDR [ADDR...]: the PowerPC of the recompiled function holding that address (out/ppc comments only), with calls named."""
import glob, re, sys
files = sorted(glob.glob('H:/PGR4-ReGPU/out/ppc/ppc_recomp.*.cpp'))
for want in sys.argv[1:]:
    want = int(want, 16)
    best = None
    for f in files:
        for m in re.finditer(r'PPC_FUNC_IMPL\(__imp__sub_([0-9A-F]{8})\)', open(f, errors='replace').read()):
            a = int(m.group(1), 16)
            if a <= want and (best is None or a > best[0]):
                best = (a, f, m.start())
    a, f, at = best
    s = open(f, errors='replace').read()
    e = s.find('\n}\n', at)
    print('=== sub_%08X (%s for %08X)' % (a, f[-10:], want))
    for line in s[at:e].split('\n'):
        t = line.strip()
        if t.startswith('//'):
            print('  ' + t[3:])
        elif t.startswith('loc_'):
            print(t)
        elif t.startswith('sub_') or '__imp__' in t and 'PPC_FUNC' not in t:
            print('    -> ' + t)
