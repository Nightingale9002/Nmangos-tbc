# Replica monitor: watch the local MySQL 8.0 replica on port 3307 (source = cloud master
# through the SSH tunnel on 16306). Logs every state change, keeps a status file, and
# appends a line to the cloud watchdog log on state changes. ASCII only on purpose:
# Windows PowerShell parses this file as ANSI, non-ASCII breaks quoting.
#
# Task: WoW_ReplicaMonitor, every 5 minutes.

$ErrorActionPreference = 'Continue'

$mysqlExe = 'C:\Program Files\MySQL\MySQL Server 9.3\bin\mysql.exe'
# credentials live outside the repo (this file is also copied to dev/tools/ for reference)
$credFile = 'D:\Game\cmangos\.replica_cred'
$mysqlPw  = ''
if (Test-Path $credFile) { $mysqlPw = (Get-Content $credFile -Raw).Trim() }
$logFile  = 'D:\Game\cmangos\replica_monitor.log'
$statFile = 'D:\Game\cmangos\replica_monitor.status'
$sshKey   = 'C:\Users\nYmpH\.ssh\codex_ecs_deploy'
$sshHost  = 'root@39.96.90.39'
$lagWarnS = 300
$tunnelPort = 16306
$replicaPort = 3307

function Write-Log([string]$text) {
    $line = "{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $text
    Add-Content -Path $logFile -Value $line -Encoding utf8
}

function Query([string]$sql) {
    # NOTE: no -B and no -N here: SHOW SLAVE STATUS\G only yields labelled "field: value"
    # lines in the non-batch format with column names - batch/-N turn it into bare values.
    & $mysqlExe '--host=127.0.0.1' "--port=$replicaPort" '--user=root' "--password=$mysqlPw" '-e' $sql 2>$null
}

# --- 1. tunnel (a closed tunnel is the most common cause of a stalled replica) ---
$tunnelUp = $false
try {
    $tunnelUp = [bool](Get-NetTCPConnection -State Listen -LocalPort $tunnelPort -ErrorAction SilentlyContinue)
} catch { $tunnelUp = $false }

# --- 2. replication state ---
$io = 'n/a'; $sqlThread = 'n/a'; $lag = 'n/a'; $errno = 'n/a'; $relay = 'n/a'; $lastErr = ''
$raw = Query 'SHOW SLAVE STATUS\G'
if (-not $raw) {
    $state = 'DOWN'
    $detail = 'replica not reachable on port ' + $replicaPort + ' (mysql query failed)'
} else {
    foreach ($l in $raw) {
        if ($l -match '^\s*Slave_IO_Running:\s*(\S+)')            { $io = $Matches[1] }
        elseif ($l -match '^\s*Slave_SQL_Running:\s*(\S+)')       { $sqlThread = $Matches[1] }
        elseif ($l -match '^\s*Seconds_Behind_Master:\s*(\S+)')   { $lag = $Matches[1] }
        elseif ($l -match '^\s*Last_Errno:\s*(\S+)')              { $errno = $Matches[1] }
        elseif ($l -match '^\s*Relay_Log_Space:\s*(\S+)')         { $relay = $Matches[1] }
        elseif ($l -match '^\s*Last_Error:\s*(.+)$')              { $lastErr = $Matches[1].Trim() }
    }
    $lagNum = -1
    if ($lag -match '^\d+$') { $lagNum = [int]$lag }
    if ($io -ne 'Yes' -or $sqlThread -ne 'Yes') {
        $state = 'BROKEN'
        $detail = "io=$io sql=$sqlThread errno=$errno err=$lastErr"
    } elseif ($lagNum -lt 0) {
        $state = 'UNKNOWN'
        $detail = "lag is NULL (io=$io sql=$sqlThread)" 
    } elseif ($lagNum -gt $lagWarnS) {
        $state = 'LAGGING'
        $detail = "lag=${lagNum}s relay=${relay}B"
    } else {
        $state = 'OK'
        $detail = "io=$io sql=$sqlThread lag=${lagNum}s relay=${relay}B"
    }
}
if (-not $tunnelUp) { $detail = "tunnel port $tunnelPort NOT listening; " + $detail }

# --- 3. status file (every run) + log/alert only on state change ---
"{0} state={1} tunnel={2} {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $state, $tunnelUp, $detail |
    Set-Content -Path $statFile -Encoding utf8

$prev = ''
if (Test-Path $logFile) {
    $last = Get-Content $logFile -Tail 1 -ErrorAction SilentlyContinue
    if ($last -match 'state=([A-Z]+)') { $prev = $Matches[1] }
}
if ($state -ne $prev) {
    Write-Log ("state={0} (was {1}) tunnel={2} {3}" -f $state, $(if ($prev) { $prev } else { 'none' }), $tunnelUp, $detail)
    # best effort: leave a line in the cloud watchdog log so it shows up in the usual place
    if ($state -ne 'OK') {
        $msg = "replica-monitor: local MySQL replica state=$state $detail"
        & ssh -i $sshKey -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes $sshHost "echo `"`$(date '+%F %T') $msg`" >> /opt/mangos/logs/watchdog.log" 2>$null
    }
}

exit 0
