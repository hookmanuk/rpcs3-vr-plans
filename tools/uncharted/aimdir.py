"""aimdir.py GAME [LABEL]: which way the aim turns for each push of the right stick, against a game running under
sess.sh with BB_VR_HEAD_AIM_TRACE=1 (the player standing in play). Holds the aim (l2) 2 s, then the stick right 1 s,
up 1 s (ry=0), and the left stick right 1 s (for swapped sticks), 0.6 s apart; from the trace lines of each second:
the turn of the game's camera, of the held base and of the view (degrees: yaw to the right positive in the picture,
pitch up positive), and how far the camera moved (the player walking). The same without the aim (the follow camera)
after it, with the left stick up as well. Read the result against the game's
Controls options (Aiming / Camera: Horizontal, Vertical; Left and Right Stick)."""
import re, sys, time
from pathlib import Path
out = Path(r'H:\uncharted_pc\out\try') / sys.argv[1]
label = sys.argv[2] if len(sys.argv) > 2 else ''
pad, log = out / 'pad.txt', out / 'run.log'


def put(text):
    tmp = pad.with_suffix('.tmp'); tmp.write_text(text, encoding='ascii'); tmp.replace(pad)


def last():
    with open(log, 'rb') as f:
        f.seek(0, 2); f.seek(max(0, f.tell() - 4000))
        lines = [l for l in f.read().decode('ascii', 'replace').splitlines() if l.startswith('VR aim trace') and 'target off' in l]
    m = re.search(r'xs ([\d.]+) eng (\d) .* cam (\S+) (\S+) base (\S+) (\S+) view (\S+) (\S+) pos (\S+) (\S+) (\S+)', lines[-1])
    return [float(v) for v in m.groups()]


def turn(a, b):
    d = b - a
    return d - 360 * round(d / 360)


def push(name, tokens, aim):
    hold = 'l2 ' if aim else ''
    put(hold.strip()); time.sleep(0.6)
    a = last(); put(hold + tokens); time.sleep(1.0); b = last(); put(hold.strip())
    # The trace's yaw is atan2(x, z) of the forward row: it grows to the picture's LEFT in this frame; printed negated.
    moved = sum((b[8 + k] - a[8 + k]) ** 2 for k in range(3)) ** 0.5
    print('%-8s %-18s eng %d: camera yaw %+6.1f pitch %+6.1f | base yaw %+6.1f pitch %+6.1f | view yaw %+6.1f pitch %+6.1f | camera moved %.2f m'
          % ('aim' if aim else 'no aim', name, int(b[1]), -turn(a[2], b[2]), b[3] - a[3], -turn(a[4], b[4]), b[5] - a[5],
             -turn(a[6], b[6]), b[7] - a[7], moved))


print(label)
put('l2'); time.sleep(2.0)
push('right stick right', 'rx=255', True)
push('right stick up', 'ry=0', True)
push('left stick right', 'lx=255', True)
put(''); time.sleep(2.5)
push('right stick right', 'rx=255', False)
push('right stick up', 'ry=0', False)
push('left stick right', 'lx=255', False)
push('left stick up', 'ly=0', False)
put('')
