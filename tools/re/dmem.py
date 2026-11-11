import struct, numpy as np
class Dump:
    def __init__(s, base):
        s.data = open(base + '.bin', 'rb').read()
        idx = open(base + '.idx', 'rb').read()
        s.pages = {struct.unpack_from('<I', idx, i)[0]: i // 4 for i in range(0, len(idx), 4)}
    def rd(s, addr, n):
        out = b''
        while n > 0:
            p = addr & ~0xffff; o = addr - p; k = min(n, 0x10000 - o)
            i = s.pages[p]; out += s.data[i * 0x10000 + o: i * 0x10000 + o + k]; addr += k; n -= k
        return out
    def f(s, addr, n=1): return struct.unpack('>%df' % n, s.rd(addr, 4 * n))
    def u(s, addr, n=1): return struct.unpack('>%dI' % n, s.rd(addr, 4 * n))
