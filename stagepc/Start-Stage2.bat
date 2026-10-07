@echo off
REM Start-Stage2.bat - switch this PC back to Stage 2 (Symphony 2, port 5678).
REM
REM Stops any running Stage server (Stage 2 or Stage 3), then launches the installed
REM Stage 2 "Stage Server" app in MATLAB R2019b with exactly the command the old
REM all-users Startup shortcut (stage.lnk) used. The app starts serving on port 5678
REM immediately, fullscreen on the projector. To stop it: click the Stage window and
REM HOLD left Shift + Esc for up to 10 s, or run Stop-StageServers.bat.
REM
REM The Stage 2 install itself (Documents\MATLAB\Add-Ons) is not modified.

setlocal
set "HERE=%~dp0"
set "MATLAB_EXE=C:\Program Files\MATLAB\R2019b\bin\matlab.exe"

if not exist "%MATLAB_EXE%" (
    echo MATLAB R2019b not found at "%MATLAB_EXE%".
    pause
    exit /b 1
)

echo Stopping any running Stage server...
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%Stop-StageServers.ps1"

echo Starting Stage 2 Stage Server app (R2019b, port 5678)...
cd /d "C:\Program Files\MATLAB\R2019b\bin"
start "" "%MATLAB_EXE%" -nodesktop -nosplash -r "startStageServer"
endlocal
