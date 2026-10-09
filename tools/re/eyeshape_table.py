"""eyeshape_table.py RESULTS: per-game savings table (markdown) from an eyeshape_bench.sh results.txt: avg FPS, GPU use and
power with 16:9 eyes vs headset-shaped eyes, and the totals."""
import re, sys

rows = {}
order = []
for line in open(sys.argv[1], encoding='utf8'):
    if line.startswith('#') or ' | ' not in line:
        continue
    f = [x.strip() for x in line.split('|')]
    state, mode, rate = f[0], f[1], f[2]
    m = re.match(r'([0-9.]+) ([0-9.]+) ([0-9.]+)', f[3])
    g = re.match(r'GPU ([0-9]+)% ([0-9]+) W', f[4])
    if state not in rows:
        rows[state] = {}
        order.append(state)
    rows[state][mode] = (rate, float(m.group(1)) if m else None, float(m.group(3)) if m else None,
                         int(g.group(1)) if g else None, int(g.group(2)) if g else None)

print('| State | Hz | FPS 16:9 -> shaped | Late % | GPU use | GPU power |')
print('|---|---|---|---|---|---|')
tot = [0, 0, 0, 0, 0]
for st in order:
    a, b = rows[st].get('16:9'), rows[st].get('shaped')
    if not a or not b or a[1] is None or b[1] is None or a[3] is None or b[3] is None:
        print(f'| {st} | | incomplete | | | |')
        continue
    fps = f'{a[1]:.1f} -> {b[1]:.1f}' + (f' (**{(b[1] / a[1] - 1) * 100:+.0f}%**)' if abs(b[1] / a[1] - 1) >= 0.03 else '')
    print(f'| {st} | {a[0]} | {fps} | {a[2]:.2f} -> {b[2]:.2f} | {a[3]}% -> {b[3]}% | {a[4]} -> {b[4]} W ({(b[4] / a[4] - 1) * 100:+.0f}%) |')
    tot[0] += 1; tot[1] += a[3]; tot[2] += b[3]; tot[3] += a[4]; tot[4] += b[4]
if tot[0]:
    n = tot[0]
    print(f'| **Mean of {n}** | | | | {tot[1] / n:.0f}% -> {tot[2] / n:.0f}% | {tot[3] / n:.0f} -> {tot[4] / n:.0f} W ({(tot[4] / tot[3] - 1) * 100:+.0f}%) |')
