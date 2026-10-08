function StartStageSchwartzLab(varargin)
%STARTSTAGESCHWARTZLAB  Run Stage 3 on the Schwartz Lab Stage PC, next to Stage 2.
%
%   The Stage PC (192.168.0.3) runs the production Stage 2 "Stage Server" app
%   on TCP port 5678 for Symphony 2. This launcher starts the Stage 3 server
%   from this source tree in a SEPARATE MATLAB session on port 5679 for
%   Symphony 3, without touching the Stage 2 install.
%
%   Usage (from a MATLAB session, or via StartStageSchwartzLab.bat):
%     StartStageSchwartzLab()             fullscreen on the projector (monitor 1), port 5679
%     StartStageSchwartzLab('windowed')   640x480 window, not fullscreen (smoke test;
%                                         does not take over the projector)
%     StartStageSchwartzLab(..., 'port', P, 'monitor', N, 'size', [W H], ...
%                           'fullscreen', TF, 'refreshRate', R)
%
%   What it does, in this MATLAB session only (nothing is saved with savepath):
%     1. Removes the installed Stage 2 toolbox / "Stage Server" app and the
%        production sa-labs-extension (master) from the path so they cannot
%        shadow the Stage 3 source tree.
%     2. Adds the Stage 3 source tree (StartStage('pathsonly')).
%     3. Adds the symphony3-port clone of sa-labs-extension so the server can
%        deserialize the lab's custom stimulus classes (sa_labs.util.*), which
%        arrive Java-serialized inside the Player.
%     4. Makes ffmpeg (winget install Gyan.FFmpeg) callable if it is not yet on
%        PATH (Movie stimuli).
%     5. Starts stage.core.network.StageServer on the requested port.
%
%   Stop the server with shift + escape while the Stage window has focus.

    ip = inputParser();
    ip.addOptional('mode', '', @(x) ischar(x) || isstring(x));
    ip.addParameter('port', 5679, @(x) isnumeric(x) && isscalar(x));
    ip.addParameter('monitor', 1, @(x) isnumeric(x) && isscalar(x));
    ip.addParameter('size', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
    ip.addParameter('fullscreen', [], @(x) isempty(x) || islogical(x) || ismember(x, [0, 1]));
    ip.addParameter('refreshRate', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
    ip.parse(varargin{:});
    r = ip.Results;

    windowed = strcmpi(char(r.mode), 'windowed');
    if isempty(r.fullscreen)
        fullscreen = ~windowed;
    else
        fullscreen = logical(r.fullscreen);
    end
    if isempty(r.size)
        if windowed
            canvasSize = [640 480];
        else
            canvasSize = [];   % resolved from the monitor below
        end
    else
        canvasSize = r.size;
    end
    if r.port == 5678
        error('StartStageSchwartzLab:port5678', ...
            'Port 5678 belongs to the production Stage 2 server on this PC. Use 5679.');
    end

    root = fileparts(mfilename('fullpath'));

    % ---- 1. Drop Stage 2 and the production sa-labs-extension from this session's path.
    prodExt = fullfile(fileparts(fileparts(fileparts(root))), 'sa-labs-extension'); % Documents\MATLAB\sa-labs-extension
    shadowPatterns = { ...
        [filesep 'Add-Ons' filesep 'Toolboxes' filesep 'Stage'], ...
        [filesep 'Add-Ons' filesep 'Apps' filesep 'StageServer'], ...
        prodExt};
    entries = strsplit(path, pathsep);
    drop = false(size(entries));
    for k = 1:numel(shadowPatterns)
        drop = drop | ~cellfun(@isempty, strfind(entries, shadowPatterns{k})); %#ok<STRCL1>
    end
    if any(drop)
        rmpath(entries{drop});
        fprintf('[StartStageSchwartzLab] removed %d Stage 2 / sa-labs-extension(master) path entries (this session only)\n', nnz(drop));
    end

    % ---- 2. Stage 3 source tree.
    addpath(root);
    StartStage('pathsonly');

    % ---- 3. Lab stimulus classes (symphony3-port clone next to this repo).
    labExt = fullfile(fileparts(fileparts(root)), 'sa-labs-extension', 'src', 'main', 'matlab');
    if exist(fullfile(labExt, '+sa_labs'), 'dir')
        addpath(labExt);
        fprintf('[StartStageSchwartzLab] added sa-labs-extension (symphony3-port): %s\n', labExt);
    else
        fprintf(2, ['[StartStageSchwartzLab] WARNING: sa-labs-extension (symphony3-port) not found at\n' ...
            '  %s\n  Custom lab stimuli (sa_labs.util.*) will fail to deserialize.\n'], labExt);
    end

    % ---- 3b. Symphony 3 core MATLAB classes (symphony3_matlab clone next to this repo).
    % Controller closures that capture the protocol object only deserialize when
    % symphonyui.core.Protocol etc. exist on the server path; without them the
    % protocol becomes a double and the controller fails ("Dot indexing is not
    % supported for variables of type double"), no frames are drawn, and the
    % rig's frame-tracker trigger never fires (Rig A, 2026-10-08).
    symFork = fullfile(fileparts(fileparts(root)), 'symphony3_matlab');
    symSrc = fullfile(symFork, 'code', 'src', 'matlab');
    if exist(fullfile(symSrc, '+symphonyui'), 'dir')
        addpath(symSrc);
        addpath(genpath(fullfile(symFork, 'code', 'lib')));
        fprintf('[StartStageSchwartzLab] added Symphony 3 core classes: %s\n', symSrc);
    else
        fprintf(2, ['[StartStageSchwartzLab] WARNING: symphony3_matlab clone not found at\n' ...
            '  %s\n  Any controller closure that captures its protocol object will fail on this server.\n'], symFork);
    end

    % ---- 4. ffmpeg for Movie stimuli.
    [ffStatus, ~] = system('ffmpeg -version');
    if ffStatus ~= 0 && ispc
        cands = dir(fullfile(getenv('LOCALAPPDATA'), 'Microsoft', 'WinGet', 'Packages', 'Gyan.FFmpeg*', 'ffmpeg-*', 'bin', 'ffmpeg.exe'));
        if ~isempty(cands)
            setenv('PATH', [cands(1).folder pathsep getenv('PATH')]);
            fprintf('[StartStageSchwartzLab] ffmpeg: added %s to PATH\n', cands(1).folder);
        else
            fprintf(2, '[StartStageSchwartzLab] ffmpeg not found; Movie stimuli will fail (winget install Gyan.FFmpeg).\n');
        end
    end

    % ---- 5. Start the server.
    monitor = stage.core.Monitor(r.monitor);
    if isempty(canvasSize)
        canvasSize = monitor.resolution;
    end
    fprintf('[StartStageSchwartzLab] Stage 3 server:\n');
    fprintf('             port       = %d\n', r.port);
    fprintf('             monitor    = %d (%s, %dx%d @ %g Hz nominal)\n', r.monitor, monitor.name, ...
        monitor.resolution(1), monitor.resolution(2), monitor.refreshRate);
    fprintf('             size       = [%d %d]\n', canvasSize(1), canvasSize(2));
    fprintf('             fullscreen = %s\n', mat2str(fullscreen));
    if ~isempty(r.refreshRate)
        fprintf('             refreshRate= %g Hz (pinned)\n', r.refreshRate);
    end
    fprintf(['[StartStageSchwartzLab] To stop: click the Stage window, then HOLD left Shift + Esc\n' ...
             '             for up to 10 s (keys are polled every 10 s). Or Ctrl+Shift+Esc -> Task Manager.\n']);

    server = stage.core.network.StageServer(r.port);
    if isempty(r.refreshRate)
        server.start(canvasSize, fullscreen, monitor);
    else
        server.start(canvasSize, fullscreen, monitor, 'refreshRate', r.refreshRate);
    end
end
