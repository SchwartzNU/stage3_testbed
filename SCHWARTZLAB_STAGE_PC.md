# Schwartz Lab: Stage 3 on the Stage PC (handoff for a Claude Code session)

Written 2026-10-07 from the Rig A acquisition PC (DESKTOP-RGBEATN). Paste this file's
contents, or point Claude at it, when starting a Claude Code session on the Stage PC.
There is no shared memory between the two machines, so this file is the context.

## Who / what

- Greg Schwartz (greg.schwartz@northwestern.edu), Schwartz Lab, Northwestern. GitHub account **SchwartzNU**.
- We are porting the lab's acquisition from Symphony 2 / Stage 2.3.3 to Mike Manookin's
  Symphony 3 (`mikemanookin/symphony3_matlab`) and Stage 3 (`mikemanookin/stage3_testbed`).
  Our forks: `SchwartzNU/symphony3_matlab_schwartzlab_integration` and `SchwartzNU/stage3_testbed`
  (this repo). Lab protocols: `Schwartz-AlaLaurila-Labs/sa-labs-extension`, branch `symphony3-port`.
- **Everything must run in parallel with the production Symphony 2 / Stage 2 until every
  protocol is verified.** Never stop, uninstall, or edit the existing Stage Server install.

## This machine's job (the Stage PC, 192.168.0.3)

Today it runs the old Stage Server (MATLAB toolbox "Stage" / app "Stage Server") on
**TCP port 5678** for Symphony 2 on the Rig A PC. It must keep doing that.

Goal: also run **Stage 3 on port 5679** from this repo, in its own MATLAB session, so that
Symphony 3 on the Rig A PC (whose `sa_labs.rigs.SchwartzLab_Rig_A_UVProjector` on the
`symphony3-port` branch already has `host = '192.168.0.3'`, `port = 5679`) can drive it.

## Steps

0. **Java.** MATLAB R2025b+ ships no JVM, and Stage needs one (stage.core.Canvas and the netbox
   TCP layer are Java-based; on R2026b the server dies with "no runtime environment for Java
   applications has been found"). Install Eclipse Temurin JDK 17 (`winget install
   EclipseAdoptium.Temurin.17.JDK`, needs an admin UAC click) and in MATLAB run
   `jenv("C:Program Filesclipse Adoptiumjdk-17.<x>-hotspot")` once (per user), then restart
   MATLAB and confirm with `version -java`. Supported OpenJDK for R2026b: 8, 11, 17, 21, 25
   (https://www.mathworks.com/support/requirements/openjdk.html). Older MATLAB (<= R2025a)
   bundles Java and needs nothing.
1. Find out the MATLAB release(s) installed here (`dir "C:\Program Files\MATLAB"`). Stage 3 needs
   **R2019b or newer** (Mike develops on R2024b). Also note the GPU and which monitor is the
   projector (`stage.core.Monitor` index; the old Stage Server app shows it).
2. `gh auth login` as SchwartzNU if pushes are needed; cloning is public.
3. Clone this fork, e.g. `C:\Users\<user>\Documents\MATLAB\Symphony3\stage3_testbed`
   (`git clone https://github.com/SchwartzNU/stage3_testbed.git`), add
   `upstream = https://github.com/mikemanookin/stage3_testbed.git`.
   **Keep this fork and the Rig A PC clone on the same commit** (the wire protocol is
   Java-serialized netbox events; `stop` is new in Stage 3).
4. `winget install Gyan.FFmpeg` (needed only for Movie stimuli; restart the shell after).
5. Prebuilt MEX files are in `stage-matlab/lib` (`matlab-glfw3`, `matlab-priority`,
   `MOGL/source/moglcore.mexw64`). In MATLAB (new release), from `stage-matlab`:
   `StartStage('pathsonly'); VerifyStage` and fix anything it reports
   (`docs/Install.md` has the rebuild commands; needs MinGW add-on).
6. Start the server, windowed first, to confirm it comes up without touching the projector:
   ```matlab
   cd('<clone>\stage-matlab'); StartStage('headless','port',5679,'size',[640 480],'fullscreen',false,'monitor',1)
   ```
   then for real use on the projector monitor N:
   ```matlab
   StartStage('headless','port',5679,'fullscreen',true,'monitor',N)
   ```
   (`StartStage.bat headless` uses port 5678 by default; do NOT use that while Stage 2 runs.)
   Make sure Windows Firewall allows inbound TCP 5679 from 192.168.0.x.
7. Tell the Rig A session the Stage 3 commit hash and the monitor index/refresh rate.

## Known facts about the old setup

- `sa_labs.devices.LightCrafterDevice` on the Rig PC connects with `stage.core.network.StageClient`
  and calls: connect, setMonitorGamma, getCanvasSize, setCanvasProjectionIdentity/Orthographic/
  Translate, resetCanvasProjection/Renderer, getMonitorRefreshRate, play, replay, getPlayInfo,
  clearMemory, setCanvasRenderer, disconnect. All exist in Stage 3's `StageClient`.
- The LightCrafter 4500 itself is controlled over USB from the Rig PC (matlab-lcr), not from here.
- Lab stimuli use `stage.builtin.controllers.PropertyController`, `stage.core.Presentation`,
  `Ellipse`, `Rectangle`, `Image`, `Movie`, `Grating`, `Mask.createAnnulus/createCircularEnvelope`,
  `PatternCompositor`/`PatternRenderer`, `RealtimePlayer`, `PrerenderedPlayer`; plus the lab's own
  `sa_labs.util.ExactPatternCompositor`, `PatternMovie`, `SubtractiveRectangle` (shipped with the
  Rig PC's protocols, serialized to the server inside the Player; the server does not need the
  extension on its path unless deserialization requires the class, which we must verify).

## Open questions to resolve here

- MATLAB release available; whether a newer one must be installed.
- Does the Stage 3 server need `sa-labs-extension` on its MATLAB path to deserialize the lab's
  custom compositor/stimulus classes? (Stage 2 setup: check whether the old server has it.)
- Projector monitor index and measured refresh rate (Stage 3 can pin it with
  `StartStage('headless', ..., 'refreshRate', R)` if the empirical measurement is off).

## Findings from the Rig A PC (2026-10-07, later)

- Stage 3 reports the **measured** monitor refresh rate (60.30 Hz on the Rig A desktop monitor);
  Stage 2 returned GLFW's integer 60. Two lab protocols (NaturalMovingObjectAndFlash,
  White_to_Pink_Temporal_Noise) break on a non-integer rate. When the server is up here, report
  the measured rate of the projector (`Monitor refresh rate: ... (measured)` in the console) so
  Greg can decide between pinning the rate and fixing the protocols.
