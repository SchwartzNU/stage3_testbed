# StageWatchdog.ps1 - restart the Stage server on this PC on request from the rig PC.
#
# Listens on TCP port 5680 (rig network only). Protocol: one line per connection.
#   restart <token>   stop every Stage server and run Start-Stage3.bat (windowed if the
#                     line is "restart <token> windowed"); replies "ok restarting"
#   status <token>    replies "ok listening" if a MATLAB process listens on 5679,
#                     otherwise "ok not-listening"
#   anything else     replies "error"
# The token is the content of StageWatchdog.token next to this script (plain text);
# Install-StageWatchdog.bat creates it. It only stops someone on the lab network
# from restarting the projector by accident; this is not a security boundary.
#
# Installed by Install-StageWatchdog.bat as a hidden logon task; log in
# %LOCALAPPDATA%\StageWatchdog\watchdog.log. Rig side: restartStageServer.m
# (Documents\MATLAB\Symphony3 on Rig A).

$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$port = 5680
$logDir = Join-Path $env:LOCALAPPDATA 'StageWatchdog'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$log = Join-Path $logDir 'watchdog.log'
$tokenFile = Join-Path $here 'StageWatchdog.token'
if (-not (Test-Path $tokenFile)) { 'stage' | Set-Content -Path $tokenFile -Encoding ascii }
$token = (Get-Content -Path $tokenFile -Raw).Trim()

function Write-Log($msg) {
    $line = "{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Add-Content -Path $log -Value $line
}

function Test-StageListening {
    try {
        $c = Get-NetTCPConnection -State Listen -LocalPort 5679 -ErrorAction SilentlyContinue
        return ($null -ne $c -and @($c).Count -gt 0)
    } catch { return $false }
}

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $port)
$listener.Start()
Write-Log "listening on $port"

while ($true) {
    try {
        $client = $listener.AcceptTcpClient()
        $client.ReceiveTimeout = 5000
        $stream = $client.GetStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $writer = New-Object System.IO.StreamWriter($stream)
        $writer.AutoFlush = $true
        $remote = $client.Client.RemoteEndPoint.ToString()
        $line = ''
        try { $line = $reader.ReadLine() } catch {}
        if ($null -eq $line) { $line = '' }
        $parts = $line.Trim() -split '\s+'
        $cmd = ''
        if ($parts.Count -ge 1) { $cmd = $parts[0].ToLower() }
        $given = ''
        if ($parts.Count -ge 2) { $given = $parts[1] }
        if ($given -ne $token) {
            Write-Log "$remote : bad token for '$cmd'"
            $writer.WriteLine('error bad-token')
        } elseif ($cmd -eq 'status') {
            if (Test-StageListening) { $writer.WriteLine('ok listening') } else { $writer.WriteLine('ok not-listening') }
        } elseif ($cmd -eq 'restart') {
            $mode = ''
            if ($parts.Count -ge 3) { $mode = $parts[2] }
            Write-Log "$remote : restart $mode"
            $writer.WriteLine('ok restarting')
            $bat = Join-Path $here 'Start-Stage3.bat'
            if ($mode -eq 'windowed') {
                Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', ('"' + $bat + '" windowed') -WindowStyle Hidden
            } else {
                Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', ('"' + $bat + '"') -WindowStyle Hidden
            }
        } else {
            $writer.WriteLine('error unknown-command')
        }
        $client.Close()
    } catch {
        Write-Log ("loop error: " + $_.Exception.Message)
        Start-Sleep -Seconds 1
    }
}
