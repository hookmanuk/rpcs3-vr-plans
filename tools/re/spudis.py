"""spudis.py ELF START END [BASE]: minimal Cell SPU disassembler for an image embedded in a PPU ELF (vaddr range, hex).
BASE (hex, optional) prints local-store offsets relative to the image start as well. Covers the common RR, RRR, RI7,
RI8, RI10, RI16, RI18 forms; unknown words print as '.word'."""
import struct, sys

RR = {0x0c0: 'a', 0x040: 'sf', 0x0c1: 'and', 0x041: 'or', 0x241: 'xor', 0x0c9: 'nand', 0x049: 'nor', 0x2c1: 'andc',
      0x2c9: 'orc', 0x3c4: 'mpy', 0x3cc: 'mpyu', 0x3c5: 'mpyh', 0x05b: 'shl', 0x05f: 'shlh', 0x058: 'rot', 0x059: 'rotm',
      0x05a: 'rotma', 0x1dc: 'rotqby', 0x1df: 'shlqby', 0x1d8: 'rotqbi', 0x1db: 'shlqbi', 0x3c0: 'ceq', 0x240: 'cgt',
      0x2c0: 'clgt', 0x2c4: 'fa', 0x2c5: 'fs', 0x2c6: 'fm', 0x3c2: 'fceq', 0x2c2: 'fcgt', 0x1a8: 'bi', 0x1a9: 'bisl',
      0x1aa: 'iret', 0x128: 'biz', 0x129: 'binz', 0x12a: 'bihz', 0x12b: 'bihnz', 0x00d: 'rdch', 0x10d: 'wrch',
      0x00f: 'rchcnt', 0x1b4: 'fsmb', 0x1b6: 'fsm', 0x1b0: 'gb', 0x2a5: 'clz', 0x1d4: 'shufb?', 0x3b0: 'fesd?',
      0x201: 'nop', 0x001: 'lnop', 0x000: 'stop', 0x0c4: 'ah', 0x048: 'sfh', 0x3c8: 'ceqh', 0x248: 'cgth', 0x1f4: 'cwd?'}
RI7 = {0x07b: 'shli', 0x078: 'roti', 0x079: 'rotmi', 0x07a: 'rotmai', 0x1fc: 'rotqbyi', 0x1ff: 'shlqbyi', 0x1f8: 'rotqbii',
       0x1fb: 'shlqbii', 0x1f4: 'cbd', 0x1f5: 'chd', 0x1f6: 'cwd', 0x1f7: 'cdd'}
RI10 = {0x34: 'lqd', 0x24: 'stqd', 0x1c: 'ai', 0x1d: 'ahi', 0x0c: 'sfi', 0x16: 'andi', 0x04: 'ori', 0x46: 'xori',
        0x7c: 'ceqi', 0x4c: 'cgti', 0x5c: 'clgti', 0x74: 'mpyi', 0x75: 'mpyui', 0x14: 'andhi', 0x05: 'orhi',
        0x7d: 'ceqhi', 0x4d: 'cgthi', 0x5d: 'clgthi', 0x3c: 'heqi?', 0x4f: 'hgti', 0x5f: 'hlgti'}
RI16 = {0x081: 'il', 0x083: 'ilh', 0x082: 'ilhu', 0x0c1: 'iohl', 0x061: 'lqa', 0x041: 'stqa', 0x067: 'lqr',
        0x047: 'stqr', 0x064: 'br', 0x060: 'bra', 0x066: 'brsl', 0x062: 'brasl', 0x040: 'brz', 0x042: 'brnz',
        0x044: 'brhz', 0x046: 'brhnz', 0x065: 'fsmbi'}
RRR = {0x8: 'selb', 0xb: 'shufb', 0xc: 'mpya', 0xe: 'fma', 0xd: 'fnms', 0xf: 'fms'}
CH = {8: 'SPU_RdDec', 7: 'SPU_WrDec', 0: 'SPU_RdEventStat', 1: 'SPU_WrEventMask', 2: 'SPU_WrEventAck', 29: 'SPU_RdInMbox',
      28: 'SPU_WrOutMbox', 30: 'SPU_WrOutIntrMbox', 16: 'MFC_LSA', 17: 'MFC_EAH', 18: 'MFC_EAL', 19: 'MFC_Size',
      20: 'MFC_TagID', 21: 'MFC_Cmd', 22: 'MFC_WrTagMask', 23: 'MFC_WrTagUpdate', 24: 'MFC_RdTagStat', 27: 'MFC_RdAtomicStat'}

