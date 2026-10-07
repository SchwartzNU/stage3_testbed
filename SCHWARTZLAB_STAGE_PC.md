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