- The pinned-rate path `StageServer.start(size, fullscreen, monitor, 'refreshRate', 60)` errors in
  windowed mode: "Dot indexing is not supported for variables of type double" at
  `window.monitor.setRefreshRate` (StageServer.m line 85). `StartStage('headless', ...)` does not
  accept 'refreshRate' at all. Worth checking whether fullscreen mode has the same bug; report to Mike.
- R2026b ships with no toolboxes by default; Stage itself needs none, but check `ver` anyway.
- Rig A PC clone commit of this fork: see `git log -1` here; keep both in sync.
## Stage PC status (2026-10-07, from the Stage PC session)

Hostname DESKTOP-0NAQIQ7, IP 192.168.0.3, GPU NVIDIA GeForce GT 710 (driver 30.0.14.7514).

### Answers to the open questions

- **MATLAB:** R2016a and R2019b installed (R2019b Update 9, bundled Java 1.8.0_202). Stage 3
  runs on R2019b: `VerifyStage` passes every check and all prebuilt MEX files load, so no
  rebuild and no JDK install were needed. Greg is installing R2026b in parallel; on that
  release step 0 (Temurin JDK 17 + `jenv`) applies, and a MEX reload check should be repeated.
- **Projector monitor index = 1.** It is the only display attached (`\.\DISPLAY1`,
  "Generic PnP Monitor", 912x1140, LightCrafter 4500 native). GLFW enumerates exactly one
  monitor. Nominal 60 Hz; **Stage 3 measured 59.9546 Hz** at server start (median-of-N).
- **sa-labs-extension on the server path: yes, required.** The production Stage 2 server's
  saved path (R2019b `pathdef.m`) contains `Documents\MATLAB\sa-labs-extension` (master,
  via genpath). netbox serializes with `getByteStreamFromArray`/`getArrayFromByteStream`, so
  the server needs the class definitions to deserialize `sa_labs.util.*`. A separate clone of
  the `symphony3-port` branch lives at `Documents\MATLAB\Symphony3\sa-labs-extension`
  (commit 115002f) and the launcher below adds its `src\main\matlab` to the path. Verified:
  a presentation with `sa_labs.util.SubtractiveRectangle` + `sa_labs.util.ExactPatternCompositor`
  (with a `PatternRenderer(4,2,8)` set first) deserialized and played on the Stage 3 server.

### How Stage 2 runs here (do not touch)

- Startup-folder shortcut `C:\ProgramData\...\Startup\stage.lnk` runs
  `R2019b matlab.exe -nodesktop -nosplash -r "startStageServer"`; `Documents\MATLAB\startStageServer.m`
  launches the installed "Stage Server" app (`Documents\MATLAB\Add-Ons\Apps\StageServer`,
  toolbox at `Add-Ons\Toolboxes\Stage`). Port 5678. It was not running during this session
  (nothing listening on 5678, no MATLAB process); it comes up at login.
