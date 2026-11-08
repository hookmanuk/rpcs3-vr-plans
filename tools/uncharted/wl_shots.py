"""wl_shots.py TAG [yaw...]: eye dumps (game render, left eye) at head yaw 0, each yaw, then 0 again (control)."""
import os, shutil, subprocess, sys, time
SP = r'F:\rpsc3\source\plans\tools\re\simpose.py'
D = os.path.join(os.environ['TEMP'], 'dcvr'); U = os.path.dirname(os.path.abspath(__file__))
tag = sys.argv[1]; yaws = [float(a) for a in sys.argv[2:]] or [12.0]
def dump(name, yaw, pitch=0.0):
    subprocess.run([sys.executable, SP, str(yaw), str(pitch), '0'], capture_output=True); time.sleep(1.5)
    for f in ('eye_0.raw', 'eye_1.raw'):
        try: os.remove(os.path.join(D, f))
        except FileNotFoundError: pass
    open(os.path.join(D, 'EYES'), 'w').close()
    t = time.time()
    while not os.path.exists(os.path.join(D, 'eye_1.raw')) and time.time() - t < 10: time.sleep(0.2)
    time.sleep(0.5)
    shutil.copy(os.path.join(D, 'eye_0.raw'), os.path.join(U, f'{tag}_{name}.raw'))
dump('a', 0)
for y in yaws: dump(f'y{y:g}', y)
dump('c', 0)
subprocess.run([sys.executable, SP, '0', '0', '0'], capture_output=True)
print('ok')
