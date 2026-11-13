#Requires -Version 5.1
[CmdletBinding()]
param([switch]$RemoveFiles)
$ErrorActionPreference='Stop'
$dir = Join-Path $env:LOCALAPPDATA 'CrossDeviceDictationGate'
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$exe = Join-Path $dir 'WindowsVoiceGate.exe'
$sender = Join-Path $dir 'SwitchSender.ps1'
foreach($item in @('CrossDeviceDictationGateVoice','CrossDeviceDictationGateSender')) {
    $current = (Get-ItemProperty -Path $key -ErrorAction SilentlyContinue).$item
    if ($null -ne $current -and $current.Contains($dir)) {
        Remove-ItemProperty -Path $key -Name $item -ErrorAction SilentlyContinue
        Write-Host "Removed autostart: $item"
    }
}
Get-CimInstance Win32_Process -Filter "Name='WindowsVoiceGate.exe'" -ErrorAction SilentlyContinue |
  Where-Object { $_.ExecutablePath -eq $exe } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -like ('*' + $sender + '*') } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }
if ($RemoveFiles -and (Test-Path $dir)) {
    Remove-Item -LiteralPath $dir -Recurse -Force
    Write-Host "Removed this package's files. Existing InputShare helpers were not touched."
} else {
    Write-Host "Stopped this package and removed its autostart. Logs/config/backups preserved in $dir."
}
