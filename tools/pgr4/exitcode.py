"""exitcode.py SECONDS NAME=VALUE...: runs the game with its usual test environment, prints how it ended (exit code, last stderr and stdout lines)."""
import os, subprocess, sys, time
env = dict(os.environ)
env.update(REGPU_DEBUG='1', PGR4_USER_DIR=r'H:\PGR4-ReGPU\out\testuser', PGR4_TITLE_UPDATE_DIR=r'H:\PGR4-ReGPU\out\tu2', PGR4_SKIP_INTRO='1')
for a in sys.argv[2:]:
    k, v = a.split('=', 1)
    env[k] = v
with open(r'H:\PGR4-ReGPU\out\exit_out.txt', 'wb') as out:
    p = subprocess.Popen([r'H:\PGR4-ReGPU\build\rel\pgr4.exe', 'game'], cwd=r'H:\PGR4-ReGPU', env=env, stdout=out, stderr=subprocess.STDOUT)
    t0 = time.time()
    while time.time() - t0 < float(sys.argv[1]):
        c = p.poll()
        if c is not None:
            print('exited after %.1f s, code %d (0x%08X)' % (time.time() - t0, c, c & 0xFFFFFFFF))
            break
        time.sleep(0.2)
    else:
        print('still running after', sys.argv[1], 's, pid', p.pid)
print(open(r'H:\PGR4-ReGPU\out\exit_out.txt', 'rb').read()[-1500:].decode('utf-8', 'replace'))
