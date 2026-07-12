param(
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    if (-not $SkipBuild) {
        & "$PSScriptRoot\build_releases.ps1" -Desktop
        if ($LASTEXITCODE -ne 0) {
            throw "Desktop release build failed; no playtest package was created."
        }
    }

    $sourceBinary = Join-Path $projectRoot 'builds\windows\RogueMaze.exe'
    if (-not (Test-Path -LiteralPath $sourceBinary)) {
        throw "Windows release binary is missing. Run without -SkipBuild first."
    }

    $projectText = Get-Content -LiteralPath (Join-Path $projectRoot 'project.godot') -Raw
    $versionMatch = [regex]::Match($projectText, '(?m)^config/version="([^"]+)"$')
    if (-not $versionMatch.Success) {
        throw "project.godot does not contain application config/version."
    }
    $version = $versionMatch.Groups[1].Value
    $commit = (& git rev-parse HEAD).Trim().ToLowerInvariant()
    if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{7,40}$') {
        throw "Unable to resolve the Git commit for the playtest package."
    }
    $shortCommit = $commit.Substring(0, 7)
    $dirty = @(& git status --porcelain).Count -gt 0
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect the Git worktree."
    }

    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
    $packageName = "RogueMaze-{0}-windows-{1}-{2}" -f $version, $shortCommit, $stamp
    $packageDirectory = Join-Path $projectRoot "builds\playtest\$packageName"
    $zipPath = "$packageDirectory.zip"
    New-Item -ItemType Directory -Force -Path $packageDirectory | Out-Null
    Copy-Item -LiteralPath $sourceBinary -Destination (Join-Path $packageDirectory 'RogueMaze.exe') -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\06-playtest\PLAYER_README.txt') `
        -Destination (Join-Path $packageDirectory 'PLAYER_README.txt') -Force

    $buildLabel = "v{0} | WINDOWS | {1}{2}" -f $version, $shortCommit, $(if ($dirty) { '*' } else { '' })
    @(
        "RogueMaze playtest build"
        "Build: $buildLabel"
        "Commit: $commit"
        "Configuration: release"
        "Packaged at UTC: $((Get-Date).ToUniversalTime().ToString('o'))"
        "Dirty worktree: $($dirty.ToString().ToLowerInvariant())"
    ) | Set-Content -LiteralPath (Join-Path $packageDirectory 'BUILD.txt') -Encoding UTF8

    $binaryHash = (Get-FileHash -LiteralPath (Join-Path $packageDirectory 'RogueMaze.exe') -Algorithm SHA256).Hash.ToLowerInvariant()
    "$binaryHash  RogueMaze.exe" | Set-Content `
        -LiteralPath (Join-Path $packageDirectory 'SHA256SUMS.txt') -Encoding ASCII

    Compress-Archive -Path (Join-Path $packageDirectory '*') -DestinationPath $zipPath -CompressionLevel Optimal
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $entries = @($archive.Entries | ForEach-Object { $_.FullName })
        foreach ($required in @('RogueMaze.exe', 'PLAYER_README.txt', 'BUILD.txt', 'SHA256SUMS.txt')) {
            if ($required -notin $entries) {
                throw "Playtest archive is missing $required."
            }
        }
    }
    finally {
        $archive.Dispose()
    }

    Write-Host "Playtest package: $zipPath"
    Write-Host "Build identity: $buildLabel"
    Write-Host "RogueMaze.exe SHA-256: $binaryHash"
}
finally {
    Pop-Location
}
