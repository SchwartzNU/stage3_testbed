# Stop-StageServers.ps1 - stop every Stage server MATLAB session on this PC.
#
# Finds MATLAB processes that (a) listen on the Stage 2 port 5678 or the Stage 3
# port 5679, or (b) were launched with a Stage server command line (covers a server
# that is still starting up and not yet listening). Nothing else is touched.
# Used by Start-Stage3.bat, Start-Stage2.bat and Stop-StageServers.bat.

$stagePorts = 5678, 5679
$ids = @()

try {
    $ids += Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Where-Object { $_.LocalPort -in $stagePorts } |
        Select-Object -ExpandProperty OwningProcess
} catch {}

try {
    $ids += Get-CimInstance Win32_Process -Filter "Name='MATLAB.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'startStageServer|StartStageSchwartzLab|StartStage\b' } |
        Select-Object -ExpandProperty ProcessId
} catch {}

# R2026b runs a launcher MATLAB.exe (which carries the command line) plus a child
# MATLAB.exe that does the work; include children of anything matched above.
try {
    $all = Get-CimInstance Win32_Process -Filter "Name='MATLAB.exe'" -ErrorAction SilentlyContinue
    $ids += $all | Where-Object { $_.ParentProcessId -in $ids } | Select-Object -ExpandProperty ProcessId
} catch {}

$ids = $ids | Where-Object { $_ -gt 0 } | Sort-Object -Unique
$stopped = 0
foreach ($id in $ids) {
    $p = Get-Process -Id $id -ErrorAction SilentlyContinue
    if ($p -and $p.ProcessName -ieq 'MATLAB') {
        Write-Host "Stopping Stage server MATLAB (pid $id)"
        Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
        $stopped++
    }
}
if ($stopped -eq 0) {
    Write-Host "No Stage server was running."
} else {
    Start-Sleep -Seconds 2
}
