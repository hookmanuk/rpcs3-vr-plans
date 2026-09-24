param([string]$Keys = '', [string]$Shot = '', [int]$GapMs = 600)
# Focus RPCS3's game window, press keys (comma-separated), optionally save a DPI-aware screenshot.
Add-Type @'
using System; using System.Text; using System.Runtime.InteropServices;
public static class W {
	[DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
	public delegate bool EnumProc(IntPtr h, IntPtr p);
	[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr p);
	[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
	[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
	[DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
	[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
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
		if ($sb.ToString() -match 'FPS|WipEout|BCES00664') { $script:game = $h }
	}
	return $true }, [IntPtr]::Zero) | Out-Null
if ($script:game -eq [IntPtr]::Zero) { throw 'RPCS3 game window not found' }
[W]::ShowWindow($script:game, 9) | Out-Null
[W]::SetForegroundWindow($script:game) | Out-Null
Start-Sleep -Milliseconds 300

$vk = @{ Left = 0x25; Up = 0x26; Right = 0x27; Down = 0x28; Return = 0x0D; Space = 0x20; Backspace = 0x08 }
foreach ($k in ($Keys -split ',' | Where-Object { $_ })) {
	$code = if ($vk.ContainsKey($k)) { $vk[$k] } else { [byte][char]$k.ToUpper() }
	$ext = if ($code -ge 0x25 -and $code -le 0x28) { 1 } else { 0 }
	$scan = [byte][W]::MapVirtualKey($code, 0)
	[W]::keybd_event($code, $scan, $ext, [UIntPtr]::Zero)
	Start-Sleep -Milliseconds 120
	[W]::keybd_event($code, $scan, $ext -bor 2, [UIntPtr]::Zero)
	Start-Sleep -Milliseconds $GapMs
}

if ($Shot) {
	Add-Type -AssemblyName System.Drawing
	$b = New-Object Drawing.Bitmap 1920, 1200; $g = [Drawing.Graphics]::FromImage($b)
	$g.CopyFromScreen(0, 0, 0, 0, $b.Size)
	$small = New-Object Drawing.Bitmap $b, 960, 600
	$small.Save($Shot); $g.Dispose(); $b.Dispose(); $small.Dispose()
}
