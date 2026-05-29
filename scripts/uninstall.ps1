param(
    [ValidateSet('en', 'ru', 'english', 'russian')]
    [string] $Lang = ''
)

$ErrorActionPreference = 'SilentlyContinue'

$appDir = Join-Path $env:APPDATA 'ClipDeck'
$taskName = 'ClipDeck Watchdog'
$programsDir = Join-Path ([Environment]::GetFolderPath('Programs')) 'ClipDeck'
$desktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'ClipDeck.lnk'

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'ClipDeckWatchdog'

Get-CimInstance Win32_Process |
    Where-Object {
        $_.Name -eq 'powershell.exe' -and
        $_.CommandLine -and (
            $_.CommandLine -like '*clipdeck-ui.ps1*' -or
            $_.CommandLine -like '*clipboard-hotkeys-watchdog.ps1*' -or
            $_.CommandLine -like '*clipboard-second-paste.ps1*'
        )
    } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

Remove-Item -LiteralPath $desktopShortcut -Force
Remove-Item -LiteralPath $programsDir -Recurse -Force
Remove-Item -LiteralPath $appDir -Recurse -Force

Write-Host 'ClipDeck has been removed. Ditto was left installed because it may contain clipboard history.'
