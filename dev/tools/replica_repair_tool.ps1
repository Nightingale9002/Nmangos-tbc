# Repair the local 8.0 replica (port 3307): duplicate-key (1062) conflicts caused by
# an older manual import that seeded log tables beyond the replication position.
# Strategy (option A, data-precise): for every 1062 on a single-column PRIMARY key,
# delete exactly that row on the replica and restart the SQL thread. Stop as soon as
# the SQL thread stays up, or when a conflict appears that cannot be handled safely.
# ASCII only.
$mysql = 'C:\Program Files\MySQL\MySQL Server 9.3\bin\mysql.exe'
$pw    = 'tH4H4-=dq_kPp1=-mZ=='
$log   = 'D:\Game\cmangos\_agent_tmp\replica_repair.log'

function M([string]$sql) {
    & $mysql '--host=127.0.0.1' '--port=3307' '--user=root' "--password=$pw" '-N' '-B' '-e' $sql 2>$null
}
function Log($m) {
    $line = "{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m
    Write-Output $line
    Add-Content -Path $log -Value $line -Encoding utf8
}

Add-Content -Path $log -Value ("=== repair run 2 {0} ===" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -Encoding utf8

$deadline = (Get-Date).AddMinutes(25)
$fixed = 0
$i = 0
while ((Get-Date) -lt $deadline) {
    $i++
    $err = M "SELECT LAST_ERROR_MESSAGE FROM performance_schema.replication_applier_status_by_worker WHERE LAST_ERROR_NUMBER<>0 LIMIT 1;"
    $err = ($err -join ' ')
    if (-not $err.Trim()) {
        $sr = (M "SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME='Slave_running';") -join ''
        $behind = (M "SELECT SECONDS_BEHIND_MASTER FROM performance_schema.replication_applier_status LIMIT 1;") -join ''
        Log ("iter {0}: no pending error; Slave_running={1}" -f $i, $sr)
        if ($sr -match 'ON') {
            Start-Sleep -Seconds 25
            $sr2 = (M "SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME='Slave_running';") -join ''
            if ($sr2 -match 'ON') { Log "SQL thread stable -> done (fixed $fixed conflicts)"; break }
            Log ("stopped again -> continue (Slave_running={0})" -f $sr2)
        } else {
            M "START SLAVE;" | Out-Null
            Start-Sleep -Seconds 8
        }
        continue
    }

    if ($err -match "Duplicate entry '([^']*)' for key '([^'.]+)\.([^']+)'") {
        $val = $Matches[1]; $tbl = $Matches[2]; $keyname = $Matches[3]
        $schema = 'tbclogs'; $table = $tbl
        if ($tbl -match '^(tbcmangos|tbcrealmd|tbccharacters|tbclogs)_?(.*)$') { }
        # find the real database for this table name
        $dbs = M "SELECT table_schema FROM information_schema.tables WHERE table_name='$tbl' AND table_schema IN ('tbcmangos','tbcrealmd','tbccharacters','tbclogs');"
        if ($dbs) { $schema = ($dbs | Select-Object -First 1).Trim() }

        # single-column PRIMARY key?
        $pkcols = M "SELECT COLUMN_NAME FROM information_schema.key_column_usage WHERE table_schema='$schema' AND table_name='$tbl' AND constraint_name='PRIMARY';"
        $pkcols = @($pkcols | Where-Object { $_ -and $_.Trim() -ne '' })
        if ($keyname -eq 'PRIMARY' -and $pkcols.Count -eq 1) {
            $col = $pkcols[0].Trim()
            Log ("iter {0}: 1062 {1}.{2} {3}={4} -> delete row" -f $i, $schema, $tbl, $col, $val)
            M "STOP SLAVE;" | Out-Null
            $del = M ("DELETE FROM ``$schema``.``$tbl`` WHERE ``$col`` = '$val'; SELECT ROW_COUNT();")
            Log ("   deleted: {0}" -f (($del | Where-Object { $_ -match '^\d+$' }) -join ','))
            M "START SLAVE;" | Out-Null
            $fixed++
            Start-Sleep -Seconds 5
            continue
        }

        Log ("iter {0}: 1062 on {1}.{2} key={3} value={4} (composite or non-PRIMARY) -> stopping for manual decision" -f $i, $schema, $tbl, $keyname, $val)
        break
    }

    Log ("iter {0}: unexpected error -> {1}" -f $i, ($err -replace '\s+', ' '))
    break
}

Log "=== final status ==="
$st = M "SHOW SLAVE STATUS\G"
$st | Where-Object { $_ -match 'Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Last_Errno|Exec_Master_Log_Pos|Read_Master_Log_Pos|Relay_Log_Space' } | ForEach-Object { Log ("  " + $_.Trim()) }
