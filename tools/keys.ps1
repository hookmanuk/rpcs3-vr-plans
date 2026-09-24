param([string]$Keys = '', [string]$Shot = '', [int]$GapMs = 600, [int]$HoldMs = 120)
# Focus RPCS3's game window, press keys (comma-separated; "W+X" = hold together), optionally save a DPI-aware client capture.
Add-Type @'
using System; using System.Text; using System.Runtime.InteropServices;
public static class W {
	[StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
	[StructLayout(LayoutKind.Sequential)] public struct PT { public int X, Y; }
	[DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
	public delegate bool EnumProc(IntPtr h, IntPtr p);
	[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr p);
	[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
	[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
	[DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
	[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
	[DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
	[DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref PT p);
	[DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
	[DllImport("user32.dll")] public static extern uint MapVirtualKey(uint code, uint type);
}
'@
[W]::SetProcessDpiAwarenessContext([IntPtr]-4) | Out-Null
$rp = Get-Process rpcs3 -ErrorAction Stop | Select-Object -First 1
$script:game = [IntPtr]::Zero
[W]::EnumWindows({ param($h, $p)
	$id = 0; [W]::GetWindowThreadProcessId($h, [ref]$id) | Out-Null
	if ($id -eq $rp.Id -and [W]::IsWindowVisible($h)) {
		$sb = New-Object Text.StringBuilder 256; [W]::GetWindowText($h, $sb, 256) | Out-Null
		if ($sb.ToString() -match '^FPS') { $script:game = $h }
	}
	return $true }, [IntPtr]::Zero) | Out-Null
if ($script:game -eq [IntPtr]::Zero) { throw 'RPCS3 game window not found' }
[W]::ShowWindow($script:game, 9) | Out-Null
[W]::SetForegroundWindow($script:game) | Out-Null
Start-Sleep -Milliseconds 300

$vk = @{ Left = 0x25; Up = 0x26; Right = 0x27; Down = 0x28; Enter = 0x0D; Return = 0x0D; Space = 0x20; Backspace = 0x08; F12 = 0x7B; F10 = 0x79; Shift = 0x10; Escape = 0x1B }
function Code($k) { if ($vk.ContainsKey($k)) { $vk[$k] } else { [byte][char]$k.ToUpper() } }
foreach ($chord in ($Keys -split ',' | Where-Object { $_ })) {
	$codes = @($chord -split '\+' | ForEach-Object { Code $_ })
	foreach ($c in $codes) { $ext = if ($c -ge 0x25 -and $c -le 0x28) { 1 } else { 0 }; [W]::keybd_event($c, [byte][W]::MapVirtualKey($c, 0), $ext, [UIntPtr]::Zero) }
	Start-Sleep -Milliseconds $HoldMs
	foreach ($c in $codes) { $ext = if ($c -ge 0x25 -and $c -le 0x28) { 1 } else { 0 }; [W]::keybd_event($c, [byte][W]::MapVirtualKey($c, 0), $ext -bor 2, [UIntPtr]::Zero) }
	Start-Sleep -Milliseconds $GapMs
}

if ($Shot) {
	Add-Type -AssemblyName System.Drawing
	$r = New-Object W+RECT; [W]::GetClientRect($script:game, [ref]$r) | Out-Null
	$p = New-Object W+PT; [W]::ClientToScreen($script:game, [ref]$p) | Out-Null
	$b = New-Object Drawing.Bitmap $r.R, $r.B; $g = [Drawing.Graphics]::FromImage($b)
	$g.CopyFromScreen($p.X, $p.Y, 0, 0, $b.Size)
	$b.Save($Shot); $g.Dispose(); $b.Dispose()
	"shot $($r.R)x$($r.B) -> $Shot"
}
