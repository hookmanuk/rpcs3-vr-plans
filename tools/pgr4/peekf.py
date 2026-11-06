"""peekf.py ADDR COUNT: floats at a guest address, 4 to a line."""
import json, socket, struct, sys
s = socket.create_connection(('127.0.0.1', 7341))
s.sendall(('peek %s %d\n' % (sys.argv[1], int(sys.argv[2]) * 4)).encode()); d = b''
while not d.endswith(b'\n'): d += s.recv(1 << 20)
h = bytes.fromhex(json.loads(d)['hex']); a = int(sys.argv[1], 16)
v = struct.unpack('>%df' % (len(h) // 4), h)
for i in range(0, len(v), 4):
    print('%08X ' % (a + i * 4) + ' '.join('%11.5g' % x for x in v[i:i + 4]))
