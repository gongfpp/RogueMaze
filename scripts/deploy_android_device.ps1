param(
    [string]$ApkPath = 'builds\android\RogueMaze-debug.apk',
    [string]$Serial = '',
    [switch]$SkipInstall,
    [switch]$CaptureScreenshot
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$packageName = 'com.gongfpp.roguemaze'

function Resolve-AdbPath() {
    $command = Get-Command adb -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $candidates = @(
        $(if ($env:ANDROID_HOME) { Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe' }),
        $(if ($env:ANDROID_SDK_ROOT) { Join-Path $env:ANDROID_SDK_ROOT 'platform-tools\adb.exe' }),
        (Join-Path $projectRoot '.tools\android-sdk\platform-tools\adb.exe'),
        (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe')
    ) | Where-Object { $_ }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    throw @'
ADB was not found on PATH or in the supported SDK locations.
Run scripts/setup_android_sdk.ps1 after reviewing and accepting the Android SDK license,
or set ANDROID_HOME/ANDROID_SDK_ROOT to an existing SDK.
'@
}

function Invoke-Adb([string[]]$Arguments) {
    $prefix = @()
    if ($script:deviceSerial) { $prefix = @('-s', $script:deviceSerial) }
    $output = & $script:adbPath @prefix @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    if ($exitCode -ne 0) {
        throw "ADB command failed: adb $($Arguments -join ' ')"
    }
    return @($output)
}

Push-Location $projectRoot
try {
    $script:adbPath = Resolve-AdbPath
    Write-Host "ADB: $script:adbPath"
    $deviceOutput = & $script:adbPath devices -l 2>&1
    if ($LASTEXITCODE -ne 0) { throw "adb devices failed." }
    $deviceOutput | ForEach-Object { Write-Host $_ }
    $devices = @()
    foreach ($line in $deviceOutput) {
        if ($line -match '^(\S+)\s+(device|unauthorized|offline)\b(.*)$') {
            $devices += [PSCustomObject]@{ Serial = $Matches[1]; State = $Matches[2]; Detail = $Matches[3].Trim() }
        }
    }
    if ($Serial) {
        $selected = $devices | Where-Object { $_.Serial -eq $Serial } | Select-Object -First 1
        if (-not $selected) { throw "Requested Android device '$Serial' was not found." }
        if ($selected.State -ne 'device') { throw "Android device '$Serial' is $($selected.State). Unlock it and accept the USB debugging RSA prompt." }
    }
    else {
        $authorized = @($devices | Where-Object { $_.State -eq 'device' })
        if ($authorized.Count -eq 0) {
            $unauthorized = @($devices | Where-Object { $_.State -eq 'unauthorized' })
            if ($unauthorized.Count -gt 0) {
                throw "Android device is unauthorized. Unlock it and accept the USB debugging RSA prompt."
            }
            throw "No authorized Android device is visible to ADB. Check the USB cable, USB mode and Windows driver."
        }
        if ($authorized.Count -gt 1) { throw "Multiple Android devices are connected. Pass -Serial <id>." }
        $selected = $authorized[0]
    }
    $script:deviceSerial = $selected.Serial

    $abi = ((Invoke-Adb @('shell', 'getprop', 'ro.product.cpu.abi')) -join '').Trim()
    $manufacturer = ((Invoke-Adb @('shell', 'getprop', 'ro.product.manufacturer')) -join '').Trim()
    $model = ((Invoke-Adb @('shell', 'getprop', 'ro.product.model')) -join '').Trim()
    $sdk = ((Invoke-Adb @('shell', 'getprop', 'ro.build.version.sdk')) -join '').Trim()
    if ($abi -notmatch '^arm64') {
        throw "Connected device ABI is '$abi'; the current APK preset contains arm64-v8a only."
    }
    Write-Host "Device: $manufacturer $model | Android API $sdk | $abi | $script:deviceSerial"

    $resolvedApk = if ([System.IO.Path]::IsPathRooted($ApkPath)) {
        [System.IO.Path]::GetFullPath($ApkPath)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $projectRoot $ApkPath))
    }
    if (-not $SkipInstall) {
        if (-not (Test-Path -LiteralPath $resolvedApk)) { throw "APK not found: $resolvedApk" }
        if ((Get-Item -LiteralPath $resolvedApk).Length -le 0) { throw "APK is empty: $resolvedApk" }
        $null = Invoke-Adb @('install', '-r', $resolvedApk)
    }

    $null = Invoke-Adb @('shell', 'monkey', '-p', $packageName, '-c', 'android.intent.category.LAUNCHER', '1')
    Start-Sleep -Seconds 3
    $appPid = ((Invoke-Adb @('shell', 'pidof', $packageName)) -join '').Trim().Split(' ')[0]
    if ($appPid -notmatch '^\d+$') { throw "RogueMaze did not remain running after launch." }
    $logs = Invoke-Adb @('logcat', "--pid=$appPid", '-d', '-v', 'threadtime')
    $logText = $logs -join "`n"

    New-Item -ItemType Directory -Force builds\android | Out-Null
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
    $reportPath = Join-Path $projectRoot "builds\android\device-report-$stamp.txt"
    @(
        "RogueMaze Android device smoke"
        "Serial: $script:deviceSerial"
        "Device: $manufacturer $model"
        "API: $sdk"
        "ABI: $abi"
        "Package: $packageName"
        "PID: $appPid"
        "APK: $resolvedApk"
        "Checked at UTC: $((Get-Date).ToUniversalTime().ToString('o'))"
        ""
        "--- Process log ---"
    ) + @($logs | Select-Object -Last 500) | Set-Content -LiteralPath $reportPath -Encoding UTF8

    if ($logText -match 'FATAL EXCEPTION|AndroidRuntime.*FATAL|SCRIPT ERROR|Parse Error|Failed to load script') {
        throw "Fatal Android/Godot error found after launch. Inspect $reportPath."
    }

    if ($CaptureScreenshot) {
        $remoteScreenshot = '/sdcard/Download/RogueMaze-smoke.png'
        $localScreenshot = Join-Path $projectRoot "builds\android\device-$stamp.png"
        $null = Invoke-Adb @('shell', 'screencap', '-p', $remoteScreenshot)
        $null = Invoke-Adb @('pull', $remoteScreenshot, $localScreenshot)
        $null = Invoke-Adb @('shell', 'rm', '-f', $remoteScreenshot)
        Write-Host "Screenshot: $localScreenshot"
    }
    Write-Host "Android smoke passed; app left running for manual play."
    Write-Host "Device report: $reportPath"
}
finally {
    Pop-Location
}
