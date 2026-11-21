$ErrorActionPreference = 'Stop'
if (-not ('XInputTest' -as [type])) {
Add-Type @'
using System.Runtime.InteropServices;
public class XInputTest {
    [StructLayout(LayoutKind.Sequential)]
    public struct State {
        public uint Packet;
        public ushort Buttons;
        public byte LT, RT;
        public short LX, LY, RX, RY;
    }
    [DllImport("xinput1_4.dll")]
    public static extern uint XInputGetState(uint index, out State state);
}
'@
}
Get-PnpDevice -PresentOnly | Where-Object {
    $_.InstanceId -match 'VID_045E|VID_057E|VID_2DC8'
} | Format-Table Status,FriendlyName,InstanceId -AutoSize
for ($i = 0; $i -lt 4; $i++) {
    $s = New-Object XInputTest+State
    $r = [XInputTest]::XInputGetState($i, [ref]$s)
    if ($r -eq 0) {
        Write-Host "XINPUT NATIVO PASS - Controle $i" -ForegroundColor Green
    } else { Write-Host "Slot $i return code $r" }
}
