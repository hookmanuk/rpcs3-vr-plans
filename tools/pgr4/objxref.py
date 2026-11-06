"""objxref.py ADDR...: functions in the recompiled code that form a static guest address or read a value from it (+32):
lis rX,hi with addi/lwz/lbz/lfs offset lo or lo+32 nearby."""
import glob, re, sys
sources = [(p, open(p, errors='ignore').read()) for p in glob.glob('H:/PGR4-ReGPU/out/ppc/ppc_recomp.*.cpp')]
for arg in sys.argv[1:]:
    addr = int(arg, 16)
    found = {}
    for a in (addr, addr + 32):
        lo = a & 0xFFFF
        hi = (a >> 16) + (1 if lo >= 0x8000 else 0)
        if lo >= 0x8000:
            lo -= 0x10000
        if hi >= 0x8000:
            hi -= 0x10000
        pat = re.compile(r'// (?:addi r\d+,r\d+,%d|l[wbhf][zs]x? [rf]\d+,%d\(r\d+\))\n' % (lo, lo))
        for p, t in sources:
            for m in pat.finditer(t):
                seg = t[max(0, m.start() - 1200):m.start()]
                if re.search(r'// lis r\d+,%d\n' % hi, seg):
                    f = t.rfind('PPC_FUNC_IMPL(__imp__sub_', 0, m.start())
                    found.setdefault(t[f + 25:f + 33], 0)
                    found[t[f + 25:f + 33]] += 1
    print(arg, sorted(found.items()))
