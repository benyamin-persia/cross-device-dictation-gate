#Requires -Version 5.1
$ErrorActionPreference='Stop'
Write-Host 'Cross-Device Dictation Gate: Windows setup wizard'
Write-Host 'Set up Deskflow server first, and ensure you know your Mac LAN IPv4 address.'
Write-Host 'Available local IPv4 addresses:'
Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
 Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' } |
 Select-Object IPAddress,InterfaceAlias | Format-Table -AutoSize
$winIp = Read-Host 'Windows Deskflow server LAN IPv4 address'
$macIp = Read-Host 'Mac LAN IPv4 address'
$defaultName = $env:COMPUTERNAME
$name = Read-Host "Exact Windows Deskflow screen name [$defaultName]"
if ([string]::IsNullOrWhiteSpace($name)) { $name = $defaultName }
$macName = Read-Host 'Exact Mac Deskflow screen name [Mac]'
if ([string]::IsNullOrWhiteSpace($macName)) { $macName = 'Mac' }
$log = Read-Host 'Deskflow Windows server log path [C:\ProgramData\Deskflow\deskflow-daemon.log]'
if ([string]::IsNullOrWhiteSpace($log)) { $log='C:\ProgramData\Deskflow\deskflow-daemon.log' }
$installer=Join-Path $PSScriptRoot 'install.ps1'
$opt = @{}
$dir = Join-Path $env:LOCALAPPDATA 'CrossDeviceDictationGate'
if(Test-Path $dir) {
    $yes=Read-Host 'A previous package install exists. Back up and update it? [y/N]'
    if ($yes -ne 'y') { Write-Host 'Cancelled'; return }
    $opt.Update=$true
}
& $installer -WindowsIp $winIp -MacIp $macIp -WindowsScreenName $name -MacScreenName $macName -DeskflowLog $log @opt
Write-Host 'Complete the Mac installer on the other computer, then test in an empty text editor.'
