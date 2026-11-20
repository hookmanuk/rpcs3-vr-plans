#!/usr/bin/env python3
"""hunks.py FILE [N]: print the merge-conflict hunks of FILE (ours / base / theirs), each side cut to N lines
(default 40), with the hunk's line number. For resolving big merges hunk by hunk."""
import sys

path = sys.argv[1]
limit = int(sys.argv[2]) if len(sys.argv) > 2 else 40
lines = open(path, encoding='utf-8', errors='replace', newline='').read().splitlines()
i = 0
n = 0
while i < len(lines):
    if lines[i].startswith('<<<<<<<'):
        n += 1
        start = i
        sides = {'ours': [], 'base': [], 'theirs': []}
        side = 'ours'
        i += 1
        while i < len(lines) and not lines[i].startswith('>>>>>>>'):
            if lines[i].startswith('|||||||'):
                side = 'base'
            elif lines[i].startswith('======='):
                side = 'theirs'
            else:
                sides[side].append(lines[i])
            i += 1
        print(f'===== hunk {n} at line {start + 1}')
        for name in ('ours', 'base', 'theirs'):
            body = sides[name]
            if name == 'base' and not body:
                continue
            print(f'--- {name} ({len(body)} lines)')
            for l in body[:limit]:
                print('  ' + l)
            if len(body) > limit:
                print(f'  ... {len(body) - limit} more')
    i += 1
