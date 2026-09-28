"""pine.py: live PS3 memory access through RPCS3's IPC server (PINE protocol, TCP 127.0.0.1:28012).

Needs `IPC Server enabled: true` in rpcs3/bin/config/ipc.yml (read when RPCS3 starts). Works while a game runs,
with no relaunch, but is not synchronised with frames: for per-frame logs, PPU watchpoints or code patches use the
RPCS3_VR_PEEK / RPCS3_PPU_WATCH / RPCS3_VR_POKE hooks. Writes to code are not seen by LLVM-compiled code.

Addresses are hex (0x optional) and may dereference u32 pointers: '[0x1050300]+0x14', '[[0x1050300]+8]-4'.
Types: u8 u16 u32 u64 s8 s16 s32 s64 f32 f64 (values are the PS3's, big-endian in memory).

  pine.py info                              title, ID, version, status
  pine.py read ADDR [TYPE] [COUNT]          e.g. read [0x1050300]+0x14 f32
  pine.py write ADDR TYPE VALUE [VALUE...]  consecutive values; prints old -> new
  pine.py dump ADDR LEN FILE                raw big-endian bytes; unmapped 4 KB pages are zero-filled and listed
  pine.py find ADDR LEN TYPE VALUE [TOL]    every aligned match (f32/f64 within TOL, default 1e-4)
  pine.py watch ADDR[:TYPE] ... [--ms N] [--for S]   print each change with the time (default every 50 ms)

As a module: `from pine import Pine; p = Pine(); p.read('0x10000', 'f32')`.
"""
import re, socket, struct, sys, time

PORT = 28012
TYPES = {'u8': (1, 'B'), 's8': (1, 'b'), 'u16': (2, 'H'), 's16': (2, 'h'), 'u32': (4, 'I'), 's32': (4, 'i'),
         'u64': (8, 'Q'), 's64': (8, 'q'), 'f32': (4, 'f'), 'f64': (8, 'd')}
READ_OP = {1: 0, 2: 1, 4: 2, 8: 3}
WRITE_OP = {1: 4, 2: 5, 4: 6, 8: 7}
UINT = {1: 'B', 2: 'H', 4: 'I', 8: 'Q'}
BATCH = 32768  # commands per message (limits: 650000-byte request, 450000-byte reply)


class PineError(Exception):
    pass


