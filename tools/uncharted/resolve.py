#!/usr/bin/env python3
"""resolve.py FILE CHOICES: resolves FILE's merge-conflict hunks (diff3 style) in place, keeping its line endings.
CHOICES: comma-separated N=o|t|b|tb (ours, theirs, ours then theirs, theirs then ours) by hunk number (1-based, as
hunks.py prints them), or all=X for every hunk not named. A hunk left without a choice stays as it is."""
import sys

path, spec = sys.argv[1], sys.argv[2]
choices = {}
for item in spec.split(','):
    key, value = item.split('=')
    choices[key] = value
data = open(path, encoding='utf-8', errors='surrogateescape', newline='').read()
nl = '\r\n' if '\r\n' in data else '\n'
lines = data.split(nl)
out = []
i = 0
n = 0
left = 0
while i < len(lines):
    if not lines[i].startswith('<<<<<<<'):
        out.append(lines[i])
        i += 1
        continue
    n += 1
    raw = [lines[i]]
    sides = {'o': [], 'base': [], 't': []}
    side = 'o'
    i += 1
    while not lines[i].startswith('>>>>>>>'):
        raw.append(lines[i])
        if lines[i].startswith('|||||||'):
            side = 'base'
        elif lines[i].startswith('======='):
            side = 't'
        else:
            sides[side].append(lines[i])
        i += 1
    raw.append(lines[i])
    i += 1
    choice = choices.get(str(n), choices.get('all'))
    if choice == 'o':
        out += sides['o']
    elif choice == 't':
        out += sides['t']
    elif choice == 'b':
        out += sides['o'] + sides['t']
    elif choice == 'tb':
        out += sides['t'] + sides['o']
    else:
        out += raw
        left += 1
open(path, 'w', encoding='utf-8', errors='surrogateescape', newline='').write(nl.join(out))
print(f'{path}: {n} hunks, {left} left')
