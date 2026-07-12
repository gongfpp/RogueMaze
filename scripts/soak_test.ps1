param(
    [ValidateRange(1, 5000)]
    [int]$Runs = 250
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    $output = & "$PSScriptRoot\run_godot.ps1" --headless --path . --script tests/godot/soak_runner.gd -- "--runs=$Runs" 2>&1
    $output | ForEach-Object { Write-Host $_ }
    $text = $output -join "`n"
    if (
        $LASTEXITCODE -ne 0 -or
        $text -match 'SCRIPT ERROR|Failed to load script' -or
        $text -notmatch "Godot soak: $Runs expedition\(s\), \d+ invariant check\(s\), all passed"
    ) {
        exit 1
    }
    exit 0
}
finally {
    Pop-Location
}
