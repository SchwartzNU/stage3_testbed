@echo off
REM StartStageSchwartzLab.bat - Stage 3 server on port 5679 for Symphony 3,
REM alongside the production Stage 2 "Stage Server" on port 5678.
REM
REM Usage:
REM   StartStageSchwartzLab.bat            fullscreen on the projector (monitor 1)
REM   StartStageSchwartzLab.bat windowed   640x480 window, for smoke tests
REM
REM Set MATLAB_EXE to pick a specific release, e.g.
REM   set "MATLAB_EXE=C:\Program Files\MATLAB\R2026b\bin\matlab.exe"

setlocal

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

if "%MATLAB_EXE%"=="" set "MATLAB_EXE=matlab"

set "MODE=%~1"
if "%MODE%"=="" (
    set "LAUNCH_CMD=StartStageSchwartzLab"
) else (
    set "LAUNCH_CMD=StartStageSchwartzLab('%MODE%')"
)

echo Starting Stage 3 (Schwartz Lab, port 5679) from: %ROOT%
echo Mode: %LAUNCH_CMD%
echo.

"%MATLAB_EXE%" -sd "%ROOT%" -nosplash -nodesktop -r "%LAUNCH_CMD%"

endlocal
