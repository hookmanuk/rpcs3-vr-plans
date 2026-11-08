"""snap.py NAME: U2's data segment (image +0xe64000, 0x7133d8) from the running bb-probe.exe -> snaps/NAME.bin."""
import ctypes, ctypes.wintypes as wt, os, sys
sys.path.insert(0, r'H:\uncharted_pc\tools\vr')
import memscan
k32 = ctypes.WinDLL('kernel32', use_last_error=True)
here = os.path.dirname(os.path.abspath(__file__))
elf = open(r'H:\uncharted_pc\out\try\u2\eboot.elf', 'rb').read()
SIG_OFF = 0x100000
sig = elf[0x4000 + SIG_OFF:0x4000 + SIG_OFF + 48]
pid = memscan.pid()
h = k32.OpenProcess(0x410, False, pid)
def read(addr, n):
    buf = ctypes.create_string_buffer(n); got = ctypes.c_size_t()
    ok = k32.ReadProcessMemory(h, ctypes.c_uint64(addr), buf, n, ctypes.byref(got))
    return buf.raw[:got.value] if ok else None
base_file = os.path.join(here, 'snaps', 'base.txt')
os.makedirs(os.path.dirname(base_file), exist_ok=True)
base = None
if os.path.exists(base_file):
    pid0, b = open(base_file).read().split()
    if int(pid0) == pid: base = int(b, 16)
if base is None:
    mbi = memscan.MBI(); addr = 0
    while k32.VirtualQueryEx(h, ctypes.c_uint64(addr), ctypes.byref(mbi), ctypes.sizeof(mbi)):
        if mbi.State == 0x1000 and mbi.Protect & 0xF0 and mbi.RegionSize < (1 << 30):
            data = read(mbi.BaseAddress, mbi.RegionSize)
            if data:
                i = data.find(sig)
                if i >= 0:
                    base = mbi.BaseAddress + i - SIG_OFF; break
        addr = mbi.BaseAddress + mbi.RegionSize
    open(base_file, 'w').write(f'{pid} {base:x}')
print('image base', hex(base))
seg = read(base + 0xe64000, 0x7133d8)
open(os.path.join(here, 'snaps', sys.argv[1] + '.bin'), 'wb').write(seg)
print(sys.argv[1], len(seg))
