@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Firmware80NC.ps1" -Mode Original
echo Exit code: %errorlevel%
pause