def sext(v, bits):
    return v - (1 << bits) if v & (1 << (bits - 1)) else v

def dis(w, pc):
    rt, ra, rb = w & 0x7f, (w >> 7) & 0x7f, (w >> 14) & 0x7f
    op4 = w >> 28
    if op4 in RRR:
        rc = (w >> 21) & 0x7f
        return f'{RRR[op4]} ${rc}, ${ra}, ${rb}, ${rt}'
    op11 = w >> 21
    if op11 in RR:
        n = RR[op11]
        if n in ('rdch', 'rchcnt'):
            return f'{n} ${rt}, {CH.get(ra, ra)}'
        if n == 'wrch':
            return f'wrch {CH.get(ra, ra)}, ${rt}'
        if n in ('bi', 'iret'):
            return f'{n} ${ra}'
        if n in ('biz', 'binz', 'bihz', 'bihnz', 'bisl'):
            return f'{n} ${rt}, ${ra}'
        return f'{n} ${rt}, ${ra}, ${rb}'
    if op11 in RI7:
        return f'{RI7[op11]} ${rt}, ${ra}, {sext(rb, 7)}'
    op10 = w >> 22
    if op10 in (0x3b8, 0x3b9, 0x3ba, 0x3bb):
        names = {0x3b8: 'cflts', 0x3b9: 'cfltu', 0x3ba: 'csflt', 0x3bb: 'cuflt'}
        return f'{names[op10]} ${rt}, ${ra}, {155 - ((w >> 14) & 0xff)}'
    op8 = w >> 24
    if op8 in RI10:
        i10 = sext((w >> 14) & 0x3ff, 10)
        n = RI10[op8]
        if n in ('lqd', 'stqd'):
            return f'{n} ${rt}, {i10 * 16}(${ra})'
        return f'{n} ${rt}, ${ra}, {i10}'
    op9 = w >> 23
    if op9 in RI16:
        i16 = sext((w >> 7) & 0xffff, 16)
        n = RI16[op9]
        if n in ('br', 'brsl', 'brz', 'brnz', 'brhz', 'brhnz', 'lqr', 'stqr'):
            return f'{n} ${rt}, {pc + i16 * 4:#x}' if n != 'br' else f'br {pc + i16 * 4:#x}'
        if n in ('bra', 'brasl', 'lqa', 'stqa'):
            return f'{n} ${rt}, {(i16 * 4) & 0x3ffff:#x}'
        return f'{n} ${rt}, {i16 & 0xffff:#x}'
    op7 = w >> 25
    if op7 == 0x21:
        return f'ila ${rt}, {(w >> 7) & 0x3ffff:#x}'
    if op7 in (0x08, 0x09):
        return f'hbr? {w:08x}'
    return f'.word {w:08x}'

if __name__ == '__main__':
    d = open(sys.argv[1], 'rb').read()
    ph, n = struct.unpack('>Q', d[0x20:0x28])[0], struct.unpack('>H', d[0x38:0x3a])[0]
    a, b = int(sys.argv[2], 16), int(sys.argv[3], 16)
    base = int(sys.argv[4], 16) if len(sys.argv) > 4 else None
    for s in range(n):
        t, f, off, va, pa, fs, ms = struct.unpack('>IIQQQQQ', d[ph + s * 56:ph + s * 56 + 48])
        if t == 1 and va <= a < va + fs:
            for x in range(a, b, 4):
                w = struct.unpack('>I', d[off + x - va:off + x - va + 4])[0]
                ls = f' [{x - base:05x}]' if base is not None else ''
                print(f'{x:08x}{ls}: {w:08x}  {dis(w, (x - base) if base is not None else x)}')
