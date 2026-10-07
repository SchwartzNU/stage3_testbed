@echo off
REM Start-Stage3.bat - switch this PC to Stage 3 (Symphony 3, port 5679).
REM
REM Stops any running Stage server (Stage 2 or Stage 3), then starts the Stage 3
REM server from this repo in MATLAB R2026b, fullscreen on the projector (monitor 1).
REM This is what the per-user Startup shortcut runs at login.
REM
REM Usage:
REM   Start-Stage3.bat            fullscreen on the projector (default)
REM   Start-Stage3.bat windowed   640x480 window on the desktop, for smoke tests
REM
REM Stop the server with shift + escape while the Stage window has focus,
REM or run Stop-StageServers.bat.

setlocal
set "HERE=%~dp0"
for %%I in ("%HERE%..\stage-matlab") do set "STAGE3=%%~fI"
set "MATLAB_EXE=C:\Program Files\MATLAB\R2026b\bin\matlab.exe"

if not exist "%MATLAB_EXE%" (
    echo MATLAB R2026b not found at "%MATLAB_EXE%".
    pause
    exit /b 1
)

echo Stopping any running Stage server...
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%Stop-StageServers.ps1"

if "%~1"=="" (
    set "LAUNCH_CMD=StartStageSchwartzLab"
) else (
    set "LAUNCH_CMD=StartStageSchwartzLab('%~1')"
)

echo Starting Stage 3 server: %LAUNCH_CMD%  (port 5679)
start "" "%MATLAB_EXE%" -sd "%STAGE3%" -nodesktop -r "%LAUNCH_CMD%"
endlocal
