"""regcompare.py BASE_DIR NEW_DIR [OUT_DIR]: compare two VR regression runs (vr_regress.sh result folders).

Performance: per state, the sustainable rate of each run and, at every rate both ran, avg FPS, 1% low, late frames
and RSX thread ms/frame. Pictures: the simulator captures (sim_STATE_RATE.png, what the headset was shown) at the
lowest rate both ran: mean absolute RGB difference between the runs, and left/right eye difference within each run
(0 = one eye copied into the other, i.e. no stereo). A capture taken at a different moment of play differs by its
motion as well, so the number flags states to look at; the side-by-side montage (OUT_DIR/STATE.jpg: base left,
new right) is the check. Writes OUT_DIR/compare.md (default: NEW_DIR/compare)."""
import os, re, sys
from PIL import Image
import numpy as np

base, new = sys.argv[1], sys.argv[2]
out = sys.argv[3] if len(sys.argv) > 3 else os.path.join(new, 'compare')
os.makedirs(out, exist_ok=True)

def parse(d):
    res, order, cur = {}, [], None
    for l in open(os.path.join(d, 'results.txt'), encoding='utf8', errors='replace'):
        m = re.match(r'^# (\S+) (vrtest_\S+): (.*)', l)
        if m:
            order.append(m.group(2)); res.setdefault(m.group(2), {'scene': m.group(3).strip(), 'rates': {}})
        m = re.match(r'^(\S+) (vrtest_\S+) vblank (\d+) scale', l)
        if m:
            cur = (m.group(2), int(m.group(3)))
        m = re.match(r'\s*=> median of \d+ windows: avg ([\d.]+) FPS, 1% low ([\d.]+), late frames ([\d.]+)%(?:, RSX thread ([\d.]+) ms)?', l)
        if m and cur:
            res[cur[0]]['rates'][cur[1]] = tuple(float(x) if x else None for x in m.groups())
        m = re.match(r'SUSTAINABLE \S+ (vrtest_\S+): (\S+) Hz', l)
        if m:
            res.setdefault(m.group(1), {'scene': '', 'rates': {}})['sus'] = m.group(2)
    return res, order

def eyes(a):
    w = a.shape[1] // 2
    return np.abs(a[:, :w] - a[:, w:2 * w]).mean()

b, order = parse(base)
n, order_new = parse(new)
# States only the new run has (added to the manifest since the base run): their numbers against "-".
for st in order_new:
    if st not in b:
        order.append(st)
        b[st] = {'scene': n[st]['scene'], 'rates': {r: (None, None, None, None) for r in n[st]['rates']}, 'sus': 'not run'}
lines = ['# VR regression comparison', '', 'Base: `%s`  ' % base, 'New: `%s`' % new, '',
         '| State | Sustainable base / new | Rate | avg FPS | 1% low | late % | RSX ms/frame | Picture |d| | L/R base / new |',
         '|---|---|---|---|---|---|---|---|---|']
flags = []
for st in order:
    if st not in n:
        lines.append('| %s | %s / not run | | | | | | | |' % (st, b[st].get('sus', '?')))
        continue
    common = sorted(set(b[st]['rates']) & set(n[st]['rates']))
    pic = ''
    for r in common:
        fb, fn = os.path.join(base, 'sim_%s_%d.png' % (st, r)), os.path.join(new, 'sim_%s_%d.png' % (st, r))
        if os.path.exists(fb) and os.path.exists(fn):
            ib, inn = Image.open(fb).convert('RGB'), Image.open(fn).convert('RGB')
            if inn.size != ib.size:
                inn = inn.resize(ib.size)
            A, B = np.asarray(ib).astype(int), np.asarray(inn).astype(int)
            d = np.abs(A - B).mean()
            pic = '%.1f | %.1f / %.1f' % (d, eyes(A), eyes(B))
            m = Image.new('RGB', (ib.width * 2 + 8, ib.height), (255, 0, 255))
            m.paste(ib, (0, 0)); m.paste(inn, (ib.width + 8, 0)); m.save(os.path.join(out, '%s.jpg' % st), quality=85)
            if eyes(B) < 0.5 or B.mean() < 3:
                flags.append('%s: new run shows %s' % (st, 'a black frame' if B.mean() < 3 else 'identical eyes'))
            break
    first = True
    for r in common or [None]:
        if r is None:
            lines.append('| %s | %s / %s | | | | | | %s |' % (st, b[st].get('sus', '?'), n[st].get('sus', '?'), pic or '| '))
            break
        rb, rn = b[st]['rates'][r], n[st]['rates'][r]
        f = lambda i, fmt='%.1f': '%s / %s' % (fmt % rb[i] if rb[i] is not None else '-', fmt % rn[i] if rn[i] is not None else '-')
        lines.append('| %s | %s | %d | %s | %s | %s | %s | %s |' % (
            st if first else '', ('%s / %s' % (b[st].get('sus', '?'), n[st].get('sus', '?'))) if first else '', r,
            f(0), f(1), f(2, '%.2f'), f(3, '%.2f'), pic if first else ' | '))
        first = False
if flags:
    lines += ['', '## Flags', ''] + ['- ' + x for x in flags]
open(os.path.join(out, 'compare.md'), 'w', encoding='utf8').write('\n'.join(lines) + '\n')
print('\n'.join(lines))
