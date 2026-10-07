classdef StageClient < handle
    
    properties (SetAccess = private)
        isConnected
    end

    properties
        % Seconds to wait for the server to answer a control request
        % (getCanvasSize, play acknowledgement, ...). 0 = wait forever, which
        % is how Stage 2 behaved and froze Symphony whenever the server was
        % wedged. Applied on connect; change with setResponseTimeout.
        responseTimeout = 15
    end

    properties (Access = private)
        client
        activeTimeout = 0   % seconds currently applied to the connection (0 = none)
    end

    methods

        function obj = StageClient()
            obj.client = netbox.Client();
        end

        function connect(obj, host, port)
            if nargin < 2
                host = 'localhost';
            end
            if nargin < 3
                port = 5678;
            end
            obj.client.connect(host, port);
            obj.applyTimeout(obj.responseTimeout);
        end

        function setResponseTimeout(obj, seconds)
            % Sets the control-request timeout (seconds, 0 = none).
            obj.responseTimeout = seconds;
            if obj.isConnected
                obj.applyTimeout(seconds);
            end
        end
        
        function disconnect(obj)
            obj.client.disconnect();
        end
        
        function tf = get.isConnected(obj)
            tf = obj.client.isConnected;
        end
        
        function s = getCanvasSize(obj)
            % Gets the remote canvas size.
            e = netbox.NetEvent('getCanvasSize');
            s = obj.sendReceive(e);
        end
        
        function setCanvasProjectionIdentity(obj)
            % Sets the remote canvas projection to identity matrix.
            e = netbox.NetEvent('setCanvasProjectionIdentity');
            obj.sendReceive(e);
        end
        
        function setCanvasProjectionTranslate(obj, x, y, z)
            % Translates the remote canvas projection
            e = netbox.NetEvent('setCanvasProjectionTranslate', {x, y, z});
            obj.sendReceive(e);
        end
        
        function setCanvasProjectionOrthographic(obj, left, right, bottom, top)
            % Sets the remote canvas projection orthographic.
            e = netbox.NetEvent('setCanvasProjectionOrthographic', {left, right, bottom, top});
            obj.sendReceive(e);
        end
        
        function resetCanvasProjection(obj)
            % Resets the remote canvas projection matrix.
            e = netbox.NetEvent('resetCanvasProjection');
            obj.sendReceive(e);
        end
        
        function setCanvasRenderer(obj, renderer)
            % Sets the remote canvas renderer.
            e = netbox.NetEvent('setCanvasRenderer', renderer);
            obj.sendReceive(e);
        end
        
        function resetCanvasRenderer(obj)
            % Resets the remote canvas renderer.
            e = netbox.NetEvent('resetCanvasRenderer');
            obj.sendReceive(e);
        end
        
        function r = getMonitorRefreshRate(obj)
            % Gets the remote monitor refresh rate.
            e = netbox.NetEvent('getMonitorRefreshRate');
            r = obj.sendReceive(e);
        end

        function setMonitorRefreshRate(obj, rate)
            % Pins the remote monitor's refresh rate to a caller-supplied
            % value (Hz). Use when the local rig has a calibrated rate
            % (e.g. a DAQ-clock measurement) more accurate than whatever
            % Stage measured via vsync at startup. Once set, subsequent
            % getMonitorRefreshRate calls return the supplied value and
            % player frame timing uses it directly.
            %
            % Caller responsibility: send only outside of an active play.
            % See TASK-007 / spec/specs/MONITOR_TIMING.md.
            if ~isnumeric(rate) || ~isscalar(rate) || ~isfinite(rate) || rate <= 0
                error('stage:StageClient:invalidRefreshRate', ...
                    'rate must be a positive finite numeric scalar; got %s.', mat2str(rate));
            end
            e = netbox.NetEvent('setMonitorRefreshRate', double(rate));
            obj.sendReceive(e);
        end

        function setMonitorGamma(obj, gamma)
            % Sets the remote monitor gamma ramp from the given gamma exponent.
            e = netbox.NetEvent('setMonitorGamma', gamma);
            obj.sendReceive(e);
        end
        
        function r = getMonitorResolution(obj)
            % Gets the remote monitor resolution.
            e = netbox.NetEvent('getMonitorResolution');
            r = obj.sendReceive(e);
        end
        
        function [red, green, blue] = getMonitorGammaRamp(obj)
            % Gets the remote monitor red, green, and blue gamma ramp.
            e = netbox.NetEvent('getMonitorGammaRamp');
            [red, green, blue] = obj.sendReceive(e);
        end
        
        function setMonitorGammaRamp(obj, red, green, blue)
            % Sets the remote monitor gamma ramp from the given red, green, and blue lookup tables. The tables should 
            % have length of 256 and values that range from 0 to 65535.
            e = netbox.NetEvent('setMonitorGammaRamp', {red, green, blue});
            obj.sendReceive(e);
        end
        
        function play(obj, player)
            % Plays a given player on the remote canvas. This method will return immediately. While the player plays
            % remotely, further attempts to interface with the server will block until the presentation completes.
            e = netbox.NetEvent('play', player);
            obj.sendReceive(e);
        end

        function replay(obj)
            % Replays the last played player on the remote canvas.
            e = netbox.NetEvent('replay');
            obj.sendReceive(e);
        end

        function stop(obj)
            % Requests that the currently-playing presentation terminate
            % early. Blocks until the server acknowledges the stop (usually
            % within one frame period, ~16 ms at 60 Hz). After this returns,
            % getPlayInfo() will return a struct with `stopped = true`.
            %
            % Errors if no play is in progress. See
            % spec/specs/WIRE_PROTOCOL.md § stop.
            e = netbox.NetEvent('stop');
            obj.sendReceive(e);
        end
        
        function i = getPlayInfo(obj, timeoutSeconds)
            % Gets information about the last remotely played (or replayed) presentation.
            % Blocks until the play finishes. Pass timeoutSeconds (e.g. the
            % presentation duration plus a margin) to bound the wait; omit it or
            % pass 0 to wait indefinitely, as before.
            if nargin < 2
                timeoutSeconds = 0;
            end
            e = netbox.NetEvent('getPlayInfo');
            obj.applyTimeout(timeoutSeconds);
            restore = onCleanup(@() obj.applyTimeout(obj.responseTimeout));
            i = obj.sendReceive(e);
        end
        
        function clearMemory(obj)
            % Clears the current connection data and class definitions from the server.
            e = netbox.NetEvent('clearMemory');
            obj.sendReceive(e);
        end
        
    end
    
    methods (Access = protected)
        
        function applyTimeout(obj, seconds)
            % netbox works in milliseconds; 0 disables the timeout.
            try
                obj.client.setReceiveTimeout(round(seconds * 1000));
                obj.activeTimeout = seconds;
            catch
                % not connected yet
            end
        end

        function varargout = sendReceive(obj, event)
            obj.client.sendEvent(event);
            try
                e = obj.client.receiveEvent();
            catch x
                if strcmp(x.identifier, 'Connection:ReceiveTimeout')
                    error('stage:StageClient:timeout', ...
                        ['Stage server did not answer ''%s'' within %g s. The server may be ' ...
                         'wedged or still serving a previous client; restart Stage on the Stage PC.'], ...
                        event.name, obj.activeTimeout);
                end
                rethrow(x);
            end

            switch e.name
                case 'ok'
                    varargout = e.arguments;
                case 'error'
                    rethrow(e.arguments{1});
                otherwise
                    error('Unknown response');
            end
        end
        
    end
    
end

