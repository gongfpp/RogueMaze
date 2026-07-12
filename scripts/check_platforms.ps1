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

function Find-Adb() {
    $command = Get-Command adb -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $candidates = @(
        'C:\Program Files\SideQuest\resources\app.asar.unpacked\build\platform-tools\adb.exe',
        (Join-Path $env:USERPROFILE 'AppData\Roaming\SideQuest\platform-tools\adb.exe'),
        $(if ($env:ANDROID_HOME) { Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe' }),
        $(if ($env:ANDROID_SDK_ROOT) { Join-Path $env:ANDROID_SDK_ROOT 'platform-tools\adb.exe' }),
        (Join-Path $projectRoot '.tools\android-sdk\platform-tools\adb.exe'),
        (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'),
        (Join-Path $env:ProgramFiles 'SideQuest\resources\app.asar.unpacked\build\platform-tools\adb.exe'),
        (Join-Path $env:APPDATA 'SideQuest\platform-tools\adb.exe')
    ) | Where-Object { $_ }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
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
$adbPath = Find-Adb
Add-Result $results 'Android' 'ADB executable' ($null -ne $adbPath) $(if ($adbPath) { $adbPath } else { 'Install platform-tools or set ANDROID_HOME' })
$authorizedDevices = @()
if ($adbPath) {
    $adbOutput = & $adbPath devices 2>&1
    if ($LASTEXITCODE -eq 0) {
        $authorizedDevices = @($adbOutput | Where-Object { $_ -match '^\S+\s+device$' })
    }
}
Add-Result $results 'Android' 'Authorized device' ($authorizedDevices.Count -gt 0) $(if ($authorizedDevices.Count -gt 0) { "$($authorizedDevices.Count) authorized device(s)" } else { 'Connect, unlock and accept the USB debugging RSA prompt' })
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
