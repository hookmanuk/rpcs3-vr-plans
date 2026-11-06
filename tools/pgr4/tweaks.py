"""tweaks.py OUT: the game's named settings ("Camera.Shake.Enable"...): objects in linked lists (+4 next, +8 prev, +16 name),
value from +32. Walks from the objects found by their constructors' static addresses, writes OUT (addr, name, bytes)."""
import json, socket, struct, sys

def send(s, line):
    s.sendall((line + '\n').encode()); d = b''
    while not d.endswith(b'\n'): d += s.recv(1 << 20)
    return json.loads(d)

s = socket.create_connection(('127.0.0.1', 7341))
def peek(a, n):
    r = send(s, 'peek %08X %d' % (a, n))
    return bytes.fromhex(r['hex']) if r.get('ok') else None
def cstr(a):
    b = peek(a, 96)
    return b.split(b'\0')[0].decode('latin1') if b else '?'

seen = {}
def walk(a, off):
    while a and a not in seen:
        o = peek(a, 64)
        if not o: break
        vt, nx, pv, kind, name = struct.unpack('>5I', o[:20])
        if not (0x82000000 <= name < 0x84000000) or not (0x82000000 <= vt < 0x84000000):
            break
        seen[a] = (cstr(name), vt, kind, o[20:64])
        a = struct.unpack('>I', o[off:off + 4])[0]

for start in sys.argv[2:] or ['82C94460', '82A928B4']:
    a = int(start, 16)
    walk(a, 4)
    seen.pop(a, None)
    walk(a, 8)
with open(sys.argv[1], 'w') as f:
    for a, (name, vt, kind, rest) in sorted(seen.items(), key=lambda kv: kv[1][0]):
        v = rest[12:]
        fl = struct.unpack('>3f', v[:12])
        f.write('%08X %-60s vt %08X kind %d flags %s | b %d %d | f %.5g %.5g %.5g\n' % (a, name, vt, kind, rest[:8].hex(), v[0], v[1], fl[0], fl[1], fl[2]))
print(len(seen), 'settings')
