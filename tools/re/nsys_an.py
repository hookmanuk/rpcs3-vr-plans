"""nsys_an.py REPORT.sqlite [schema]: GPU busy vs idle from the Vulkan GPU workloads, Vulkan API waits per thread,
OpenXR calls, and (with sampling) the top sampled symbols per thread."""
import sqlite3, sys, collections
db = sqlite3.connect(sys.argv[1])
cur = db.cursor()
tables = [r[0] for r in cur.execute("select name from sqlite_master where type='table' order by name")]
if len(sys.argv) > 2:
    for t in tables:
        cols = [c[1] for c in cur.execute(f'pragma table_info({t})')]
        n = cur.execute(f'select count(*) from {t}').fetchone()[0]
        print(f'{t} ({n}): {", ".join(cols)}')
    sys.exit()

def has(t): return t in tables
def cols(t): return [c[1] for c in cur.execute(f'pragma table_info({t})')]

strings = {}
if has('StringIds'):
    strings = dict(cur.execute('select id, value from StringIds'))
threads = {}
if has('ThreadNames'):
    for name_id, tid in cur.execute('select nameId, globalTid from ThreadNames'):
        threads[tid] = strings.get(name_id, str(name_id))

def tname(tid):
    return threads.get(tid, str(tid & 0xffffffff))

# --- GPU workloads: busy (union of intervals) vs wall
for t in [x for x in tables if 'WORKLOAD' in x.upper() or 'GPU' in x.upper()]:
    c = cols(t)
    if 'start' in c and 'end' in c:
        rows = sorted(cur.execute(f'select start, end from {t} where end > start'))
        if not rows: continue
        busy = 0; cs, ce = rows[0]
        gaps = []
        for s, e in rows[1:]:
            if s > ce:
                busy += ce - cs; gaps.append(s - ce); cs, ce = s, e
            else:
                ce = max(ce, e)
        busy += ce - cs
        wall = rows[-1][1] - rows[0][0]
        print(f'{t}: {len(rows)} workloads over {wall/1e6:.1f} ms: GPU busy {busy/1e6:.1f} ms ({100*busy/wall:.1f}%), idle {(wall-busy)/1e6:.1f} ms in {len(gaps)} gaps, '
              f'gaps >0.5 ms: {sum(1 for g in gaps if g > 5e5)} totalling {sum(g for g in gaps if g > 5e5)/1e6:.1f} ms')
        # per 1-second slice: per-frame style summary uses windows of 100 ms
        big = sorted(gaps, reverse=True)[:8]
        print('   largest gaps ms:', ' '.join(f'{g/1e6:.2f}' for g in big))

# --- Vulkan API calls: total time per (thread, function), top 20
for t in [x for x in tables if x.upper().startswith('VULKAN_API')]:
    c = cols(t)
    name_col = 'nameId' if 'nameId' in c else None
    if not name_col or 'globalTid' not in c: continue
    wall = cur.execute(f'select max(end) - min(start) from {t}').fetchone()[0] or 1
    print(f'\n{t}: top calls by total time over {wall/1e6:.1f} ms')
    for n, tot, cnt, tid in cur.execute(f'select nameId, sum(end-start), count(*), globalTid from {t} group by globalTid, nameId order by 2 desc limit 20'):
        print(f'   {tot/1e6:8.2f} ms  {cnt:6d} x  {strings.get(n, n):40s} {tname(tid)}')

# --- OpenXR
for t in [x for x in tables if 'OPENXR' in x.upper() and 'API' in x.upper()]:
    c = cols(t)
    if 'nameId' not in c: continue
    print(f'\n{t}:')
    for n, tot, cnt, tid in cur.execute(f'select nameId, sum(end-start), count(*), globalTid from {t} group by globalTid, nameId order by 2 desc limit 12'):
        print(f'   {tot/1e6:8.2f} ms  {cnt:6d} x  {strings.get(n, n):40s} {tname(tid)}')

# --- CPU sampling: samples per thread, and top leaf symbols on the RSX thread
if has('COMPOSITE_EVENTS') and has('SAMPLING_CALLCHAINS'):
    print('\nCPU samples per thread:')
    per = cur.execute('select globalTid, count(*) from COMPOSITE_EVENTS group by globalTid order by 2 desc limit 16').fetchall()
    total = sum(n for _, n in per) or 1
    for tid, n in per:
        print(f'   {100*n/total:5.1f}%  {tname(tid)}')
    syms = dict(cur.execute('select id, value from StringIds'))
    if has('SYMBOLS'):
        pass
    print('\nTop leaf symbols (all threads):')
    q = ('select s.symbol, count(*) from SAMPLING_CALLCHAINS s where s.stackDepth = 0 group by s.symbol order by 2 desc limit 25')
    try:
        for sym, n in cur.execute(q):
            print(f'   {100*n/total:5.1f}%  {strings.get(sym, sym)}')
    except Exception as e:
        print('  ', e)
