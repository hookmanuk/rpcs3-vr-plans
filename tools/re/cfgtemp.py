"""cfgtemp.py ID set "Section/Key=value" ["Section/Sub/Key=value" ...] | cfgtemp.py ID restore

Temporary edits to a game's own custom config (bin/config/custom_configs/config_ID.yml), keeping all its other settings:
'set' backs the file up once to config_ID.yml.cfgtemp.bak and rewrites the listed keys (a missing key is added at the
end of its section; a missing section is appended). 'restore' puts the backup back. Lines are edited as text (no YAML
rewrite), so the rest of the file stays byte-identical. No BOM is written.
"""
import os, sys, shutil

ID = sys.argv[1]
C = rf'F:\rpsc3\source\rpcs3\bin\config\custom_configs\config_{ID}.yml'
BAK = C + '.cfgtemp.bak'

if sys.argv[2] == 'restore':
    if os.path.exists(BAK):
        shutil.move(BAK, C)
        print('restored', C)
    else:
        print('no backup')
    sys.exit()

if not os.path.exists(BAK):
    shutil.copy(C, BAK)
lines = open(BAK if not os.path.exists(C) else C, encoding='utf8').read().split('\n')


def set_key(lines, path, value):
    parts = path.split('/')
    start, end, depth = 0, len(lines), 0
    for p in parts[:-1]:
        ind = '  ' * depth
        found = None
        for i in range(start, end):
            l = lines[i]
            if l.startswith(ind + p + ':') and (len(l) - len(l.lstrip(' '))) == len(ind):
                found = i
                break
        if found is None:
            lines.insert(end, ind + p + ':')
            found = end
            end += 1
        # section ends at the next line with indentation <= ind
        j = found + 1
        while j < len(lines) and (lines[j].strip() == '' or (len(lines[j]) - len(lines[j].lstrip(' '))) > len(ind)):
            j += 1
        start, end, depth = found + 1, j, depth + 1
    ind = '  ' * depth
    key = parts[-1]
    for i in range(start, end):
        if lines[i].startswith(ind + key + ':') and (len(lines[i]) - len(lines[i].lstrip(' '))) == len(ind):
            lines[i] = f'{ind}{key}: {value}'
            return
    lines.insert(end, f'{ind}{key}: {value}')


for arg in sys.argv[3:]:
    path, value = arg.split('=', 1)
    set_key(lines, path, value)
open(C, 'w', encoding='utf8', newline='\n').write('\n'.join(lines))
print('set', ', '.join(sys.argv[3:]))
