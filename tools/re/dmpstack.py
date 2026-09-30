"""dmpstack.py DUMP [N]: faulting thread of a minidump; its exception, then candidate return addresses in rpcs3.exe
found by scanning the stack (heuristic, like a raw stack dump), printed as image offsets for sym.py."""
import sys, struct
from minidump.minidumpfile import MinidumpFile
m = MinidumpFile.parse(sys.argv[1]); n = int(sys.argv[2]) if len(sys.argv) > 2 else 40
exc = m.exception.exception_records[0]
rec = exc.ExceptionRecord
print('thread', exc.ThreadId, 'code', hex(rec.ExceptionCode if isinstance(rec.ExceptionCode, int) else rec.ExceptionCode.value), 'addr', hex(rec.ExceptionAddress))
mods = [(mo.baseaddress, mo.baseaddress + mo.size, mo.name) for mo in m.modules.modules]
exe = next(x for x in mods if x[2].lower().endswith('rpcs3.exe'))
print('rpcs3 base', hex(exe[0]))
th = next(t for t in m.threads.threads if t.ThreadId == exc.ThreadId)
rd = m.get_reader().get_buffered_reader()
ctx = exc.ThreadContext
# the thread's stack memory region
sp_lo = th.Stack.StartOfMemoryRange; size = th.Stack.MemoryLocation.DataSize
rd.move(sp_lo); data = rd.read(size)
def modof(a):
    for b, e, nm in mods:
        if b <= a < e: return nm.replace(chr(92), '/').split('/')[-1], a - b
    return None
out = []
for off in range(0, len(data) - 8, 8):
    v = struct.unpack_from('<Q', data, off)[0]
    mo = modof(v)
    if mo: out.append((sp_lo + off, mo))
for a, (nm, o) in out[:n]:
    print(hex(a), nm, hex(o))
