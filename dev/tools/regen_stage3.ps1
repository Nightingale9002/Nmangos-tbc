# Stage 3: full mmaps regeneration, production config + map 530 offmesh + every gameobject collision
$Ex     = 'D:\Game\cmangos\build1\bin\x64_Release\Extractors'
$Work   = 'D:\Game\cmangos\_regen'
$Log    = Join-Path $Work 'logs\stage3_mmaps.log'

function Log($m) {
    $line = "{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
    Write-Output $line
    Add-Content -Path (Join-Path $Work 'logs\pipeline.log') -Value $line -Encoding utf8
}

Log "=== stage 3: MoveMapGen all maps (production cfg + GO bake) ==="
$sw = [System.Diagnostics.Stopwatch]::StartNew()
& (Join-Path $Ex 'MoveMapGen.exe') --workdir $Work `
    --configInputPath (Join-Path $Work 'config_prod.json') `
    --offMeshInput (Join-Path $Work 'offmesh_530_all.txt') `
    --gameObjectInput (Join-Path $Work 'go_bake_all.txt') `
    --silent --threads 16 *>&1 | Tee-Object -FilePath $Log
$rc = $LASTEXITCODE
Log ("MoveMapGen.exe exit {0}, {1:N1} min" -f $rc, $sw.Elapsed.TotalMinutes)
$n = (Get-ChildItem (Join-Path $Work 'mmaps') -File -ErrorAction SilentlyContinue).Count
$mb = [math]::Round(((Get-ChildItem (Join-Path $Work 'mmaps') -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB), 1)
Log ("mmaps: {0} files, {1} MB" -f $n, $mb)
Log "=== stage 3 done ==="
