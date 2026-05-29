$ErrorActionPreference = 'SilentlyContinue'

$appDir = Join-Path $env:APPDATA 'ClipDeck'
$watchdogPath = Join-Path $appDir 'clipboard-hotkeys-watchdog.ps1'

if (Test-Path -LiteralPath $watchdogPath) {
    Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        $watchdogPath
    ) -WindowStyle Hidden
}
