"""bodrive.py "STEPS": drives Burnout through the pad file (pad.txt here): press BTN [secs] | hold TOKENS | release |
wait S | shot NAME (the simulator's composite, NAME.png here) | win NAME (the desktop window)."""
import os, subprocess, sys, time
S = os.path.dirname(os.path.abspath(__file__))
O = r'C:\Users\matt\AppData\Local\Temp\claude\f--rpsc3-source\4442e172-019d-4ce9-a371-7b716d311939\scratchpad'
pad = os.path.join(S, 'pad.txt')
def write(t):
    open(pad + '.tmp', 'w').write(t)
    for _ in range(50):
        try:
            os.replace(pad + '.tmp', pad); return
        except PermissionError:
            time.sleep(0.005)
for step in filter(None, (x.strip() for x in sys.argv[1].split(';'))):
    v, *a = step.split()
    if v == 'press':
        write(a[0]); time.sleep(float(a[1]) if len(a) > 1 else 0.25); write(''); time.sleep(0.2)
    elif v == 'hold': write(' '.join(a))
    elif v == 'release': write('')
    elif v == 'wait': time.sleep(float(a[0]))
    elif v == 'shot':
        subprocess.run([sys.executable, '-I', os.path.join(O, 'vr', 'simshot.py'), a[0], a[1] if len(a) > 1 else '1600'], capture_output=True)
        import shutil; shutil.copy(os.path.join(O, 'vr', a[0] + '.png'), os.path.join(S, a[0] + '.png'))
        try: shutil.copy(os.path.join(O, 'vr', a[0] + '.full.png'), os.path.join(S, a[0] + '.full.png'))
        except OSError: pass
    elif v == 'win':
        subprocess.run([sys.executable, '-I', os.path.join(O, 'mc', 'wincap.py'), os.path.join(S, a[0])], capture_output=True,
                       env=dict(os.environ, CAP_EXE='burnout.exe'))
    print(step, flush=True)
