"""frameupd.py TAG [TAG...]: from dumps/TAG.peek (peek_run.sh), per peeked word, the share of presented frames on which
it changed and the mean step per changed frame. A game that simulates every frame changes ~100%; one with a fixed
1/60 s step under an accumulator changes on ~60/rate of the frames (judder in the headset)."""
import sys, re, collections
for tag in sys.argv[1:]:
    rows = []
    for line in open('dumps/%s.peek' % tag, encoding='latin1'):
        m = re.search(r't=([\d.]+)', line)
        vals = dict(re.findall(r' ([0-9a-f]+)=([0-9a-f]{8})', line))
        if m and vals: rows.append((float(m.group(1)), vals))
    if len(rows) < 3: print(tag, 'no samples'); continue
    span = rows[-1][0] - rows[0][0]
    print('%s: %d frames in %.2f s (%.1f FPS)' % (tag, len(rows), span, (len(rows) - 1) / span))
    for a in rows[0][1]:
        seq = [r[1].get(a) for r in rows]
        ch = sum(1 for x, y in zip(seq, seq[1:]) if x != y)
        runs = collections.Counter()
        n = 0
        for x, y in zip(seq, seq[1:]):
            if x == y: n += 1
            else: runs[n] += 1; n = 0
        print('  %8s changed on %5.1f%% of frames; unchanged runs before a change: %s' % (a, 100 * ch / (len(seq) - 1), dict(sorted(runs.items())[:5])))
