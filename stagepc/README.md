# Stage PC switch scripts (Schwartz Lab)

Scripts for the Stage PC (192.168.0.3) to switch between the production Stage 2 server
(Symphony 2, port 5678, MATLAB R2019b) and the Stage 3 server from this repo (Symphony 3,
port 5679, MATLAB R2026b). Only one can own the projector at a time, so each "switch"
stops whatever Stage server is running first.

| Script | What it does |
|---|---|
| `Start-Stage3.bat` | Stop any Stage server, then start Stage 3 **fullscreen on the projector** (monitor 1), port 5679, via `stage-matlab\StartStageSchwartzLab.m`. `Start-Stage3.bat windowed` opens a 640x480 window instead (smoke test). |
| `Start-Stage2.bat` | Stop any Stage server, then launch the installed Stage 2 "Stage Server" app in R2019b with the same command the old Startup shortcut used. The app starts serving on port 5678 **immediately, fullscreen on the projector** (verified 2026-10-07). |
| `Stop-StageServers.bat` | Stop whichever Stage server is running (by listening port 5678/5679 or by launch command line). |
| `Stop-StageServers.ps1` | Helper used by the three .bat files. |

## Installed on this PC (2026-10-07)

- Desktop shortcuts: **Switch to Stage 3**, **Switch to Stage 2**, **Stop Stage servers**
  (pointing at the three .bat files above).
- Per-user Startup folder (`%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`):
  **Stage 3 Server.lnk** → `Start-Stage3.bat`, so Stage 3 starts fullscreen at login.
- The old all-users Startup shortcut `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\stage.lnk`
  (which opened the Stage 2 app at login) was moved to `stagepc\disabled-startup\stage.lnk`
  in this folder. To make Stage 2 the login default again, move it back and delete
  `Stage 3 Server.lnk` from the per-user Startup folder.

Stage 2's install (`Documents\MATLAB\Add-Ons\Apps\StageServer`, `Add-Ons\Toolboxes\Stage`,
`Documents\MATLAB\startStageServer.m`) is not modified by any of this.

## Getting out of a fullscreen Stage window

- **Hold LEFT Shift + Esc for up to 10 seconds** with the Stage window focused (click on it
  first). The server only polls the keyboard every 10 s (its socket accept/receive timeout),
  so a quick tap does nothing. Right Shift is not checked.
- Keyboard-only alternative: **Ctrl + Shift + Esc** opens Task Manager on top of the Stage
  window; end the MATLAB process there.
- Or press the Windows key, type `Stop Stage servers`, Enter (the Desktop shortcut), which
  runs `Stop-StageServers.bat`.

## Notes
- Stage 3 logs appear in the MATLAB console window behind the fullscreen Stage window.
- The Stage 3 server needs the `symphony3-port` clone of sa-labs-extension next to this repo
  (`Documents\MATLAB\Symphony3\sa-labs-extension`); `StartStageSchwartzLab.m` adds it to the path.

| `StageWatchdog.ps1` / `Install-StageWatchdog.bat` | Remote restart from the rig PC (TCP 5680, token in `StageWatchdog.token`). Install once as administrator; see SCHWARTZLAB_STAGE_PC.md "Remote restart". |
