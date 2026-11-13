#Requires -Version 5.1
<#
Build and install the Windows half of Cross-Device Dictation Gate.
Example:
.\windows\install.ps1 -WindowsIp 192.168.1.10 -MacIp 192.168.1.20 -WindowsScreenName "MY-PC" -MacScreenName "Mac"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$WindowsIp,
    [Parameter(Mandatory=$true)][string]$MacIp,
    [Parameter(Mandatory=$true)][string]$WindowsScreenName,
    [Parameter(Mandatory=$true)][string]$MacScreenName,
    [string]$DeskflowLog = "C:\ProgramData\Deskflow\deskflow-daemon.log",
    [ValidateRange(1024,65535)][int]$Port = 43891,
    [switch]$Update,
    [switch]$ValidateOnly
)
$ErrorActionPreference = 'Stop'
function Test-IPv4([string]$address) {
    $ip = $null
    return ([System.Net.IPAddress]::TryParse($address,[ref]$ip) -and
       $ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork)
}
if (!(Test-IPv4 $WindowsIp) -or !(Test-IPv4 $MacIp) -or $WindowsIp -eq $MacIp) {
    throw "Specify two distinct IPv4 addresses."
}
if ($WindowsScreenName -notmatch '^[A-Za-z0-9_. -]{1,80}$' -or
    $MacScreenName -notmatch '^[A-Za-z0-9_. -]{1,80}$') {
    throw "Use the exact Deskflow screen names (1-80 letters, digits, dots, spaces, underscores or hyphens)."
}
if (!(Test-Path -LiteralPath $DeskflowLog -PathType Leaf) -and !$ValidateOnly) {
    throw "Deskflow server log does not exist at $DeskflowLog."
}
$repoRoot = Split-Path $PSScriptRoot -Parent
$winTemplate = Join-Path $PSScriptRoot 'WindowsVoiceGate.cs.in'
$senderTemplate = Join-Path $PSScriptRoot 'SwitchSender.ps1.in'
if (!(Test-Path $winTemplate) -or !(Test-Path $senderTemplate)) {
    throw "Source templates missing: download the complete repository."
}
$installDir = Join-Path $env:LOCALAPPDATA 'CrossDeviceDictationGate'
if ((Test-Path $installDir) -and !($Update -or $ValidateOnly)) {
    throw "Existing installation found in $installDir. Rerun with -Update to back up this package before replacement."
}
$compiler = @(
  (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
  (Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (!$compiler) { throw "Install the .NET Framework 4.x developer tools (csc.exe)." }
$stage = Join-Path $env:TEMP ('CrossDeviceDictationGate-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $stage | Out-Null
function Render-Template([string]$source,[string]$destination) {
    $raw = [IO.File]::ReadAllText($source)
    $items = @{
        '__WINDOWS_IP__' = $WindowsIp
        '__MAC_IP__' = $MacIp
        '__UDP_PORT__' = "$Port"
        '__WINDOWS_SCREEN_NAME__' = $WindowsScreenName
        '__MAC_SCREEN_NAME__' = $MacScreenName
        '__DESKFLOW_LOG_PATH__' = $DeskflowLog.Replace("'","''")
    }
    foreach($key in $items.Keys) { $raw = $raw.Replace($key,$items[$key]) }
    if ($raw -match '__[A-Z_]+__') { throw "Unresolved template token in $source" }
    [IO.File]::WriteAllText($destination,$raw,(New-Object Text.UTF8Encoding($false)))
}
try {
    $sourceFile = Join-Path $stage 'WindowsVoiceGate.cs'
    $senderFile = Join-Path $stage 'SwitchSender.ps1'
    $exeFile = Join-Path $stage 'WindowsVoiceGate.exe'
    Render-Template $winTemplate $sourceFile
    Render-Template $senderTemplate $senderFile
    & $compiler '/nologo' '/target:winexe' '/optimize+' '/reference:System.dll' '/reference:System.Windows.Forms.dll' "/out:$exeFile" "$sourceFile"
    if ($LASTEXITCODE -ne 0 -or !(Test-Path $exeFile)) { throw "Windows compilation failed." }
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($senderFile,[ref]$tokens,[ref]$errors)|Out-Null
    if ($errors.Count -gt 0) { throw ("Generated PowerShell has syntax errors: " + ($errors | Out-String)) }
    if ($ValidateOnly) {
        Write-Host "PASS: Windows EXE compiled and sender script parsed. No installation performed."
        return
    }
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    foreach($name in @('WindowsVoiceGate.exe','WindowsVoiceGate.cs','SwitchSender.ps1')) {
        $dest = Join-Path $installDir $name
        if(Test-Path $dest) { Copy-Item -LiteralPath $dest -Destination ($dest + '.backup-' + $timestamp) }
    }
    # Only stop copies belonging to THIS package, never the user's older InputShare helper.
    $installedExe = Join-Path $installDir 'WindowsVoiceGate.exe'
    $installedSender = Join-Path $installDir 'SwitchSender.ps1'
    Get-CimInstance Win32_Process -Filter "Name='WindowsVoiceGate.exe'" -ErrorAction SilentlyContinue |
      Where-Object { $_.ExecutablePath -eq $installedExe } |
      ForEach-Object { Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
      Where-Object { $_.CommandLine -like ('*' + $installedSender + '*') } |
      ForEach-Object { Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }
    Copy-Item -LiteralPath $exeFile -Destination $installedExe -Force
    Copy-Item -LiteralPath $sourceFile -Destination (Join-Path $installDir 'WindowsVoiceGate.cs') -Force
    Copy-Item -LiteralPath $senderFile -Destination $installedSender -Force
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $senderCommand = 'powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $installedSender + '"'
    Set-ItemProperty -Path $key -Name 'CrossDeviceDictationGateVoice' -Value ('"' + $installedExe + '"')
    Set-ItemProperty -Path $key -Name 'CrossDeviceDictationGateSender' -Value $senderCommand
    Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-NonInteractive','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File',('"' + $installedSender + '"')) -WindowStyle Hidden
    Start-Sleep -Milliseconds 350
    Start-Process -FilePath $installedExe -WindowStyle Hidden -WorkingDirectory $installDir
    Write-Host "Installed to $installDir"
    Write-Host "Two Windows helpers registered at user sign-in."
    Write-Host "Install the macOS companion and grant its Accessibility permission."
    Write-Host "Trusted LAN only. Never expose UDP $Port to the public internet."
} finally {
    if (Test-Path $stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
}
