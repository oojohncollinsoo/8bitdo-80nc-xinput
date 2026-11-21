param([Parameter(Mandatory=$true)][ValidateSet('XInput','Original')][string]$Mode)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = $PSScriptRoot
$up = Join-Path $root 'Updater'
$exe = Join-Path $up '8BitDo Firmware Updater.exe'
$cache = Join-Path $up 'updateFile\b1e151e4-c14b-4ae4-80ce-f64d23457a0d.dat'
$stock = Join-Path $root 'Firmware\80NC_V101_ORIGINAL.dat'
$candidate = Join-Path $root 'Firmware\80NC_V101_XINPUT_EXPERIMENTAL.dat'
$stockHash = 'b6badf8a7ecb4c2a63be78bae3b01000b9f7a43f148806c996b948533290691a'
$candidateHash = '64de40596324ef55d66ed7bf46f36c3cd7f6d81a777ebd13b39ebc46d0e0cf51'
$expected = @{
    '8BitDo Firmware Updater.exe' = '5880c67c092f6d6e658f5a3a10c87dd42a439d561de75384599befe7b905916c'
    '8BitDoFirmwareUpdaterTools.dll' = 'b38ffa61b12af29d41dc55212e5ba44e509130facf6e3c4db9a7141aa313f974'
    'J2i.Net.XInputWrapper.dll' = '96fd1b4ec4d3d2907e92220413b59e7b14af263976cc222b407c589ec289d08b'
    'data\Autoupdate.exe' = '6ae8ceb83b42e590a5c920d03fe227841a817bdf671b1fe81f902f405d6b01c5'
    'data\ICSharpCode.SharpZipLib.dll' = '8ac42e07dfc4f53bbcfc9d34bd170ab7278a724cfdfb14d87aa8979542d0affa'
    'data\versions.txt' = 'ca3c9abacd39bbd9b5116e39cb38c500083f814406268ccd1cd40ffafc3825a6'
}
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Verify([string]$Path,[string]$Sha) {
    if ((Hash $Path) -ne $Sha) { throw "SHA256 divergente: $Path" }
}
function Lines([string]$Path) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) { Get-Content -LiteralPath $Path }
}
function CheckNoUpdater {
    $running = @(Get-Process | Where-Object { $_.ProcessName -match '8BitDo.*(Updater|Software)|^Autoupdate$' })
    if ($running.Count -gt 0) { throw 'Feche o atualizador e Ultimate Software antes de continuar.' }
}
try {
    Write-Host "8BitDo 80NC / Modo: $Mode" -ForegroundColor Cyan
    CheckNoUpdater
    foreach ($name in $expected.Keys) { Verify (Join-Path $up $name) $expected[$name] }
    Verify $stock $stockHash
    Verify $candidate $candidateHash
    if ((Get-Item -LiteralPath $stock).Length -ne 86044 -or (Get-Item -LiteralPath $candidate).Length -ne 86044) { throw 'Tamanho incorreto.' }
    $old = Hash $cache
    if ($old -ne $stockHash -and $old -ne $candidateHash) { throw 'Cache nao pertence a esta versao.' }
    Write-Host 'Desconecte outros controles e feche Steam e DS4Windows.'
    Write-Host 'Entre no bootloader: desligue o 80NC, segure L+R e conecte USB.'
    [void](Read-Host 'Pressione Enter quando estiver pronto')
    $dev = @(Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match '^HID\\VID_2DC8&PID_3208\\' })
    if ($dev.Count -ne 1) { throw 'Esperado exatamente um bootloader HID 2DC8:3208.' }
    $path = '\\?\' + ($dev[0].InstanceId -replace '\\','#') + '#{4d1e55b2-f16f-11cf-88cb-001111000030}'
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public class Confirm80NC {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern SafeFileHandle CreateFile(string p, uint a, uint s, IntPtr sec, uint c, uint f, IntPtr t);
    [DllImport("kernel32.dll")]
    static extern bool CancelIoEx(SafeFileHandle h, IntPtr o);
    public static int ReadPid(string path) {
        using (var h = CreateFile(path, 0xC0000000, 3, IntPtr.Zero, 3, 0x40000000, IntPtr.Zero)) {
            if (h.IsInvalid) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            using (var s = new FileStream(h, FileAccess.ReadWrite, 1, true)) {
                byte[] tx = new byte[65]; tx[0]=0x81; tx[1]=5; tx[2]=8; tx[6]=2; tx[10]=2;
                var w = s.WriteAsync(tx,0,65);
                if (!w.Wait(3000)) { CancelIoEx(h,IntPtr.Zero); throw new Exception("WRITE_TIMEOUT"); }
                byte[] rx = new byte[65]; var r = s.ReadAsync(rx,0,65);
                if (!r.Wait(3000)) { CancelIoEx(h,IntPtr.Zero); throw new Exception("READ_TIMEOUT"); }
                Console.WriteLine("RAW: " + BitConverter.ToString(rx,0,r.Result));
                if (r.Result < 21 || rx[2]!=5 || rx[5]!=8) throw new Exception("RESPOSTA_INESPERADA");
                return rx[19] | (rx[20]<<8);
            }
        }
    }
}
'@
    $pidValue = [Confirm80NC]::ReadPid($path)
    if ($pidValue -ne 0x301A) { throw ('PID interno inesperado: {0:X4}' -f $pidValue) }
    Write-Host 'PID interno 301A / MODELO_CONFIRMADO' -ForegroundColor Green
    if ($Mode -eq 'XInput') {
        Write-Warning 'Firmware experimental: pode deixar o controle inoperante. Recuperacao nao garantida.'
        if ((Read-Host 'Digite CONFIRMO para preparar o teste') -cne 'CONFIRMO') { throw 'Cancelado.' }
        $source = $candidate; $targetHash = $candidateHash
    } else {
        if ((Read-Host 'Digite RESTAURAR para preparar o firmware original') -cne 'RESTAURAR') { throw 'Cancelado.' }
        $source = $stock; $targetHash = $stockHash
    }
    CheckNoUpdater
    $debug = Join-Path $up 'data\debugLog.txt'
    $native = Join-Path $up 'data\updateLog.txt'
    $beforeDebug = @(Lines $debug)
    $beforeNative = @(Lines $native)
    Copy-Item -LiteralPath $source -Destination $cache -Force
    Verify $cache $targetHash
    Write-Host "Cache preparado: $targetHash"
    Write-Host 'Use a MESMA selecao que funcionou: tipo 108, Ultimate 2, V1.01 de 2025-07-24.'
    Write-Host 'Se o programa oferecer atualizar o proprio programa, cancele e feche.'
    Write-Host 'Aguarde Update complete. NAO desconecte durante a gravacao. Feche o atualizador ao terminar.'
    try {
        Start-Process -FilePath $exe -WorkingDirectory $up -Wait
        CheckNoUpdater
        $afterDebug = @(Lines $debug)
        $afterNative = @(Lines $native)
        $newDebug = @($afterDebug | Select-Object -Skip $beforeDebug.Count)
        $newNative = @($afterNative | Select-Object -Skip $beforeNative.Count)
        $log = Join-Path $root ('RESULTADO_' + $Mode + '_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log')
        @('MODO: ' + $Mode; 'CACHE_SHA256: ' + (Hash $cache); 'ESPERADO: ' + $targetHash; 'DEBUG:'; $newDebug; 'NATIVE:'; $newNative) | Set-Content -LiteralPath $log -Encoding UTF8
        Verify $cache $targetHash
        Verify $exe $expected['8BitDo Firmware Updater.exe']
        Verify (Join-Path $up '8BitDoFirmwareUpdaterTools.dll') $expected['8BitDoFirmwareUpdaterTools.dll']
        $debugText = $newDebug -join "`n"
        $nativeText = $newNative -join "`n"
        if ($debugText -notmatch 'firmware type: 108' -or $debugText -notmatch [regex]::Escape('b1e151e4-c14b-4ae4-80ce-f64d23457a0d.dat') -or $nativeText -notmatch 'PID: 301a' -or $nativeText -notmatch 'Len: 15000 desAddress:1018000' -or $nativeText -notmatch 'inspect Flash pass') {
            throw "Gravacao nao comprovada no log. Envie $log"
        }
        Write-Host "GRAVACAO E INSPECAO REPORTADAS PELO UPDATER. Envie $log" -ForegroundColor Green
    } finally {
        CheckNoUpdater
        $current = Hash $cache
        if ($current -eq $candidateHash) {
            Copy-Item -LiteralPath $stock -Destination $cache -Force
            Verify $cache $stockHash
            Write-Host 'Cache local voltou ao original (isso nao regrava o controle).'
        }
    }
} catch {
    Write-Host "FAIL_CLOSED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
exit 0
