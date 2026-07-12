param(
    [switch]$Android,
    [switch]$Desktop
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildInfoPath = Join-Path $projectRoot 'assets\build\build_info.json'

function New-BuildInfo([string]$Platform, [string]$Configuration = 'release') {
    $generatorOutput = & node "$PSScriptRoot\generate_build_info.mjs" --platform $Platform --configuration $Configuration
    $generatorExitCode = $LASTEXITCODE
    $generatorOutput | ForEach-Object { Write-Host $_ }
    if ($generatorExitCode -ne 0 -or -not (Test-Path -LiteralPath $buildInfoPath)) {
        throw "Build identity generation failed."
    }
    return Get-Content -LiteralPath $buildInfoPath -Raw | ConvertFrom-Json
}

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

function Invoke-WindowsSmokeTest($ExpectedBuildInfo) {
    $smokeBinary = '.\builds\windows\RogueMaze.console.exe'
    if (-not (Test-Path -LiteralPath $smokeBinary)) {
        throw "Windows console wrapper is missing."
    }
    $output = & $smokeBinary --headless -- --smoke 2>&1
    $output | ForEach-Object { Write-Host $_ }
    $text = $output -join "`n"
    $expectedBuildMarker = "RogueMaze smoke: build v{0} platform=windows configuration=release commit={1}" -f `
        $ExpectedBuildInfo.version, $ExpectedBuildInfo.commit_short
    if (
        $LASTEXITCODE -ne 0 -or
        -not $text.Contains($expectedBuildMarker) -or
        $text -notmatch 'RogueMaze smoke: legal notices ready' -or
        $text -notmatch 'RogueMaze smoke: main scene ready'
    ) {
        throw "Windows release smoke test failed."
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
        $windowsBuildInfo = New-BuildInfo 'windows'
        Invoke-GodotExport @('--headless', '--path', '.', '--export-release', 'Windows Desktop', 'builds\windows\RogueMaze.exe')
        Invoke-WindowsSmokeTest $windowsBuildInfo
        $null = New-BuildInfo 'linux'
        Invoke-GodotExport @('--headless', '--path', '.', '--export-release', 'Linux', 'builds\linux\RogueMaze.x86_64')
    }

    if ($Android) {
        New-Item -ItemType Directory -Force builds\android | Out-Null
        $null = New-BuildInfo 'android' 'debug'
        Invoke-GodotExport @('--headless', '--path', '.', '--export-debug', 'Android', 'builds\android\RogueMaze-debug.apk')
    }
}
finally {
    Remove-Item -LiteralPath $buildInfoPath -Force -ErrorAction SilentlyContinue
    Pop-Location
}
