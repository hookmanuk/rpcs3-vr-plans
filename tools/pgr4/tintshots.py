"""tintshots.py OUT.png PS...: each pixel shader tinted in turn on the running game, a crop of the left eye for each, in a grid."""
import json, socket, sys, time
from PIL import Image
def send(s, line):
    s.sendall((line + '\n').encode()); d = b''
    while not d.endswith(b'\n'): d += s.recv(1 << 20)
    return json.loads(d)
out = sys.argv[1]; hashes = sys.argv[2:]
s = socket.create_connection(('127.0.0.1', 7341))
tiles = []
for h in hashes:
    send(s, 'ps %s tint 0,1,0' % h); time.sleep(1.5)
    send(s, 'shot H:/PGR4-ReGPU/out/tt.png'); time.sleep(0.3)
    im = Image.open('H:/PGR4-ReGPU/out/tt.png').convert('RGB')
    w, h2 = im.size
    tiles.append(im.crop((w // 4, h2 // 5, w, h2 * 3 // 5)).resize((480, 340)))
    send(s, 'ps ' + h); time.sleep(0.3)
cols = 3
rows = (len(tiles) + cols - 1) // cols
m = Image.new('RGB', (480 * cols, 340 * rows))
for i, t in enumerate(tiles):
    m.paste(t, ((i % cols) * 480, (i // cols) * 340))
m.save(out)
