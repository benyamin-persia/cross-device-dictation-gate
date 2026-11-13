@echo off
setlocal
cd /d "%~dp0"
echo Cross-Device Dictation Gate - Windows setup
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup.ps1"
echo.
pause
