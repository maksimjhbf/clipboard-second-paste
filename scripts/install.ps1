param(
    [ValidateSet('en', 'ru', 'english', 'russian')]
    [string] $Lang = '',
    [string] $SourceRoot = ''
)

$ErrorActionPreference = 'Stop'

if (-not $SourceRoot) {
    $candidate = Split-Path -Parent $PSScriptRoot
    if (Test-Path -LiteralPath (Join-Path $candidate 'src\clipdeck-ui.ps1')) {
        $SourceRoot = $candidate
    } else {
        $SourceRoot = $PSScriptRoot
    }
}

$appName = 'ClipDeck'
$appDir = Join-Path $env:APPDATA $appName
$srcDir = Join-Path $SourceRoot 'src'
$assetsDir = Join-Path $SourceRoot 'assets'
$helper = Join-Path $srcDir 'clipboard-second-paste.ps1'
$watchdog = Join-Path $srcDir 'clipboard-hotkeys-watchdog.ps1'
$ui = Join-Path $srcDir 'clipdeck-ui.ps1'
$icon = Join-Path $assetsDir 'ClipDeck.ico'
$installedHelper = Join-Path $appDir 'clipboard-second-paste.ps1'
$installedWatchdog = Join-Path $appDir 'clipboard-hotkeys-watchdog.ps1'
$installedUi = Join-Path $appDir 'clipdeck-ui.ps1'
$installedIcon = Join-Path $appDir 'ClipDeck.ico'
$settingsPath = Join-Path $appDir 'clipdeck-settings.json'
$dittoPath = 'C:\Program Files\Ditto\Ditto.exe'
$taskName = 'ClipDeck Watchdog'

if (-not (Test-Path -LiteralPath $helper) -or -not (Test-Path -LiteralPath $watchdog) -or -not (Test-Path -LiteralPath $ui)) {
    throw 'Installer files are incomplete.'
}

Write-Host 'Installing ClipDeck 2.0...'

if (-not (Test-Path -LiteralPath $dittoPath)) {
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw 'Ditto is required, and winget was not found. Install Ditto manually, then rerun this installer.'
    }

    Write-Host 'Installing Ditto with winget...'
    winget install --id Ditto.Ditto -e --accept-package-agreements --accept-source-agreements
}

New-Item -ItemType Directory -Force -Path $appDir | Out-Null
Copy-Item -LiteralPath $helper -Destination $installedHelper -Force
Copy-Item -LiteralPath $watchdog -Destination $installedWatchdog -Force
Copy-Item -LiteralPath $ui -Destination $installedUi -Force
if (Test-Path -LiteralPath $icon) {
    Copy-Item -LiteralPath $icon -Destination $installedIcon -Force
}

if (-not (Test-Path -LiteralPath $settingsPath)) {
    @{
        idleShutdownEnabled = $false
        idleShutdownHours = 2
        screenshotSaveEnabled = $false
        pasteCurrentHotkey = 'Ctrl+1'
        pasteSecondHotkey = 'Ctrl+2'
        pasteThirdHotkey = 'Ctrl+3'
    } |
        ConvertTo-Json -Depth 3 |
        Set-Content -LiteralPath $settingsPath -Encoding UTF8
}

New-Item -Path 'HKCU:\Software\Ditto' -Force | Out-Null
Set-ItemProperty -Path 'HKCU:\Software\Ditto' -Name 'Position1' -Type DWord -Value 0
Set-ItemProperty -Path 'HKCU:\Software\Ditto' -Name 'Position2' -Type DWord -Value 1917
Set-ItemProperty -Path 'HKCU:\Software\Ditto' -Name 'Position3' -Type DWord -Value 1918
Set-ItemProperty -Path 'HKCU:\Software\Ditto' -Name 'SendPasteOnFirstTenHotKeys' -Type DWord -Value 0
Set-ItemProperty -Path 'HKCU:\Software\Ditto' -Name 'MoveClipsOnGlobal10' -Type DWord -Value 0
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'Ditto' -Type String -Value $dittoPath

$watchdogCmd = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $installedWatchdog + '"'
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'ClipDeckWatchdog' -Type String -Value $watchdogCmd

# Remove the old v1 autostart entry if the user previously installed Clipboard Second Paste.
Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'ClipboardSecondPaste' -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName 'Clipboard Second Paste' -Confirm:$false -ErrorAction SilentlyContinue

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $installedWatchdog + '"')
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$trigger.Delay = 'PT15S'
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

$shell = New-Object -ComObject WScript.Shell
$desktopShortcut = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'ClipDeck.lnk'))
$desktopShortcut.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$desktopShortcut.Arguments = '-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $installedUi + '"'
$desktopShortcut.WorkingDirectory = $appDir
if (Test-Path -LiteralPath $installedIcon) {
    $desktopShortcut.IconLocation = $installedIcon
}
$desktopShortcut.Save()

$programsDir = Join-Path ([Environment]::GetFolderPath('Programs')) 'ClipDeck'
New-Item -ItemType Directory -Force -Path $programsDir | Out-Null
$menuShortcut = $shell.CreateShortcut((Join-Path $programsDir 'ClipDeck.lnk'))
$menuShortcut.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$menuShortcut.Arguments = '-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $installedUi + '"'
$menuShortcut.WorkingDirectory = $appDir
if (Test-Path -LiteralPath $installedIcon) {
    $menuShortcut.IconLocation = $installedIcon
}
$menuShortcut.Save()

Get-CimInstance Win32_Process |
    Where-Object {
        $_.CommandLine -and (
            $_.CommandLine -like '*clipboard-hotkeys-watchdog.ps1*' -or
            $_.CommandLine -like '*clipboard-second-paste.ps1*'
        )
    } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

Start-Process -FilePath 'powershell.exe' -ArgumentList @(
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-WindowStyle',
    'Hidden',
    '-File',
    $installedWatchdog
) -WindowStyle Hidden

Write-Host 'Installed. Hotkeys: Ctrl+1 = current clipboard, Ctrl+2 = second saved clip, Ctrl+3 = third saved clip, Ctrl+B = second saved clip.'
