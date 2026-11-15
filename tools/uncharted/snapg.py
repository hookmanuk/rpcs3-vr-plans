"""snapg.py GAME NAME: the game's data segment (the writable LOAD of out/try/GAME/eboot.elf) from the running
bb-probe.exe -> snaps/NAME.bin; prints the image base and the segment's image offset. (snap.py, for any of the three
games.) Compare with diffg.py."""
import ctypes, os, struct, sys
sys.path.insert(0, r'H:\uncharted_pc\tools\vr')
import memscan
k32 = ctypes.WinDLL('kernel32', use_last_error=True)
here = os.path.dirname(os.path.abspath(__file__))
game, name = sys.argv[1], sys.argv[2]
elf = open(rf'H:\uncharted_pc\out\try\{game}\eboot.elf', 'rb').read()
phoff, = struct.unpack_from('<Q', elf, 0x20); phentsize, phnum = struct.unpack_from('<HH', elf, 0x36)
seg = None
for i in range(phnum):
    t, fl, off, va, pa, fs, ms, al = struct.unpack_from('<IIQQQQQQ', elf, phoff + i * phentsize)
    if t == 1 and fl == 6: seg = (va, ms)
SIG_OFF = 0x100000
sig = elf[0x4000 + SIG_OFF:0x4000 + SIG_OFF + 48]
pid = memscan.pid()
h = k32.OpenProcess(0x410, False, pid)


def read(addr, n):
    buf = ctypes.create_string_buffer(n); got = ctypes.c_size_t()
    ok = k32.ReadProcessMemory(h, ctypes.c_uint64(addr), buf, n, ctypes.byref(got))
    return buf.raw[:got.value] if ok else None


os.makedirs(os.path.join(here, 'snaps'), exist_ok=True)
base_file = os.path.join(here, 'snaps', 'base_%s.txt' % game)
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
data = read(base + seg[0], seg[1])
open(os.path.join(here, 'snaps', name + '.bin'), 'wb').write(struct.pack('<Q', seg[0]) + data)
print('image base', hex(base), 'segment +%#x' % seg[0], name, len(data))
