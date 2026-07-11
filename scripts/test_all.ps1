$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    npm test
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & "$PSScriptRoot\run_godot.ps1" --headless --editor --path . --quit
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & "$PSScriptRoot\run_godot.ps1" --headless --path . --script tests/godot/test_runner.gd
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
