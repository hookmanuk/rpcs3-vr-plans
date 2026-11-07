"""headjump.py DIR [yaw]: consecutive frames (left eye) across an instant head turn, to see a draw lag the turn by a frame: the
simulator's pose jumps while "shots" records. Montage of the frames in DIR/montage.png."""
import json, os, socket, subprocess, sys, threading, time
from PIL import Image
out = sys.argv[1]; yaw = sys.argv[2] if len(sys.argv) > 2 else '25'
os.makedirs(out, exist_ok=True)
def send(s, line):
    s.sendall((line + '\n').encode()); d = b''
    while not d.endswith(b'\n'): d += s.recv(1 << 20)
    return json.loads(d)
s = socket.create_connection(('127.0.0.1', 7341))
pose = lambda y: subprocess.run(['py', '-3', '-I', 'F:/rpsc3/source/plans/tools/re/simpose.py', str(y), '0', '0'], capture_output=True)
pose(0); time.sleep(0.5)
threading.Timer(0.25, pose, [yaw]).start()
print(send(s, 'shots 12 ' + out))
time.sleep(1); pose(0)
ims = [Image.open(os.path.join(out, 's%d.png' % i)).convert('RGB').resize((320, 320)) for i in range(12)]
m = Image.new('RGB', (320 * 6, 640))
for i, im in enumerate(ims):
    m.paste(im, ((i % 6) * 320, (i // 6) * 320))
m.save(os.path.join(out, 'montage.png'))
