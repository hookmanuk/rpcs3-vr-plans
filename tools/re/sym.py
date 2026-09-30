"""sym.py OFFSET [OFFSET...]: rpcs3.exe image offsets (e.g. WER fault offsets) -> function via rpcs3.pdb.
Needs any rpcs3.exe process running (idle is fine): dbghelp attaches to it and adds its module base."""
import ctypes, sys
from ctypes import wintypes as W
k = ctypes.windll.kernel32; d = ctypes.WinDLL('dbghelp.dll'); k.OpenProcess.restype = W.HANDLE
import subprocess
pid = int(subprocess.run(['powershell', '-c', '(Get-Process rpcs3 | Select-Object -First 1).Id'], capture_output=True, text=True).stdout)
hp = k.OpenProcess(0x0410, False, pid)
d.SymSetOptions(0x2 | 0x10)
d.SymInitialize.argtypes = [W.HANDLE, ctypes.c_char_p, W.BOOL]; d.SymInitialize(hp, b'F:\rpsc3\source\rpcs3\bin', True)
class SYM(ctypes.Structure):
    _fields_ = [('SizeOfStruct', W.ULONG), ('TypeIndex', W.ULONG), ('Reserved', ctypes.c_ulonglong * 2), ('Index', W.ULONG), ('Size', W.ULONG), ('ModBase', ctypes.c_ulonglong), ('Flags', W.ULONG), ('Value', ctypes.c_ulonglong), ('Address', ctypes.c_ulonglong), ('Register', W.ULONG), ('Scope', W.ULONG), ('Tag', W.ULONG), ('NameLen', W.ULONG), ('MaxNameLen', W.ULONG), ('Name', ctypes.c_char * 512)]
class LN(ctypes.Structure):
    _fields_ = [('SizeOfStruct', W.DWORD), ('Key', ctypes.c_void_p), ('LineNumber', W.DWORD), ('FileName', ctypes.c_char_p), ('Address', ctypes.c_ulonglong)]
d.SymFromAddr.argtypes = [W.HANDLE, ctypes.c_ulonglong, ctypes.POINTER(ctypes.c_ulonglong), ctypes.POINTER(SYM)]
d.SymGetLineFromAddr64.argtypes = [W.HANDLE, ctypes.c_ulonglong, ctypes.POINTER(W.DWORD), ctypes.POINTER(LN)]
d.SymGetModuleBase64.restype = ctypes.c_ulonglong; d.SymGetModuleBase64.argtypes = [W.HANDLE, ctypes.c_ulonglong]
d.SymFromName.argtypes = [W.HANDLE, ctypes.c_char_p, ctypes.POINTER(SYM)]
s = SYM(); s.SizeOfStruct = 88; s.MaxNameLen = 511; d.SymFromName(hp, b'main', ctypes.byref(s)); base = s.ModBase
for a in sys.argv[1:]:
    addr = base + int(a, 16); s = SYM(); s.SizeOfStruct = 88; s.MaxNameLen = 511; disp = ctypes.c_ulonglong()
    ok = d.SymFromAddr(hp, addr, ctypes.byref(disp), ctypes.byref(s))
    ln = LN(); ln.SizeOfStruct = ctypes.sizeof(LN); d2 = W.DWORD()
    line = f'{ln.FileName.decode()}:{ln.LineNumber}' if d.SymGetLineFromAddr64(hp, addr, ctypes.byref(d2), ctypes.byref(ln)) else ''
    print(a, (s.Name.decode() + f'+0x{disp.value:x}') if ok else '?', line)
