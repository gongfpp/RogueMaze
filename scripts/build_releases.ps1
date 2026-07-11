param(
    [switch]$Android,
    [switch]$Desktop
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

function Invoke-GodotExport([string[]]$Arguments) {
    $output = & "$PSScriptRoot\run_godot.ps1" @Arguments 2>&1
    $output | ForEach-Object { Write-Host $_ }
    $text = $output -join "`n"
    if (
        $LASTEXITCODE -ne 0 -or
        $text -match 'Cannot export project with preset' -or
        $text -match 'Project export for preset .* failed' -or
        $text -match 'SCRIPT ERROR|Failed to load script'
    ) {
        throw "Godot export failed."
    }
}

Push-Location $projectRoot
try {
    if (-not $Android -and -not $Desktop) {
        $Desktop = $true
    }
    & "$PSScriptRoot\test_all.ps1"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    if ($Desktop) {
        New-Item -ItemType Directory -Force builds\windows, builds\linux | Out-Null
        Invoke-GodotExport @('--headless', '--path', '.', '--export-release', 'Windows Desktop', 'builds\windows\RogueMaze.exe')
        Invoke-GodotExport @('--headless', '--path', '.', '--export-release', 'Linux', 'builds\linux\RogueMaze.x86_64')
    }

    if ($Android) {
        New-Item -ItemType Directory -Force builds\android | Out-Null
        Invoke-GodotExport @('--headless', '--path', '.', '--export-debug', 'Android', 'builds\android\RogueMaze-debug.apk')
    }
}
finally {
    Pop-Location
}
