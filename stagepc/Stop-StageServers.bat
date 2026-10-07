@echo off
REM Stop-StageServers.bat - stop whichever Stage server (Stage 2 or Stage 3) is running.
setlocal
set "HERE=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%Stop-StageServers.ps1"
ping -n 3 127.0.0.1 >nul
endlocal
