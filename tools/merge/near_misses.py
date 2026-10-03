#!/usr/bin/env python3
"""How close upstream's new changes came to the fork's changes (see 10-multiview-merge-audit.md section 8).

Both diffs are taken against the same merge base, so their hunks share the base's line numbers. For each
file both sides changed, counts the fork's hunks that an upstream hunk touches or is adjacent to (these
usually conflict), and those within 3 and 10 lines (near misses that merged, worth a read).

usage: near_misses.py [-C rpcs3-checkout] BASE UPSTREAM REF
example: tools/merge/near_misses.py -C ../rpcs3 $(git -C ../rpcs3 merge-base openxr upstream/master) upstream/master multiview
output: touching  within3  within10 / fork hunks in the file   file
"""
import re
import subprocess
import sys


def git(*args):
    return subprocess.run(['git', *args], capture_output=True).stdout.decode('utf-8', 'replace')


def spans(base, ref, path):
    out = []
    for m in re.finditer(r'^@@ -(\d+)(?:,(\d+))? \+\d+(?:,\d+)? @@', git('diff', '-U0', base, ref, '--', path), re.M):
        a = int(m.group(1))
        n = int(m.group(2)) if m.group(2) is not None else 1
        out.append((a, a + n - 1) if n else (a, a + 1))  # an insertion sits between lines a and a + 1
    return out


def main():
    args = sys.argv[1:]
    if args[:1] == ['-C']:
        import os
        os.chdir(args[1])
        args = args[2:]
    base, upstream, ref = args
    up_files = set(git('diff', '--name-only', base, upstream).split())
    totals = {0: 0, 3: 0, 10: 0}
    rows = []
    for path in git('diff', '--name-only', base, ref).split():
        if path not in up_files or subprocess.run(['git', 'cat-file', '-e', f'{base}:{path}'], capture_output=True).returncode:
            continue
        fork, up = spans(base, ref, path), spans(base, upstream, path)
        near = {d: sum(1 for (a, b) in fork if any(ua - d <= b and a <= ub + d for (ua, ub) in up)) for d in totals}
        for d in totals:
            totals[d] += near[d]
        if near[10]:
            rows.append((near[0], near[3], near[10], len(fork), path))
    for row in sorted(rows, reverse=True):
        print('%3d %3d %3d / %3d  %s' % row)
    print('fork hunks with an upstream change touching or adjacent: %d, within 3 lines: %d, within 10 lines: %d' % (totals[0], totals[3], totals[10]))


if __name__ == '__main__':
    main()
