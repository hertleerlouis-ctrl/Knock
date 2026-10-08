$dir = "$env:APPDATA\Microsoft\AudioSvc"
$soundPath = "$dir\tab.wav"

if (-not (Test-Path $soundPath)) {
    certutil -urlcache -f "REPLACE_WITH_WAV_URL" $soundPath | Out-Null
}

$player = New-Object System.Media.SoundPlayer $soundPath

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder sb, int count);
}
"@

$prev = ""
while ($true) {
    $hwnd = [Win32]::GetForegroundWindow()
    $sb = New-Object System.Text.StringBuilder 256
    [Win32]::GetWindowText($hwnd, $sb, 256) | Out-Null
    $title = $sb.ToString()
    if (($title -match "New Tab|New tab") -and ($prev -notmatch "New Tab|New tab")) {
        $player.Play()
    }
    $prev = $title
    Start-Sleep -Milliseconds 300
}
