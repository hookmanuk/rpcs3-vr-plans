"""fgphase.py PREFIX [MAXFLIPS]: each generated frame G dumped at flip n, located on the time line of the real frames
r(n-2), r(n-1), r(n): t = position in units of one game frame, 0 = r(n-1), 1 = r(n), -1 = r(n-2). Per block: G's displacement
from r(n-1) projected on r(n-1)->r(n) (forward) and on r(n-1)->r(n-2) (backward); a negative t means G lies before r(n-1)."""
import sys, glob, re
import numpy as np
pre = sys.argv[1]; maxf = int(sys.argv[2]) if len(sys.argv) > 2 else 99
w, h, fmt = map(int, open(pre + '.txt').read().split())
def load(p):
    a = np.frombuffer(open(p, 'rb').read(), np.uint8).reshape(h, w, 4)[:, :, :3].astype(np.float32)
    return a @ np.array([0.299, 0.587, 0.114], np.float32)
def match(a, b, x, y, bs=32, r=40):
    blk = a[y:y + bs, x:x + bs]; best = None
    for step, rr, c in ((3, r, (0, 0)), (1, 3, None)):
        cx, cy = c if c else (best[1], best[2])
        for dy in range(cy - rr, cy + rr + 1, step):
            for dx in range(cx - rr, cx + rr + 1, step):
                yy, xx = y + dy, x + dx
                if yy < 0 or xx < 0 or yy + bs > h or xx + bs > w: continue
                e = np.abs(b[yy:yy + bs, xx:xx + bs] - blk).mean()
                if best is None or e < best[0]: best = (e, dx, dy)
    return best
R = {int(re.search(r'\.(\d+)\.r$', f).group(1)): f for f in glob.glob(pre + '.*.r')}
out = {}
for n in sorted(R):
    if n - 2 not in R or n > maxf: continue
    P, A, B = load(R[n - 2]), load(R[n - 1]), load(R[n])
    for g in sorted(glob.glob('%s.%03d.g*' % (pre, n))):
        tag = g.rsplit('.', 1)[1]; G = load(g); ts = []
        for y in range(40, h - 72, 64):
            for x in range(40, w - 72, 64):
                if A[y:y + 32, x:x + 32].std() < 6: continue
                ab, ap, ag = match(A, B, x, y), match(A, P, x, y), match(A, G, x, y)
                if max(ab[0], ap[0], ag[0]) > 12: continue
                fwd = np.array(ab[1:]); bwd = np.array(ap[1:]); dg = np.array(ag[1:])
                if fwd @ fwd < 9 or bwd @ bwd < 9: continue
                # forward projection if G moved along A->B, else backward (negative)
                tf = dg @ fwd / (fwd @ fwd); tb = dg @ bwd / (bwd @ bwd)
                ts.append(tf if tf >= tb else -tb)
        if ts:
            t = float(np.median(ts)); out.setdefault(tag, []).append(t)
            print('flip %3d %-6s t = %+.3f (%d blocks)' % (n, tag, t, len(ts)))
for tag, v in sorted(out.items()):
    print('%s: median t %+.3f over %d flips' % (tag, float(np.median(v)), len(v)))