class Pine:
    def __init__(self, port=PORT, timeout=5.0):
        try:
            self.sock = socket.create_connection(('127.0.0.1', port), timeout=timeout)
        except OSError as e:
            raise PineError(f'no IPC server on port {port} ({e}); is RPCS3 running with IPC enabled in config/ipc.yml?')

    def _call(self, body):
        self.sock.sendall(struct.pack('<I', len(body) + 4) + body)
        head = self._recv(4)
        reply = self._recv(struct.unpack('<I', head)[0] - 4)
        if reply[0] != 0:
            raise PineError('IPC command failed (unmapped or read-only address?)')
        return reply[1:]

    def _recv(self, n):
        buf = b''
        while len(buf) < n:
            chunk = self.sock.recv(n - len(buf))
            if not chunk:
                raise PineError('IPC connection closed')
            buf += chunk
        return buf

    def _string(self, op):
        data = self._call(bytes([op]))
        n = struct.unpack_from('<I', data)[0]
        return data[4:4 + n - 1].decode('utf-8', 'replace')

    def info(self):
        # MsgStatus: RPCS3's server skips 4 argument bytes after the opcode, so it is padded and sent alone.
        status = struct.unpack('<I', self._call(bytes([0xF]) + bytes(4)))[0]
        return {'version': self._string(8), 'title': self._string(0xB), 'id': self._string(0xC),
                'uuid': self._string(0xD), 'game_version': self._string(0xE),
                'status': {0: 'running', 1: 'paused', 2: 'shutdown'}.get(status, status)}

    def resolve(self, expr):
        """'[0x100]+0x14' -> u32 at 0x100, plus 0x14. Nested brackets allowed."""
        expr = expr.strip()
        if expr.startswith('['):
            depth = 0
            for i, c in enumerate(expr):
                depth += (c == '[') - (c == ']')
                if depth == 0:
                    break
            base = self.read_raw(self.resolve(expr[1:i]), 4)
            rest = expr[i + 1:].replace(' ', '')
            return (base + (sum(int(t, 16) * (-1 if t[0] == '-' else 1) for t in re.findall(r'[+-][0-9a-fA-Fx]+', rest)) if rest else 0)) & 0xFFFFFFFF
        return int(expr, 16)

    def read_raw(self, addr, size):
        return struct.unpack(f'<{UINT[size]}', self._call(bytes([READ_OP[size]]) + struct.pack('<I', addr)))[0]

    def read(self, addr, typ='u32', count=1):
        addr = self.resolve(addr) if isinstance(addr, str) else addr
        size, fmt = TYPES[typ]
        out = []
        for i in range(0, count, BATCH):
            n = min(BATCH, count - i)
            body = b''.join(bytes([READ_OP[size]]) + struct.pack('<I', addr + (i + k) * size) for k in range(n))
            raw = struct.unpack(f'<{n}{UINT[size]}', self._call(body))
            out += [struct.unpack(f'<{fmt}', struct.pack(f'<{UINT[size]}', v))[0] for v in raw]
        return out[0] if count == 1 else out

    def write(self, addr, typ, *values):
        addr = self.resolve(addr) if isinstance(addr, str) else addr
        size, fmt = TYPES[typ]
        body = b''.join(bytes([WRITE_OP[size]]) + struct.pack('<I', addr + k * size) +
                        struct.pack(f'<{UINT[size]}', struct.unpack(f'<{UINT[size]}', struct.pack(f'<{fmt}', v))[0])
                        for k, v in enumerate(values))
        self._call(body)

    def dump(self, addr, length):
        """Big-endian bytes as in PS3 memory, and the list of unmapped 4 KB pages (zero-filled)."""
        addr = self.resolve(addr) if isinstance(addr, str) else addr
        out, missing = bytearray(), []

        def block(a, n):  # n is a multiple of 8
            body = b''.join(bytes([3]) + struct.pack('<I', a + k * 8) for k in range(n // 8))
            return b''.join(struct.pack('>Q', v) for v in struct.unpack(f'<{n // 8}Q', self._call(body)))

        pos, end = addr, addr + length
        while pos < end:
            n = min(BATCH * 8, end - pos)
            n8 = (n + 7) & ~7
            try:
                out += block(pos, n8)[:n]
            except PineError:
                for p in range(pos, pos + n, 4096):  # retry page by page
                    m = min(4096, pos + n - p)
                    try:
                        out += block(p, (m + 7) & ~7)[:m]
                    except PineError:
                        out += bytes(m)
                        missing.append(p)
            pos += n
        return bytes(out), missing


def parse_value(typ, text):
    return float(text) if typ[0] == 'f' else int(text, 0)


def fmt_value(typ, v):
    if typ[0] == 'f':
        return f'{v:.6g}'
    size = TYPES[typ][0]
    return f'{v} (0x{v & ((1 << size * 8) - 1):0{size * 2}x})'


def main(argv):
    if not argv:
        sys.exit(__doc__)
    cmd, args = argv[0], argv[1:]
    p = Pine()
    if cmd == 'info':
        for k, v in p.info().items():
            print(f'{k}: {v}')
    elif cmd == 'read':
        addr = p.resolve(args[0])
        typ = args[1] if len(args) > 1 else 'u32'
        count = int(args[2], 0) if len(args) > 2 else 1
        vals = p.read(addr, typ, count)
        for i, v in enumerate(vals if count > 1 else [vals]):
            print(f'{addr + i * TYPES[typ][0]:08x}: {fmt_value(typ, v)}')
    elif cmd == 'write':
        addr, typ = p.resolve(args[0]), args[1]
        vals = [parse_value(typ, t) for t in args[2:]]
        old = p.read(addr, typ, len(vals))
        p.write(addr, typ, *vals)
        new = p.read(addr, typ, len(vals))
        for i, (o, n) in enumerate(zip(old if len(vals) > 1 else [old], new if len(vals) > 1 else [new])):
            print(f'{addr + i * TYPES[typ][0]:08x}: {fmt_value(typ, o)} -> {fmt_value(typ, n)}')
    elif cmd == 'dump':
        addr, length, path = p.resolve(args[0]), int(args[1], 0), args[2]
        t = time.perf_counter()
        data, missing = p.dump(addr, length)
        open(path, 'wb').write(data)
        print(f'{addr:08x}+{length:#x} -> {path} ({time.perf_counter() - t:.2f} s)')
        if missing:
            print(f'unmapped (zero-filled): {len(missing)} pages, first {", ".join(f"{m:08x}" for m in missing[:8])}')
    elif cmd == 'find':
        addr, length, typ = p.resolve(args[0]), int(args[1], 0), args[2]
        target = parse_value(typ, args[3])
        tol = float(args[4]) if len(args) > 4 else 1e-4
        size, fmt = TYPES[typ]
        data, _ = p.dump(addr, length)
        n = len(data) // size
        vals = struct.unpack(f'>{n}{fmt}', data[:n * size])
        hits = [i for i, v in enumerate(vals) if (abs(v - target) <= tol if typ[0] == 'f' else v == target)]
        for i in hits[:200]:
            print(f'{addr + i * size:08x}: {fmt_value(typ, vals[i])}')
        print(f'{len(hits)} matches' + (' (first 200 shown)' if len(hits) > 200 else ''))
    elif cmd == 'watch':
        ms, dur, specs = 50, None, []
        it = iter(args)
        for a in it:
            if a == '--ms':
                ms = int(next(it))
            elif a == '--for':
                dur = float(next(it))
            else:
                expr, _, typ = a.partition(':')
                specs.append((a, p.resolve(expr), typ or 'u32'))
        last, t0 = {}, time.perf_counter()
        while dur is None or time.perf_counter() - t0 < dur:
            for name, addr, typ in specs:
                v = p.read(addr, typ)
                if last.get(name) != v:
                    print(f'{time.perf_counter() - t0:8.3f} {name} {fmt_value(typ, v)}', flush=True)
                    last[name] = v
            time.sleep(ms / 1000)
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    try:
        main(sys.argv[1:])
    except PineError as e:
        sys.exit(f'pine: {e}')
    except KeyboardInterrupt:
        pass
