param(
    [switch]$AcceptAndroidSdkLicense
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolsRoot = Join-Path $projectRoot '.tools'
$sdkRoot = Join-Path $toolsRoot 'android-sdk'
$downloadPath = Join-Path $toolsRoot 'downloads\commandlinetools-win-14742923_latest.zip'
$downloadUrl = 'https://dl.google.com/android/repository/commandlinetools-win-14742923_latest.zip'
$expectedSha1 = '16b3f45ddb3d85ea6bbe6a1c0b47146daf0db450'

if (-not $AcceptAndroidSdkLicense) {
    Write-Error @'
Android SDK installation requires accepting Google's Android SDK License Agreement.
Review it at https://developer.android.com/studio and, if you have authority to accept it,
run: .\scripts\setup_android_sdk.ps1 -AcceptAndroidSdkLicense
'@
    exit 2
}

New-Item -ItemType Directory -Force (Split-Path $downloadPath), $sdkRoot | Out-Null
if (-not (Test-Path -LiteralPath $downloadPath)) {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath
}
$actualSha1 = (Get-FileHash -LiteralPath $downloadPath -Algorithm SHA1).Hash.ToLowerInvariant()
if ($actualSha1 -ne $expectedSha1) {
    throw "Android command-line tools checksum mismatch: $actualSha1"
}

$latestRoot = Join-Path $sdkRoot 'cmdline-tools\latest'
if (-not (Test-Path -LiteralPath (Join-Path $latestRoot 'bin\sdkmanager.bat'))) {
    $extractRoot = Join-Path $toolsRoot 'android-commandline-extract'
    $resolvedExtract = [System.IO.Path]::GetFullPath($extractRoot)
    $resolvedProject = [System.IO.Path]::GetFullPath($projectRoot)
    if (-not $resolvedExtract.StartsWith($resolvedProject, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to replace a temporary directory outside the project: $resolvedExtract"
    }
    if (Test-Path -LiteralPath $extractRoot) {
        Remove-Item -LiteralPath $extractRoot -Recurse -Force
    }
    Expand-Archive -LiteralPath $downloadPath -DestinationPath $extractRoot
    New-Item -ItemType Directory -Force (Split-Path $latestRoot) | Out-Null
    Move-Item -LiteralPath (Join-Path $extractRoot 'cmdline-tools') -Destination $latestRoot
    Remove-Item -LiteralPath $extractRoot -Recurse -Force
}

$sdkManager = Join-Path $latestRoot 'bin\sdkmanager.bat'
$env:ANDROID_HOME = $sdkRoot
$env:ANDROID_SDK_ROOT = $sdkRoot
1..20 | ForEach-Object { 'y' } | & $sdkManager --sdk_root=$sdkRoot --licenses
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $sdkManager --sdk_root=$sdkRoot 'platform-tools' 'build-tools;35.0.1' 'platforms;android-35' 'cmdline-tools;latest' 'cmake;3.10.2.4988404' 'ndk;28.1.13356709'
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$javaCommand = Get-Command java -ErrorAction Stop
$javaRoot = Split-Path (Split-Path $javaCommand.Source -Parent) -Parent
$editorSettings = Join-Path $toolsRoot 'godot\editor_data\editor_settings-4.7.tres'
if (Test-Path -LiteralPath $editorSettings) {
    $settings = Get-Content -LiteralPath $editorSettings -Raw
    $escapedSdk = $sdkRoot.Replace('\', '\\')
    $escapedJava = $javaRoot.Replace('\', '\\')
    $settings = [regex]::Replace($settings, 'export/android/android_sdk_path = ".*"', "export/android/android_sdk_path = `"$escapedSdk`"")
    $settings = [regex]::Replace($settings, 'export/android/java_sdk_path = ".*"', "export/android/java_sdk_path = `"$escapedJava`"")
    [System.IO.File]::WriteAllText($editorSettings, $settings, [System.Text.UTF8Encoding]::new($false))
}

& "$PSScriptRoot\check_platforms.ps1"
