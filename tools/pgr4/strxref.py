"""strxref.py NAME [NAME...]: guest address of each string in the title-updated executable and the functions that
load it (lis rX,hi / addi rY,rX,lo in the recompiled code's comments)."""
import glob, re, sys
d = open('H:/PGR4-ReGPU/out/tu2/default_tu2.xex', 'rb').read()
sources = [(p, open(p, errors='ignore').read()) for p in glob.glob('H:/PGR4-ReGPU/out/ppc/ppc_recomp.*.cpp')]
for name in sys.argv[1:]:
    at = d.find(name.encode() + b'\0')
    if at < 0:
        print(name, 'not found'); continue
    va = 0x82000000 + at - 0x3000
    lo = va & 0xFFFF
    hi = (va >> 16) + (1 if lo >= 0x8000 else 0)
    if lo >= 0x8000:
        lo -= 0x10000
    if hi >= 0x8000:
        hi -= 0x10000
    print('%s at %08X (lis %d, addi %d)' % (name, va, hi, lo))
    pat = re.compile(r'// lis r(\d+),%d\n(?:.*\n){0,12}?\s*// addi r\d+,r\1,%d\n' % (hi, lo))
    for p, t in sources:
        for m in pat.finditer(t):
            f = t.rfind('PPC_FUNC_IMPL(__imp__sub_', 0, m.start())
            print('   ', t[f + 25:f + 33], 'at', t[m.start():m.end()].replace('\n', ' ')[-70:].strip())
