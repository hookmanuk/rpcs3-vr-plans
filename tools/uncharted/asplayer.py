"""asplayer.py GAME USER_DIR LOG ROUTE: starts a game exactly as the launcher's Play does (its saved settings and
game_environment, run.py, output piped and written to LOG), with the saves folder swapped for USER_DIR (a copy of the
player's) and a pad file for scripted input (H:/uc_tests/asplayer_pad.txt; route steps as in drive.py: wait S,
press BTN [S], hold TOKENS, release, close = the window's close button). The runtime is the system's (SteamVR)."""
import ctypes, importlib.util, os, subprocess, sys, threading, time
from pathlib import Path

PORT = Path(r'H:\uncharted_pc')
game, user, log_path, route = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
spec = importlib.util.spec_from_file_location('launcher', PORT / 'launcher' / 'uncharted_launcher.py')
launcher = importlib.util.module_from_spec(spec)
sys.path.insert(0, str(PORT / 'launcher'))
spec.loader.exec_module(launcher)
settings = {**launcher.APP_DEFAULTS, **launcher.load_json(launcher.CONFIG_FILE, {})}
settings = dict(settings, user_dir=user, start=game)
# ASPLAYER_SET="key=value ...": launcher settings changed for this run (e.g. fix_job_sleep=auto).
for item in os.environ.get('ASPLAYER_SET', '').split():
    key, value = item.split('=', 1); settings[key] = value
pad = Path(r'H:\uc_tests\asplayer_pad.txt'); pad.write_text('', encoding='ascii')
env = launcher.game_environment(settings)
env['BB_PAD_FILE'] = str(pad)
env.pop('XR_RUNTIME_JSON', None)
# SIM=1: the OpenXR Simulator instead of the system runtime; ASPLAYER_ENV="K=V ...": extra variables.
if os.environ.get('SIM') == '1':
    env['XR_RUNTIME_JSON'] = r'F:\rpsc3\source\OpenXR-Simulator\bin\openxr_simulator.json'
for item in os.environ.get('ASPLAYER_ENV', '').split():
    key, value = item.split('=', 1); env[key] = value
log = open(log_path, 'w', encoding='utf-8', errors='replace')
log.write('asplayer env: ' + ' '.join(f'{k}={v}' for k, v in sorted(env.items()) if k.startswith('BB_')) + '\n')
process = subprocess.Popen(launcher.run_command(), cwd=PORT, env=env, stdin=subprocess.DEVNULL,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           creationflags=getattr(launcher, 'NO_WINDOW', 0))


def pump():
    for raw in iter(process.stdout.readline, b''):
        log.write(raw.decode('utf-8', errors='replace')); log.flush()


threading.Thread(target=pump, daemon=True).start()
user32 = ctypes.WinDLL('user32')


def close_game_window():
    found = []
    WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)

    def each(hwnd, _):
        pid = ctypes.c_ulong(); user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
        buf = ctypes.create_unicode_buffer(260)
        k32 = ctypes.WinDLL('kernel32'); h = k32.OpenProcess(0x1000, False, pid.value)
        if h:
            n = ctypes.c_ulong(260); k32.QueryFullProcessImageNameW(h, 0, buf, ctypes.byref(n)); k32.CloseHandle(h)
        if buf.value.lower().endswith('bb-probe.exe') and user32.IsWindowVisible(hwnd): found.append(hwnd)
        return True
    user32.EnumWindows(WNDENUMPROC(each), 0)
    for hwnd in found: user32.PostMessageW(ctypes.c_void_p(hwnd), 0x0010, 0, 0)  # WM_CLOSE
    print('closed %d window(s)' % len(found), flush=True)


t0 = time.time()
for step in [s.strip() for s in route.split(';') if s.strip()]:
    if process.poll() is not None: print('game exited before', step); break
    verb, *args = step.split()
    print('%6.1fs %s' % (time.time() - t0, step), flush=True)
    if verb == 'wait': time.sleep(float(args[0]))
    elif verb == 'press':
        pad.write_text(args[0], encoding='ascii'); time.sleep(float(args[1]) if len(args) > 1 else 0.15)
        pad.write_text('', encoding='ascii'); time.sleep(0.1)
    elif verb == 'hold': pad.write_text(' '.join(args), encoding='ascii')
    elif verb == 'release': pad.write_text('', encoding='ascii')
    elif verb == 'close': close_game_window()
pad.write_text('', encoding='ascii')
try:
    process.wait(timeout=30)
    print('run.py exited with', process.returncode)
except subprocess.TimeoutExpired:
    print('run.py still running 30 s after the route')
