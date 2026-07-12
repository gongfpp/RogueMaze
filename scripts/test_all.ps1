$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    npm test
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $importOutput = & "$PSScriptRoot\run_godot.ps1" --headless --editor --path . --quit 2>&1
    $importOutput | ForEach-Object { Write-Host $_ }
    $importText = $importOutput -join "`n"
    if ($LASTEXITCODE -ne 0 -or $importText -match 'SCRIPT ERROR|Failed to load script') { exit 1 }

    $testOutput = & "$PSScriptRoot\run_godot.ps1" --headless --path . --script tests/godot/test_runner.gd 2>&1
    $testOutput | ForEach-Object { Write-Host $_ }
    $testText = $testOutput -join "`n"
    if (
        $LASTEXITCODE -ne 0 -or
        $testText -match 'SCRIPT ERROR|Failed to load script' -or
        $testText -notmatch 'Godot rules: \d+ assertion\(s\), all passed'
    ) { exit 1 }

    $soakOutput = & "$PSScriptRoot\run_godot.ps1" --headless --path . --script tests/godot/soak_runner.gd -- --runs=250 2>&1
    $soakOutput | ForEach-Object { Write-Host $_ }
    $soakText = $soakOutput -join "`n"
    if (
        $LASTEXITCODE -ne 0 -or
        $soakText -match 'SCRIPT ERROR|Failed to load script' -or
        $soakText -notmatch 'Godot soak: 250 expedition\(s\), \d+ invariant check\(s\), all passed'
    ) { exit 1 }
    exit 0
}
finally {
    Pop-Location
}
