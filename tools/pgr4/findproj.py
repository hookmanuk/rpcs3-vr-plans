"""findproj.py SX SY: guest addresses of matrices with m00 = SX, m11 = SY, and their 16 floats."""
import json, socket, struct, sys
def send(s, line):
    s.sendall((line + '\n').encode()); d = b''
    while not d.endswith(b'\n'): d += s.recv(1 << 20)
    return json.loads(d)
sx, sy = sys.argv[1], sys.argv[2]
s = socket.create_connection(('127.0.0.1', 7341))
r = send(s, 'findm %s %s 20 0.001' % (sx, sy))
print(len(r['found']))
for a in r['found'][:60]:
    f = struct.unpack('>16f', bytes.fromhex(send(s, 'peek %s 64' % a)['hex']))
    print(a, ' '.join('%.4g' % v for v in f))
