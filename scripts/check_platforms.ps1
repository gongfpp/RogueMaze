param(
    [switch]$RequireAll
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$androidSdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $projectRoot '.tools\android-sdk' }

function Test-Command($name) {
    return $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

function Add-Result($items, $platform, $check, $ready, $detail) {
    $items.Add([PSCustomObject]@{
        Platform = $platform
        Check = $check
        Ready = if ($ready) { 'YES' } else { 'NO' }
        Detail = $detail
    })
}

$results = [System.Collections.Generic.List[object]]::new()
$presets = Get-Content -LiteralPath (Join-Path $projectRoot 'export_presets.cfg') -Raw

Add-Result $results 'Windows' 'Export preset' ($presets.Contains('name="Windows Desktop"')) 'Windows Desktop preset'
Add-Result $results 'Linux' 'Export preset' ($presets.Contains('name="Linux"')) 'Linux x86_64 preset'
Add-Result $results 'Android' 'Export preset' ($presets.Contains('name="Android"')) 'arm64 APK preset; no runtime permissions'
Add-Result $results 'Android' 'JDK 17' (Test-Command 'java') 'Run java -version to inspect the exact version'
Add-Result $results 'Android' 'SDK root' (Test-Path -LiteralPath $androidSdk) $androidSdk
Add-Result $results 'Android' 'Platform Tools' (Test-Path -LiteralPath (Join-Path $androidSdk 'platform-tools\adb.exe')) 'Requires 35.0.0 or newer'
Add-Result $results 'Android' 'Build Tools' (Test-Path -LiteralPath (Join-Path $androidSdk 'build-tools\35.0.1')) 'Required version: 35.0.1'
Add-Result $results 'Android' 'Platform 35' (Test-Path -LiteralPath (Join-Path $androidSdk 'platforms\android-35')) 'Required platform: android-35'
Add-Result $results 'Android' 'NDK r28b' (Test-Path -LiteralPath (Join-Path $androidSdk 'ndk\28.1.13356709')) 'Required for Gradle/custom template builds'
Add-Result $results 'iOS' 'Export preset' ($presets.Contains('name="iOS"')) 'Xcode project-only preset'
Add-Result $results 'iOS' 'macOS/Xcode' (Test-Command 'xcodebuild') 'iOS export must run on macOS with Xcode'
$teamId = $env:GODOT_IOS_TEAM_ID
Add-Result $results 'iOS' 'Team ID' ($teamId -match '^[A-Z0-9]{10}$') 'Set GODOT_IOS_TEAM_ID in the macOS release environment'

$results | Format-Table -AutoSize

$notReady = @($results | Where-Object { $_.Ready -eq 'NO' })
if ($RequireAll -and $notReady.Count -gt 0) {
    Write-Error ("Platform readiness failed: {0} check(s) are not ready." -f $notReady.Count)
    exit 1
}

Write-Output ("Platform readiness: {0}/{1} checks ready." -f ($results.Count - $notReady.Count), $results.Count)
