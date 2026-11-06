"""tintfind.py X Y [hash ...]: which pixel shader draws pixel (X, Y)? Each candidate painted magenta in turn on the
running game (regpuctl ps HASH tint), the pixel read from a shot. Candidates default to the last capture's list."""
import json, os, re, socket, sys, time
from PIL import Image

def send(s, line):
    s.sendall((line + '\n').encode())
    d = b''
    while not d.endswith(b'\n'):
        d += s.recv(65536)
    return json.loads(d)

x, y = int(sys.argv[1]), int(sys.argv[2])
hashes = sys.argv[3:]
if not hashes:
    seen = {}
    for line in open('H:/PGR4-ReGPU/thirdparty/ReGPU/out/live.log', errors='ignore'):
        m = re.search(r'draw #\d+ vs \w+ ps (\w+) .*pitch 1280', line)
        if m:
            seen[m.group(1)] = seen.get(m.group(1), 0) + 1
    hashes = sorted(seen, key=seen.get, reverse=True)
s = socket.create_connection(('127.0.0.1', 7341))
shot = 'H:/PGR4-ReGPU/out/tint.png'
def pixel():
    send(s, 'shot ' + shot)
    time.sleep(0.2)
    return Image.open(shot).convert('RGB').getpixel((x, y))
print('base', pixel())
for h in hashes:
    send(s, 'ps %s tint 1,0,1' % h)
    time.sleep(1.2)
    p = pixel()
    send(s, 'ps ' + h)
    flag = 'HIT' if p[0] > 150 and p[2] > 150 and p[1] < 90 else ''
    print(h, p, flag, flush=True)
    time.sleep(0.2)
