# Full asset re-extraction, stage 1+2: dbc + maps + vmaps (ASCII only: Windows PowerShell reads this as ANSI)
# Uses the extractors built from our fork in build1; writes to _regen, never touches live data.
# Stage 3 (mmaps with gameobject baking) runs separately once the config is chosen.

$ErrorActionPreference = 'Continue'
$Ex   = 'D:\Game\cmangos\build1\bin\x64_Release\Extractors'
$Cli  = 'D:\Game\70\2.4.3'
$Out  = 'D:\Game\cmangos\_regen'
$Logs = Join-Path $Out 'logs'

New-Item -ItemType Directory -Force -Path $Out, $Logs | Out-Null

function Log($msg) {
    $line = "{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Write-Output $line
    Add-Content -Path (Join-Path $Logs 'pipeline.log') -Value $line -Encoding utf8
}

Log "=== stage 1: ad.exe -> dbc + maps ==="
$sw = [System.Diagnostics.Stopwatch]::StartNew()
& (Join-Path $Ex 'ad.exe') -i $Cli -o $Out *>&1 | Tee-Object -FilePath (Join-Path $Logs 'stage1_ad.log')
Log ("ad.exe exit {0}, {1:N1} min" -f $LASTEXITCODE, $sw.Elapsed.TotalMinutes)

Log "=== stage 2a: vmap_extractor.exe -> Buildings ==="
$sw.Restart()
& (Join-Path $Ex 'vmap_extractor.exe') -d (Join-Path $Cli 'Data') -o $Out *>&1 | Tee-Object -FilePath (Join-Path $Logs 'stage2_vmapextract.log')
$rc = $LASTEXITCODE
Log ("vmap_extractor.exe exit {0}, {1:N1} min" -f $rc, $sw.Elapsed.TotalMinutes)

if ($rc -eq 0) {
    Log "=== stage 2b: vmap_assembler.exe -> vmaps ==="
    $sw.Restart()
    & (Join-Path $Ex 'vmap_assembler.exe') (Join-Path $Out 'Buildings') (Join-Path $Out 'vmaps') *>&1 | Tee-Object -FilePath (Join-Path $Logs 'stage2_assemble.log')
    Log ("vmap_assembler.exe exit {0}, {1:N1} min" -f $LASTEXITCODE, $sw.Elapsed.TotalMinutes)
} else {
    Log "vmap extraction failed, skipping assembly (see stage2_vmapextract.log)"
}

Log "=== stats ==="
foreach ($d in @('dbc','maps','vmaps','Buildings')) {
    $p = Join-Path $Out $d
    if (Test-Path $p) {
        $files = Get-ChildItem $p -Recurse -File -ErrorAction SilentlyContinue
        $mb = [math]::Round((($files | Measure-Object Length -Sum).Sum / 1MB), 1)
        Log ("  {0}: {1} files, {2} MB" -f $d, $files.Count, $mb)
    } else { Log ("  {0}: missing" -f $d) }
}
Log "=== stage 1+2 done ==="
