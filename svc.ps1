# ── CONFIG ───────────────────────────────────────────────────────────────────
$TargetDevice = "Realtek"   # Partial match on device friendly name. "" to skip.
$TargetVolume = 0.70           # 0.0 - 1.0
$RuntimeHours = 1
$WavUrl       = "https://raw.githubusercontent.com/hertleerlouis/Knock/main/door-knock.wav"
# ─────────────────────────────────────────────────────────────────────────────

$dir       = "$env:APPDATA\Microsoft\AudioSvc"
$soundPath = "$dir\tab.wav"

if (-not (Test-Path $soundPath)) {
    certutil -urlcache -f $WavUrl $soundPath | Out-Null
}

Add-Type @"
using System;
using System.Runtime.InteropServices;

[ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IMMDeviceEnumerator {
    [PreserveSig] int EnumAudioEndpoints(int dataFlow, int dwStateMask, out IMMDeviceCollection ppDevices);
    [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice ppEndpoint);
    [PreserveSig] int GetDevice([MarshalAs(UnmanagedType.LPWStr)] string id, out IMMDevice ppDevice);
    [PreserveSig] int RegisterEndpointNotificationCallback(IntPtr p);
    [PreserveSig] int UnregisterEndpointNotificationCallback(IntPtr p);
}

[ComImport, Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IMMDeviceCollection {
    [PreserveSig] int GetCount(out uint count);
    [PreserveSig] int Item(uint n, out IMMDevice ppDevice);
}

[ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IMMDevice {
    [PreserveSig] int Activate(ref Guid iid, int clsCtx, IntPtr pParams, [MarshalAs(UnmanagedType.IUnknown)] out object ppInterface);
    [PreserveSig] int OpenPropertyStore(int access, out IPropertyStore ppStore);
    [PreserveSig] int GetId([MarshalAs(UnmanagedType.LPWStr)] out string ppstrId);
    [PreserveSig] int GetState(out int pdwState);
}

[ComImport, Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IPropertyStore {
    [PreserveSig] int GetCount(out uint cProps);
    [PreserveSig] int GetAt(uint iProp, out PropertyKey pkey);
    [PreserveSig] int GetValue(ref PropertyKey key, out PropVariant pv);
    [PreserveSig] int SetValue(ref PropertyKey key, ref PropVariant pv);
    [PreserveSig] int Commit();
}

[StructLayout(LayoutKind.Sequential)]
public struct PropertyKey { public Guid fmtid; public uint pid; }

[StructLayout(LayoutKind.Explicit)]
public struct PropVariant {
    [FieldOffset(0)] public ushort vt;
    [FieldOffset(8)] public IntPtr p;
    public string ToStr() { return vt == 31 ? Marshal.PtrToStringUni(p) : string.Empty; }
}

[ComImport, Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IAudioEndpointVolume {
    [PreserveSig] int RegisterControlChangeNotify(IntPtr p);
    [PreserveSig] int UnregisterControlChangeNotify(IntPtr p);
    [PreserveSig] int GetChannelCount(out uint c);
    [PreserveSig] int SetMasterVolumeLevel(float f, ref Guid g);
    [PreserveSig] int SetMasterVolumeLevelScalar(float f, ref Guid g);
    [PreserveSig] int GetMasterVolumeLevel(out float f);
    [PreserveSig] int GetMasterVolumeLevelScalar(out float f);
    [PreserveSig] int SetChannelVolumeLevel(uint c, float f, ref Guid g);
    [PreserveSig] int SetChannelVolumeLevelScalar(uint c, float f, ref Guid g);
    [PreserveSig] int GetChannelVolumeLevel(uint c, out float f);
    [PreserveSig] int GetChannelVolumeLevelScalar(uint c, out float f);
    [PreserveSig] int SetMute([MarshalAs(UnmanagedType.Bool)] bool b, ref Guid g);
    [PreserveSig] int GetMute([MarshalAs(UnmanagedType.Bool)] out bool b);
    [PreserveSig] int GetVolumeStepInfo(out uint step, out uint count);
    [PreserveSig] int VolumeStepUp(ref Guid g);
    [PreserveSig] int VolumeStepDown(ref Guid g);
    [PreserveSig] int QueryHardwareSupport(out uint mask);
    [PreserveSig] int GetVolumeRange(out float min, out float max, out float inc);
}

[ComImport, Guid("f8679f50-850a-41cf-9c72-430f290290c8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IPolicyConfig {
    [PreserveSig] int GetMixFormat(string dev, IntPtr fmt);
    [PreserveSig] int GetDeviceFormat(string dev, bool def, IntPtr fmt);
    [PreserveSig] int ResetDeviceFormat(string dev);
    [PreserveSig] int SetDeviceFormat(string dev, IntPtr efmt, IntPtr mfmt);
    [PreserveSig] int GetProcessingPeriod(string dev, bool def, IntPtr d, IntPtr m);
    [PreserveSig] int SetProcessingPeriod(string dev, IntPtr period);
    [PreserveSig] int GetShareMode(string dev, IntPtr mode);
    [PreserveSig] int SetShareMode(string dev, IntPtr mode);
    [PreserveSig] int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string devId, uint role);
    [PreserveSig] int SetEndpointVisibility(string dev, bool vis);
}

[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
public class MMDeviceEnumerator {}

[ComImport, Guid("870af99c-171d-4f9e-af0d-e63df40c2bc9")]
public class PolicyConfigClient {}

public class Win32 {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder sb, int count);
}

public class AudioHelper {
    static readonly Guid IID_IAudioEndpointVolume = new Guid("5CDF2C82-841E-4546-9722-0CF74078229A");
    static readonly PropertyKey PKEY_FriendlyName  = new PropertyKey {
        fmtid = new Guid("a45c254e-df1c-4efd-8020-67d146a850e0"), pid = 14
    };

    static IMMDeviceEnumerator Enum() { return (IMMDeviceEnumerator) new MMDeviceEnumerator(); }

    static string GetFriendlyName(IMMDevice dev) {
        IPropertyStore store; dev.OpenPropertyStore(0, out store);
        var key = PKEY_FriendlyName; PropVariant pv;
        store.GetValue(ref key, out pv);
        return pv.ToStr();
    }

    public static string[] ListDevices() {
        IMMDeviceCollection col; Enum().EnumAudioEndpoints(0, 1, out col);
        uint count; col.GetCount(out count);
        var names = new string[count];
        for (uint i = 0; i < count; i++) { IMMDevice d; col.Item(i, out d); names[i] = GetFriendlyName(d); }
        return names;
    }

    public static void SetDefaultDevice(string partialName) {
        IMMDeviceCollection col; Enum().EnumAudioEndpoints(0, 1, out col);
        uint count; col.GetCount(out count);
        for (uint i = 0; i < count; i++) {
            IMMDevice dev; col.Item(i, out dev);
            if (GetFriendlyName(dev).IndexOf(partialName, StringComparison.OrdinalIgnoreCase) >= 0) {
                string id; dev.GetId(out id);
                var policy = (IPolicyConfig) new PolicyConfigClient();
                policy.SetDefaultEndpoint(id, 0);
                policy.SetDefaultEndpoint(id, 1);
                policy.SetDefaultEndpoint(id, 2);
                return;
            }
        }
    }

    public static void UnmuteAndSetVolume(float volume) {
        IMMDevice dev; Enum().GetDefaultAudioEndpoint(0, 1, out dev);
        object vol; var guid = IID_IAudioEndpointVolume;
        dev.Activate(ref guid, 23, IntPtr.Zero, out vol);
        var ep = (IAudioEndpointVolume) vol; var empty = Guid.Empty;
        ep.SetMute(false, ref empty);
        ep.SetMasterVolumeLevelScalar(volume, ref empty);
    }
}
"@

# Dump available device names so you can verify the right partial name
[AudioHelper]::ListDevices() | Out-File "$dir\devices.log"

# Switch output device
if ($TargetDevice) {
    [AudioHelper]::SetDefaultDevice($TargetDevice)
    Start-Sleep -Milliseconds 500
}

# Unmute and set volume on the (now active) default device
[AudioHelper]::UnmuteAndSetVolume($TargetVolume)

# Monitor loop
$player   = New-Object System.Media.SoundPlayer $soundPath
$deadline = (Get-Date).AddHours($RuntimeHours)
$prev     = ""

while ((Get-Date) -lt $deadline) {
    $sb = New-Object System.Text.StringBuilder 256
    [Win32]::GetWindowText([Win32]::GetForegroundWindow(), $sb, 256) | Out-Null
    $title = $sb.ToString()
    if (($title -match "New Tab|New tab") -and ($prev -notmatch "New Tab|New tab")) {
        $player.Play()
    }
    $prev = $title
    Start-Sleep -Milliseconds 300
}

# Self-cleanup after runtime expires
Remove-Item -Recurse -Force $dir 2>$null
