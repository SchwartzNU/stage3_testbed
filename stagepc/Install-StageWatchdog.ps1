# Install-StageWatchdog.ps1 - install the Stage watchdog on the Stage PC.
#
# Run as the user that logs in on the Stage PC (SchwartzLab), NOT from an elevated
# prompt of another account: the watchdog and the Stage servers it starts must run in
# this user's session (MATLAB's jenv Java binding and the Stage 3 launcher paths are
# per user). Double-click Install-StageWatchdog.bat.
#
# Steps (1-3 need no administrator rights):
#   1. Create stagepc\StageWatchdog.token (random) if missing and print it.
#   2. Put "Stage Watchdog.lnk" in this user's Startup folder so the watchdog starts
#      hidden at logon (same mechanism as "Stage 3 Server.lnk").
#   3. Start the watchdog now (hidden) if port 5680 is not already in use.
#   4. Firewall: allow inbound TCP 5680 on ALL profiles. On this PC the rig Ethernet
#      ("Unidentified network", 192.168.0.x) is on the Public profile, so a
#      private/domain-only rule would block the rig PC. This step needs elevation:
#      a UAC prompt appears; if it is declined or fails, the exact netsh command is
#      printed to run from an administrator prompt.
#
# Uninstall: delete "Stage Watchdog.lnk" from the Startup folder, stop the hidden
# powershell.exe that runs StageWatchdog.ps1, and (as administrator)
#   netsh advfirewall firewall delete rule name="Stage watchdog 5680"

$ErrorActionPreference = 'Stop'

# Refuse to run elevated: on this PC elevation means a different account, and the
# Startup shortcut / watchdog process would then belong to that account.
$isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isElevated) {
    Write-Host 'This installer must NOT be run as administrator / elevated.'
    Write-Host "It is running as '$env:USERNAME' (elevated). Close this window and double-click"
    Write-Host 'Install-StageWatchdog.bat normally, as the user that logs in on the Stage PC.'
    Write-Host 'Only the firewall step needs elevation, and it asks for it by itself (UAC).'
    exit 1
}

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $here 'StageWatchdog.ps1'
$tokenFile = Join-Path $here 'StageWatchdog.token'
$port = 5680

# 1. token
if (-not (Test-Path $tokenFile)) {
    $rand = New-Object System.Random
    ('stage-{0}{1}' -f $rand.Next(10000, 99999), $rand.Next(10000, 99999)) | Set-Content -Path $tokenFile -Encoding ascii
}
$token = (Get-Content -Path $tokenFile -Raw).Trim()
Write-Host ''
Write-Host 'Watchdog token (set on the rig PC once with setpref(''SymphonyUI'',''stageWatchdogToken'',''<token>'')):'
Write-Host "  $token"
Write-Host ''

# 2. per-user Startup shortcut
$startup = [Environment]::GetFolderPath('Startup')
$lnkPath = Join-Path $startup 'Stage Watchdog.lnk'
$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut($lnkPath)
$lnk.TargetPath = 'powershell.exe'
$lnk.Arguments = ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f $script)
$lnk.WorkingDirectory = $here
$lnk.WindowStyle = 7
$lnk.Description = 'Stage watchdog: remote restart of the Stage server (TCP 5680)'
$lnk.Save()
Write-Host "Startup shortcut: $lnkPath"

# 3. start now
$busy = $null
try { $busy = Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue } catch {}
if ($busy) {
    Write-Host "Port $port already has a listener (pid $($busy.OwningProcess)); not starting a second watchdog."
} else {
    Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', "`"$script`"") -WindowStyle Hidden
    Start-Sleep -Seconds 3
    $now = $null
    try { $now = Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue } catch {}
    if ($now) { Write-Host "Watchdog started (pid $($now.OwningProcess)), listening on $port." }
    else { Write-Host "Watchdog did not start; see $env:LOCALAPPDATA\StageWatchdog\watchdog.log" }
}

# 4. firewall (needs elevation)
$ruleName = 'Stage watchdog 5680'
$netshArgs = "advfirewall firewall add rule name=`"$ruleName`" dir=in action=allow protocol=TCP localport=$port profile=any"
$existing = netsh advfirewall firewall show rule name="$ruleName" 2>$null
if ($existing -match 'Profiles:\s+(Domain,Private,Public|Any)') {
    Write-Host "Firewall rule '$ruleName' already allows all profiles."
} else {
    Write-Host 'Adding the firewall rule (UAC prompt)...'
    try {
        # Delete any older private/domain-only rule, then add the all-profile rule, in one elevated cmd.
        $cmd = "netsh advfirewall firewall delete rule name=`"$ruleName`" & netsh $netshArgs"
        $p = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $cmd -Verb RunAs -Wait -PassThru
        if ($p.ExitCode -eq 0) { Write-Host "Firewall rule '$ruleName' added (all profiles)." }
        else { throw "exit code $($p.ExitCode)" }
    } catch {
        Write-Host ''
        Write-Host "Could not add the firewall rule ($($_.Exception.Message)). From an ADMINISTRATOR prompt run:"
        Write-Host "  netsh $netshArgs"
    }
}

Write-Host ''
Write-Host "Done. Log: $env:LOCALAPPDATA\StageWatchdog\watchdog.log"
Write-Host 'Test from the rig PC: restartStageServer status'
