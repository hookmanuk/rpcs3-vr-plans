"""flipspikes.py LOG [FROM_S] [TO_S]: frame-time spikes in a BB_FLIP_LOG file (%TEMP%\\fliplog.txt: per game flip
"t_us frame_ms draws dispatches gpu_thread_ms gpu_user_ms image_MB buffer_MB"), over a window in seconds from the
log's end (default the last 30 s). Prints the median frame, the spikes (> 1.5x median), the gaps between spikes
(periodic spikes show one gap again and again) and the work in spike frames against the rest."""
import statistics, sys
rows = [list(map(float, l.split())) for l in open(sys.argv[1]) if len(l.split()) == 8]
end = rows[-1][0]
lo = float(sys.argv[2]) if len(sys.argv) > 2 else 30.0
hi = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0
rows = [r for r in rows if end - lo * 1e6 <= r[0] <= end - hi * 1e6]
ft = [r[1] for r in rows]
med = statistics.median(ft)
spikes = [r for r in rows if r[1] > 1.5 * med]
print(f'{len(rows)} frames over {(rows[-1][0] - rows[0][0]) / 1e6:.1f} s, median {med:.2f} ms, '
      f'p99 {sorted(ft)[int(len(ft) * 0.99)]:.2f} ms, max {max(ft):.2f} ms, spikes (>1.5x) {len(spikes)}')
gaps = [(b[0] - a[0]) / 1e3 for a, b in zip(spikes, spikes[1:])]
if gaps:
    print('gaps between spikes (ms):', ' '.join(f'{g:.0f}' for g in gaps[:60]))
    # frames between spikes
    idx = [i for i, r in enumerate(rows) if r[1] > 1.5 * med]
    print('frames between spikes:', ' '.join(str(b - a) for a, b in zip(idx, idx[1:]))[:400])
def mean(rs, k):
    return sum(r[k] for r in rs) / len(rs) if rs else 0.0
normal = [r for r in rows if r[1] <= 1.5 * med]
for name, rs in (('spike frames', spikes), ('other frames', normal)):
    print(f'{name:13s}: frame {mean(rs, 1):6.2f} ms, draws {mean(rs, 2):6.0f}, dispatches {mean(rs, 3):6.0f}, '
          f'GPU thread {mean(rs, 4):5.2f} ms, image {mean(rs, 6):5.2f} MB, buffer {mean(rs, 7):5.2f} MB')
for r in spikes[:12]:
    print('  spike: %.2f ms, %d draws, %d dispatches, GPU thread %.2f ms, image %.2f MB, buffer %.2f MB'
          % (r[1], r[2], r[3], r[4], r[6], r[7]))
