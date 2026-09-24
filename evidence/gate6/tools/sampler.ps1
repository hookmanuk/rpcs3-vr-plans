param([int]$Seconds = 6, [string]$ThreadPrefix = 'RSX', [int]$Top = 40)
# Minimal sampling profiler: suspends one named thread of rpcs3.exe ~1000x/s, walks its stack
# with dbghelp, and reports the most common inclusive frames (and the leaf "self" frames).
$src = @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public static class Sampler
{
	[StructLayout(LayoutKind.Sequential, Pack = 16)]
	public struct CONTEXT64
	{
		public ulong P1Home, P2Home, P3Home, P4Home, P5Home, P6Home;
		public uint ContextFlags, MxCsr;
		public ushort SegCs, SegDs, SegEs, SegFs, SegGs, SegSs;
		public uint EFlags;
		public ulong Dr0, Dr1, Dr2, Dr3, Dr6, Dr7;
		public ulong Rax, Rcx, Rdx, Rbx, Rsp, Rbp, Rsi, Rdi, R8, R9, R10, R11, R12, R13, R14, R15, Rip;
		[MarshalAs(UnmanagedType.ByValArray, SizeConst = 512)] public byte[] FltSave;
		[MarshalAs(UnmanagedType.ByValArray, SizeConst = 416)] public byte[] VectorRegister;
		public ulong VectorControl, DebugControl, LastBranchToRip, LastBranchFromRip, LastExceptionToRip, LastExceptionFromRip;
	}

	[StructLayout(LayoutKind.Sequential)]
	public struct ADDRESS64 { public ulong Offset; public ushort Segment; public uint Mode; }

	[StructLayout(LayoutKind.Sequential)]
	public struct STACKFRAME64
	{
		public ADDRESS64 AddrPC, AddrReturn, AddrFrame, AddrStack, AddrBStore;
		public IntPtr FuncTableEntry;
		[MarshalAs(UnmanagedType.ByValArray, SizeConst = 4)] public ulong[] Params;
		public bool Far, Virtual;
		[MarshalAs(UnmanagedType.ByValArray, SizeConst = 3)] public ulong[] Reserved;
		public ulong KdHelp0, KdHelp1, KdHelp2, KdHelp3, KdHelp4, KdHelp5, KdHelp6, KdHelp7, KdHelp8, KdHelp9, KdHelp10, KdHelp11, KdHelp12, KdHelp13, KdHelp14, KdHelp15;
	}

	[DllImport("kernel32.dll")] static extern IntPtr OpenThread(uint access, bool inherit, uint id);
	[DllImport("kernel32.dll")] static extern IntPtr OpenProcess(uint access, bool inherit, uint id);
	[DllImport("kernel32.dll")] static extern uint SuspendThread(IntPtr h);
	[DllImport("kernel32.dll")] static extern uint ResumeThread(IntPtr h);
	[DllImport("kernel32.dll")] static extern bool GetThreadContext(IntPtr h, IntPtr ctx);
	[DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
	[DllImport("kernel32.dll")] static extern int GetThreadDescription(IntPtr h, out IntPtr desc);
	[DllImport("kernel32.dll")] static extern IntPtr LocalFree(IntPtr p);
	[DllImport("dbghelp.dll", SetLastError = true)] static extern bool SymInitializeW(IntPtr proc, [MarshalAs(UnmanagedType.LPWStr)] string path, bool invade);
	[DllImport("dbghelp.dll")] static extern uint SymSetOptions(uint opts);
	[DllImport("dbghelp.dll")] static extern bool StackWalk64(uint machine, IntPtr proc, IntPtr thread, ref STACKFRAME64 frame, IntPtr ctx, IntPtr readMem, IntPtr funcTable, IntPtr moduleBase, IntPtr translate);
	[DllImport("dbghelp.dll")] static extern IntPtr SymFunctionTableAccess64(IntPtr proc, ulong addr);
	[DllImport("dbghelp.dll")] static extern ulong SymGetModuleBase64(IntPtr proc, ulong addr);
	[DllImport("dbghelp.dll", CharSet = CharSet.Unicode)] static extern bool SymFromAddrW(IntPtr proc, ulong addr, out ulong disp, IntPtr symbol);
	[DllImport("dbghelp.dll", CharSet = CharSet.Unicode)] static extern bool SymGetModuleInfoW64(IntPtr proc, ulong addr, IntPtr info);
	[DllImport("dbghelp.dll")] static extern bool SymRefreshModuleList(IntPtr proc);

	delegate IntPtr FuncTableDelegate(IntPtr proc, ulong addr);
	delegate ulong ModuleBaseDelegate(IntPtr proc, ulong addr);
	static FuncTableDelegate s_ft = SymFunctionTableAccess64;
	static ModuleBaseDelegate s_mb = SymGetModuleBase64;

	static Dictionary<ulong, string> s_names = new Dictionary<ulong, string>();
	static IntPtr s_proc;

	static string Name(ulong addr)
	{
		string n;
		if (s_names.TryGetValue(addr, out n)) return n;
		IntPtr sym = Marshal.AllocHGlobal(8 + 88 + 2000 * 2);
		try
		{
			for (int i = 0; i < 88; i++) Marshal.WriteByte(sym, i, 0);
			Marshal.WriteInt32(sym, 0, 88);          // SizeOfStruct (SYMBOL_INFOW without name)
			Marshal.WriteInt32(sym, 80, 2000);       // MaxNameLen
			ulong disp;
			if (SymFromAddrW(s_proc, addr, out disp, sym))
			{
				n = Marshal.PtrToStringUni(sym + 84);
			}
			else
			{
				ulong mb = SymGetModuleBase64(s_proc, addr);
				n = mb != 0 ? string.Format("module+{0:x}", addr - mb) : string.Format("0x{0:x}", addr);
			}
		}
		finally { Marshal.FreeHGlobal(sym); }
		s_names[addr] = n;
		return n;
	}

	public static string Run(int pid, string prefix, int seconds, int top)
	{
		s_proc = OpenProcess(0x1F0FFF, false, (uint)pid);
		SymSetOptions(0x00000002 | 0x00000004 | 0x00000010 | 0x00080000); // UNDNAME|DEFERRED_LOADS|LOAD_LINES off|NO_PROMPTS
		if (!SymInitializeW(s_proc, @"F:\rpsc3\source\rpcs3\bin", true)) return "SymInitialize failed " + Marshal.GetLastWin32Error();

		uint tid = 0; string tname = "";
		foreach (ProcessThread t in Process.GetProcessById(pid).Threads)
		{
			IntPtr h = OpenThread(0x0040 | 0x0800, false, (uint)t.Id);
			IntPtr d;
			if (h != IntPtr.Zero && GetThreadDescription(h, out d) >= 0)
			{
				string s = Marshal.PtrToStringUni(d); LocalFree(d);
				if (s != null && s.StartsWith(prefix)) { tid = (uint)t.Id; tname = s; }
			}
			if (h != IntPtr.Zero) CloseHandle(h);
		}
		if (tid == 0) return "thread not found";

		IntPtr th = OpenThread(0x0002 | 0x0008 | 0x0010 | 0x0040, false, tid);
		IntPtr ctx = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(CONTEXT64)) + 16);
		IntPtr actx = new IntPtr((ctx.ToInt64() + 15) & ~15L);

		var incl = new Dictionary<string, int>();
		var self = new Dictionary<string, int>();
		var addrs = new List<ulong[]>();
		int samples = 0;
		var sw = Stopwatch.StartNew();
		while (sw.Elapsed.TotalSeconds < seconds)
		{
			if (SuspendThread(th) == 0xFFFFFFFF) break;
			for (int i = 0; i < Marshal.SizeOf(typeof(CONTEXT64)); i += 8) Marshal.WriteInt64(actx, i, 0);
			Marshal.WriteInt32(actx, 0x30, 0x10000B); // CONTEXT_FULL (AMD64)
			var frames = new List<ulong>();
			if (GetThreadContext(th, actx))
			{
				var c = (CONTEXT64)Marshal.PtrToStructure(actx, typeof(CONTEXT64));
				var f = new STACKFRAME64();
				f.AddrPC.Offset = c.Rip; f.AddrPC.Mode = 3;
				f.AddrFrame.Offset = c.Rbp; f.AddrFrame.Mode = 3;
				f.AddrStack.Offset = c.Rsp; f.AddrStack.Mode = 3;
				f.Params = new ulong[4]; f.Reserved = new ulong[3];
				for (int depth = 0; depth < 48; depth++)
				{
					if (!StackWalk64(0x8664, s_proc, th, ref f, actx, IntPtr.Zero,
						Marshal.GetFunctionPointerForDelegate(s_ft), Marshal.GetFunctionPointerForDelegate(s_mb), IntPtr.Zero)) break;
					if (f.AddrPC.Offset == 0) break;
					frames.Add(f.AddrPC.Offset);
				}
			}
			ResumeThread(th);
			if (frames.Count > 0) { addrs.Add(frames.ToArray()); samples++; }
			Thread.Sleep(1);
		}

		foreach (var st in addrs)
		{
			var seen = new HashSet<string>();
			for (int i = 0; i < st.Length; i++)
			{
				string n = Name(st[i]);
				if (i == 0) { int v; self.TryGetValue(n, out v); self[n] = v + 1; }
				if (seen.Add(n)) { int v; incl.TryGetValue(n, out v); incl[n] = v + 1; }
			}
		}

		var sb = new StringBuilder();
		sb.AppendFormat("thread {0} ({1}), {2} samples over {3}s\n", tname, tid, samples, seconds);
		sb.AppendLine("--- inclusive ---");
		var li = new List<KeyValuePair<string, int>>(incl); li.Sort((a, b) => b.Value.CompareTo(a.Value));
		for (int i = 0; i < Math.Min(top, li.Count); i++) sb.AppendFormat("{0,5:F1}%  {1}\n", 100.0 * li[i].Value / samples, li[i].Key);
		sb.AppendLine("--- self (leaf) ---");
		var ls = new List<KeyValuePair<string, int>>(self); ls.Sort((a, b) => b.Value.CompareTo(a.Value));
		for (int i = 0; i < Math.Min(25, ls.Count); i++) sb.AppendFormat("{0,5:F1}%  {1}\n", 100.0 * ls[i].Value / samples, ls[i].Key);
		return sb.ToString();
	}
}
'@
if (-not ([System.Management.Automation.PSTypeName]'Sampler').Type) { Add-Type -TypeDefinition $src -Language CSharp }
$p = Get-Process rpcs3 -ErrorAction Stop | Select-Object -First 1
[Sampler]::Run($p.Id, $ThreadPrefix, $Seconds, $Top)
