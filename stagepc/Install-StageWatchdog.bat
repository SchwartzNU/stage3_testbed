@echo off
REM Install-StageWatchdog.bat - run once on the Stage PC (as the user that logs in).
REM
REM Registers StageWatchdog.ps1 as a hidden task that starts at this user's logon,
REM opens Windows Firewall for TCP 5680 on private/domain networks, writes the shared
REM token, and starts the watchdog now. Afterwards the rig PC can restart the Stage
REM server with restartStageServer in MATLAB (see StageWatchdog.ps1 for the protocol).
REM
REM Uninstall: schtasks /Delete /TN StageWatchdog /F

setlocal
set "HERE=%~dp0"
set "SCRIPT=%HERE%StageWatchdog.ps1"

if not exist "%HERE%StageWatchdog.token" (
    echo stage-%RANDOM%%RANDOM%> "%HERE%StageWatchdog.token"
)
echo Token (copy this into restartStageServer.m on the rig PC, or keep the default there if unchanged):
type "%HERE%StageWatchdog.token"

schtasks /Delete /TN StageWatchdog /F >nul 2>&1
schtasks /Create /TN StageWatchdog /SC ONLOGON /RL LIMITED /F ^
    /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%SCRIPT%\""
if errorlevel 1 (
    echo Could not create the logon task. Run this file as administrator.
    pause
    exit /b 1
)

netsh advfirewall firewall delete rule name="Stage watchdog 5680" >nul 2>&1
netsh advfirewall firewall add rule name="Stage watchdog 5680" dir=in action=allow protocol=TCP localport=5680 profile=private,domain >nul 2>&1

echo Starting the watchdog now...
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%SCRIPT%"
echo Done. Log: %LOCALAPPDATA%\StageWatchdog\watchdog.log
endlocal