- Windows Firewall already has program-scoped inbound Allow rules (TCP and UDP, any port) for
  `C:\Program Files\MATLAB\R2019b\bin\win64\matlab.exe`, so port 5679 needs no new rule as long
  as the Stage 3 server runs under R2019b. A new MATLAB release will need its own rule
  (MATLAB normally prompts for it on first network use; the account is not an administrator).

### Stage 3 launcher for this PC

`stage-matlab\StartStageSchwartzLab.m` (and `.bat`), committed in this fork:

```matlab
cd('C:\Users\SchwartzLab\Documents\MATLAB\Symphony3\stage3_testbed\stage-matlab')
StartStageSchwartzLab('windowed')   % 640x480 window, port 5679, smoke test
StartStageSchwartzLab()             % fullscreen on monitor 1 (projector), port 5679
StartStageSchwartzLab('refreshRate', 59.9546)   % optional: pin the measured rate
```

Session-only path hygiene (nothing is saved): removes the installed Stage 2 toolbox/app and
the master sa-labs-extension from the path, adds this source tree, adds the symphony3-port
extension, and puts the winget ffmpeg (Gyan.FFmpeg 9.0.2, `%LOCALAPPDATA%\Microsoft\WinGet\...`)
on PATH if it is not inherited yet. Refuses port 5678.

Verified 2026-10-07 on R2019b, windowed: `StageClient` connect/getCanvasSize/
getMonitorRefreshRate/getMonitorResolution/play/getPlayInfo/clearMemory/disconnect all worked
from a second MATLAB on localhost (1 s ellipse with a PropertyController: 57 frames,
mean flip 17.2 ms, max 33.1 ms in the non-fullscreen window; expect tighter timing fullscreen).

### Tooling installed this session (per-user, via winget)

- Gyan.FFmpeg 9.0.2 (restart shells / re-login for PATH; the launcher also handles it).
- GitHub.cli (`%LOCALAPPDATA%\Microsoft\WinGet\Packages\GitHub.cli_*\bin\gh.exe`); not yet
  logged in (`gh auth login` as SchwartzNU is interactive).
- Not installed: MinGW (not needed on R2019b), Temurin JDK (not needed on R2019b).

### For the Rig A session

- Stage 3 fork commit: see `git log -1` on this repo after this commit (Rig A clone must match).
- sa-labs-extension symphony3-port commit on the server: 115002f.
- Projector: monitor 1, 912x1140, measured 59.9546 Hz (nominal 60).

### R2026b (installed 2026-10-07, later the same session)

- R2026b (26.2.0.3386108) installed by Greg; products: MATLAB + MATLAB Copilot only.
- Temurin JDK 17.0.20.1 installed (`winget install EclipseAdoptium.Temurin.17.JDK`, UAC approved)
  and bound once with `jenv("C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot")`.
  `version -java` in a `-batch` session still prints "Java is not loaded" (lazy load); the
  server start proves the JVM works (netbox listens, clients connect).
- `VerifyStage` on R2026b: ALL 12 CHECKS PASSED (prebuilt MEX files load, ffmpeg found).
- `StartStageSchwartzLab('windowed')` on R2026b: measured refresh **59.9794 Hz**; the same
  two localhost client tests passed (1 s ellipse: 56 frames, mean flip 17.9 ms;
  SubtractiveRectangle + ExactPatternCompositor with PatternRenderer(4,2,8): 17 frames).
- Toolboxes: `matlab.codetools.requiredFilesAndProducts` over Stage 3 `src`, netbox,
  matlab-avbin and `sa_labs.util.*` reports **MATLAB only**. Nothing else to install for the
  server. MinGW is only needed if a MEX rebuild is ever required (it is not today).
- Firewall: the R2026b installer added "MATLAB R2026b" inbound Allow rules (TCP+UDP, any port,
  Public profile) for `C:\Program Files\MATLAB\R2026b\bin\win64\matlab.exe`. The Ethernet
  adapter (192.168.0.3, "Unidentified network") is on the Public profile, so port 5679 is
  reachable from the rig network under R2019b or R2026b without new rules.
- Recommended production launch (R2026b, projector, port 5679):
  `set "MATLAB_EXE=C:\Program Files\MATLAB\R2026b\bin\matlab.exe"` then
  `stage-matlab\StartStageSchwartzLab.bat`, or in MATLAB `StartStageSchwartzLab()`.
  Measured rates differ slightly by release/run (59.9546 vs 59.9794 Hz); let the server measure
  at start, or pin with `StartStageSchwartzLab('refreshRate', R)` once Rig A settles on a value.

### Reply to the Rig A findings (Stage PC, 2026-10-07)

- **Projector measured rate:** 59.9546 Hz (R2019b run) and 59.9794 Hz (R2026b run), windowed.
  Non-integer either way, so the two protocols that assume an integer rate need the fix or a pin.
