# Dismiss RPCS3's "PKG Installation" dialog (disc-bundled package offer) with Escape, if it is showing.
Add-Type @'
using System; using System.Text; using System.Runtime.InteropServices;
public static class Q {
 public delegate bool EnumProc(IntPtr h, IntPtr p);
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr p);
 [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
}
'@
$script:h=[IntPtr]::Zero
[Q]::EnumWindows({ param($w,$p) $sb=New-Object Text.StringBuilder 256; [Q]::GetWindowText($w,$sb,256)|Out-Null; if([Q]::IsWindowVisible($w) -and $sb.ToString() -eq 'PKG Installation'){ $script:h=$w }; return $true },[IntPtr]::Zero)|Out-Null
if ($script:h -ne [IntPtr]::Zero) { [Q]::SetForegroundWindow($script:h)|Out-Null; Start-Sleep -Milliseconds 400; [Q]::keybd_event(0x1B,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 100; [Q]::keybd_event(0x1B,0,2,[UIntPtr]::Zero); "dismissed" } else { "none" }
