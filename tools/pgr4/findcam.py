"""findcam.py: on a paused or still camera, finds the view-projection and the view's forward axis in guest memory."""
import json, socket, struct, sys, math

def send(s, line):
    s.sendall((line + '\n').encode()); d = b''
    while not d.endswith(b'\n'): d += s.recv(1 << 20)
    return json.loads(d)

s = socket.create_connection(('127.0.0.1', 7341))
vp = send(s, 'vrcam')['vp']
print('VP', ['%.5g' % v for v in vp])
r = [vp[i:i + 4] for i in range(0, 16, 4)]
k = math.sqrt(sum(v * v for v in r[3][:3]))
f = [v / k for v in r[3][:3]]
print('forward', f)
sx = math.sqrt(sum(v * v for v in r[0][:3]))
right = [v / sx for v in r[0][:3]]
sy = math.sqrt(sum(v * v for v in r[1][:3]))
up = [v / sy for v in r[1][:3]]
print('right', right, 'up', up, 'sx', sx, 'sy', sy)
eye = [-(r[0][3] / sx * right[i] + r[1][3] / sy * up[i] + r[3][3] / k * f[i]) for i in range(3)]
print('eye', eye)

def show(addr, n=24):
    h = bytes.fromhex(send(s, 'peek %s %d' % (addr, n * 4))['hex'])
    v = struct.unpack('>%df' % n, h)
    a = int(addr, 16)
    for i in range(0, n, 4):
        print('   %08X ' % (a + i * 4) + ' '.join('%11.5g' % x for x in v[i:i + 4]))

def search(name, a, b, gap, tol=0.0003):
    found = send(s, 'findm %.7g %.7g %d %g' % (a, b, gap, tol))['found']
    print(name, len(found), found[:12])
    return found

for name, row in (('VP row0', r[0]), ('VP row1', r[1]), ('VP row3', r[3])):
    search(name, row[0], row[1], 4)
search('VP col0', r[0][0], r[1][0], 4)
for name, axis in (('forward', f), ('right', right), ('up', up), ('-forward', [-x for x in f])):
    hits = search(name, axis[0], axis[1], 4, 0.0005)
    for a in hits[:6]:
        show('%08X' % (int(a, 16) & ~15), 16)
hits = search('eye', eye[0], eye[1], 4, 0.05)
for a in hits[:6]:
    show('%08X' % (int(a, 16) & ~15), 8)