- **Pinned-rate path works here.** `StartStageSchwartzLab('windowed', 'refreshRate', 59.98)` on
  R2026b printed `Monitor refresh rate: 59.9800 Hz (caller-supplied)` and served normally. The
  launcher passes a `stage.core.Monitor` object to `StageServer.start`. The "Dot indexing is not
  supported for variables of type double" error at `window.monitor.setRefreshRate` happens when
  the 4th argument is a numeric monitor index (e.g. `start(size, false, 1, 'refreshRate', 60)`):
  `StageServer.start` only builds a Monitor when nargin < 4 and `Window` stores whatever it gets.
  Suggest to Mike: validate/convert a numeric `monitor` in `StageServer.start`, and add a
  `'refreshRate'` passthrough to `StartStage('headless', ...)`.

### Switch scripts and login default (Stage PC, 2026-10-07, approved by Greg)

- `stagepc\Start-Stage3.bat`, `Start-Stage2.bat`, `Stop-StageServers.bat` (+ `.ps1` helper,
  `README.md`). Each switch stops whatever Stage server is running (by listening port
  5678/5679, launch command line, and child processes), then starts the other. All three
  verified on this PC.
- Desktop shortcuts: **Switch to Stage 3**, **Switch to Stage 2**, **Stop Stage servers**.
- **Login default is now Stage 3 fullscreen on the projector** (per-user Startup
  `Stage 3 Server.lnk` → `Start-Stage3.bat`, MATLAB R2026b). The old all-users Startup
  shortcut `C:\ProgramData\...\Startup\stage.lnk` (Stage 2) was moved to
  `stagepc\disabled-startup\stage.lnk`; move it back to restore Stage 2 at login.
- Found while testing: the installed Stage 2 app starts serving fullscreen immediately when
  launched (it does not wait for a Start click), and both servers poll for the escape keys only
  every 10 s (netbox accept/receive timeout), so **left Shift + Esc must be held for up to 10 s**
  with the Stage window focused. Ctrl+Shift+Esc (Task Manager) is the keyboard fallback. Worth
  suggesting a shorter poll interval to Mike.

### Handoff to Rig A (Stage PC, 2026-10-07, end of session)

- Stage 3 is **running now**, fullscreen on the projector, port 5679, MATLAB R2026b, started by
  `stagepc\Start-Stage3.bat` (also the login default). Both switch scripts and the stop script
  were tested by Greg after a reboot.
- Fullscreen localhost check: canvas 912x1140, **measured refresh 60.0080 Hz** (windowed runs
  measured 59.95-59.98 Hz; use the fullscreen figure). 1 s ellipse = 60 frames, steady 16.7 ms
  flips after the first ~6 frames.
- Fork commit on the Stage PC: see `git log -1` (this commit). sa-labs-extension on the server:
  `symphony3-port` @ 115002f.
- Connect from Rig A with host 192.168.0.3, port 5679. The server console prints
  "Client connected from <host>" on connect. If the connection is refused, check that the Stage
  window is up (someone may have switched to Stage 2 via the Desktop shortcut) rather than the
  firewall, which already allows R2026b MATLAB inbound on the rig network.

## 2026-10-08 (Rig A session): the server needs the Symphony 3 core classes too

Finding: every stage protocol whose controller closure captured its protocol object (`obj`) failed on
this server (Annulus, Chirp, ContrastResponse, ... "Timeout (10s) waiting for 512 AI samples" on Rig A,
because no frames were drawn and the frame-tracker trigger never fired). Reproduced headlessly: the
closure deserializes fine when `symphonyui.core.Protocol` is on the path, and `obj` becomes a `double`
("Dot indexing is not supported for variables of type double") when it is not. Two fixes, both applied:

1. `StartStageSchwartzLab.m` now adds the Symphony 3 fork's MATLAB classes when the fork is cloned next
   to this repo. **On this PC, do once:**
   ```
   cd %USERPROFILE%\Documents\MATLAB\Symphony3
   git clone https://github.com/SchwartzNU/symphony3_matlab_schwartzlab_integration.git symphony3_matlab
   ```
   so the layout matches Rig A: `Symphony3\stage3_testbed`, `Symphony3\sa-labs-extension`,
   `Symphony3\symphony3_matlab`. Then `git pull` in `stage3_testbed` and in `sa-labs-extension`
   (branch symphony3-port) and restart the Stage 3 server (Start-Stage3.bat). The launcher prints
   `added Symphony 3 core classes: ...` when it finds the clone.
2. The lab protocols are being rewritten so controller closures carry only plain values (see the
   sa-labs-extension commits of 2026-10-08 and `Symphony3\s3_presentationcheck.m` on Rig A, which
   flags any controller that still captures the protocol object). Keep both: 1 is the safety net.
