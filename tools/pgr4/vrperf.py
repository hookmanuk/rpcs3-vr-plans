"""vrperf.py [SECONDS=10] [label]: frame rate of the running game over a window: average FPS, 1% low, mean and worst ms.
Appends to plans/tools/pgr4/perf.log. Uses the debug server's frametimes (statistics since its last call)."""
import json, socket, sys, time
def send(s, line):
    s.sendall((line + '\n').encode()); d = b''
    while not d.endswith(b'\n'): d += s.recv(1 << 22)
    return json.loads(d)
seconds = float(sys.argv[1]) if len(sys.argv) > 1 else 10
label = sys.argv[2] if len(sys.argv) > 2 else ''
s = socket.create_connection(('127.0.0.1', 7341))
send(s, 'frametimes')
time.sleep(seconds)
r = send(s, 'frametimes')
st = send(s, 'status')
line = '%s: avg %.1f FPS, 1%% low %.1f, p50 %.2f ms, p99 %.2f ms, worst %.1f ms, %d frames, draws %s' % (label, 1000 / r['avg'], 1000 / r['p99'], r['p50'], r['p99'], r['max'], r['frames'], st.get('draws'))
print(line)
open('F:/rpsc3/source/plans/tools/pgr4/perf.log', 'a').write(time.strftime('%Y-%m-%d %H:%M ') + line + '\n')
