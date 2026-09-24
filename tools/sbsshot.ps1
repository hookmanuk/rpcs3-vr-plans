param([string]$Out)
# Resize RPCS3's game window so the side-by-side eyes fit on screen, then capture its client area.
Add-Type @'
using System; using System.Text; using System.Runtime.InteropServices;
public static class G {
	[DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
	public delegate bool EnumProc(IntPtr h, IntPtr p);
	[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr p);
	[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
	[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
	[DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
	[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int hh, uint f);
	[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
	[StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
	[StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
	[DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
	[DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
}
'@
[G]::SetProcessDpiAwarenessContext([IntPtr]-4) | Out-Null
$rp = Get-Process rpcs3 -ErrorAction Stop | Select-Object -First 1
$script:game = [IntPtr]::Zero
[G]::EnumWindows({ param($h, $p)
	$id = 0; [G]::GetWindowThreadProcessId($h, [ref]$id) | Out-Null
	if ($id -eq $rp.Id -and [G]::IsWindowVisible($h)) {
		$sb = New-Object Text.StringBuilder 256; [G]::GetWindowText($h, $sb, 256) | Out-Null
		if ($sb.ToString() -match 'FPS') { $script:game = $h }
	}
	return $true }, [IntPtr]::Zero) | Out-Null
if ($script:game -eq [IntPtr]::Zero) { throw 'game window not found' }
[G]::ShowWindow($script:game, 1) | Out-Null   # restore from maximized
[G]::SetWindowPos($script:game, [IntPtr]::Zero, 40, 80, 1860, 600, 0x0040) | Out-Null
[G]::SetForegroundWindow($script:game) | Out-Null
Start-Sleep -Milliseconds 1500
$r = New-Object G+RECT; [G]::GetClientRect($script:game, [ref]$r) | Out-Null
$pt = New-Object G+POINT; [G]::ClientToScreen($script:game, [ref]$pt) | Out-Null
Add-Type -AssemblyName System.Drawing
$w = $r.R - $r.L; $h = $r.B - $r.T
$b = New-Object Drawing.Bitmap $w, $h; $g = [Drawing.Graphics]::FromImage($b)
$g.CopyFromScreen($pt.X, $pt.Y, 0, 0, $b.Size); $b.Save($Out); $g.Dispose(); $b.Dispose()
"client ${w}x${h} saved $Out"
