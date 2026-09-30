# Print the RPCS3 game window title (FPS) every second for N samples.
param([int]$N = 5)
Add-Type @'
using System; using System.Text; using System.Runtime.InteropServices;
public static class WT {
	public delegate bool EnumProc(IntPtr h, IntPtr p);
	[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr p);
	[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
	[DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
}
'@
$rp = (Get-Process rpcs3 | Select-Object -First 1).Id
for ($i = 0; $i -lt $N; $i++) {
	$script:t = ''
	[WT]::EnumWindows({ param($h, $p) $id = 0; [WT]::GetWindowThreadProcessId($h, [ref]$id) | Out-Null
		if ($id -eq $rp) { $sb = New-Object Text.StringBuilder 256; [WT]::GetWindowText($h, $sb, 256) | Out-Null; if ($sb.ToString() -match '^FPS') { $script:t = $sb.ToString() } }
		return $true }, [IntPtr]::Zero) | Out-Null
	($script:t -split ' \| ')[0]
	Start-Sleep 1
}
