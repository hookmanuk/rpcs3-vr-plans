"""dis.py SUB [max lines]: the PowerPC of a recompiled function (the comments in out/ppc), 3 instructions a line."""
import glob, re, sys
name = sys.argv[1].lower().replace('sub_', '').upper()
limit = int(sys.argv[2]) if len(sys.argv) > 2 else 400
tag = 'PPC_FUNC_IMPL(__imp__sub_%s)' % name
for path in glob.glob('H:/PGR4-ReGPU/out/ppc/ppc_recomp.*.cpp'):
    text = open(path, errors='ignore').read()
    at = text.find(tag + ' {')
    if at < 0:
        continue
    end = text.find('\n}\n', at)
    out = []
    for line in text[at:end].splitlines():
        s = line.strip()
        if s.startswith('// ') and not s.startswith('// PPC'):
            out.append(s[3:])
        elif re.match(r'loc_[0-9A-F]+:', s):
            out.append(s)
    print(path.split('.')[-2], len(out), 'lines')
    print('\n'.join(out[:limit]))
    break
else:
    print('not found')
