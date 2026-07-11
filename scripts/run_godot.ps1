param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GodotArgs
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godotDirectory = Join-Path $projectRoot '.tools\godot'
$godotBinary = Join-Path $godotDirectory 'Godot_v4.7-stable_win64_console.exe'
$roamingData = Join-Path $projectRoot '.tools\user-data\roaming'
$localData = Join-Path $projectRoot '.tools\user-data\local'

if (-not (Test-Path -LiteralPath $godotBinary)) {
    throw "Godot 4.7 not found at $godotBinary. Follow docs/03-technical/TOOLCHAIN.md."
}

New-Item -ItemType Directory -Force -Path $roamingData | Out-Null
New-Item -ItemType Directory -Force -Path $localData | Out-Null
$env:APPDATA = (Resolve-Path -LiteralPath $roamingData).Path
$env:LOCALAPPDATA = (Resolve-Path -LiteralPath $localData).Path

& $godotBinary @GodotArgs
exit $LASTEXITCODE
