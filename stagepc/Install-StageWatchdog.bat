@echo off
REM Install-StageWatchdog.bat - run once on the Stage PC, double-clicked as the user
REM that logs in (SchwartzLab). Do NOT run it from another account's administrator
REM prompt: the watchdog and the Stage servers it starts must run in this user's
REM session (MATLAB's jenv Java binding is per user).
REM
REM It runs Install-StageWatchdog.ps1, which creates the token, adds a per-user
REM Startup shortcut for the watchdog, starts it now, and asks (UAC) to open TCP 5680
REM in the firewall for all profiles. Afterwards the rig PC can restart the Stage
REM server with restartStageServer in MATLAB (see StageWatchdog.ps1 for the protocol).
REM
REM Uninstall: see the header of Install-StageWatchdog.ps1.

setlocal
set "HERE=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%Install-StageWatchdog.ps1"
echo.
pause
endlocal
