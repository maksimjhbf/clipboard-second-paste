param(
    [ValidateSet('en', 'ru', 'english', 'russian')]
    [string] $Lang = '',
    [string] $SourceRoot = ''
)

$ErrorActionPreference = 'Stop'

if (-not $SourceRoot) {
    $candidate = Split-Path -Parent $PSScriptRoot
    if (Test-Path -LiteralPath (Join-Path $candidate 'src\clipboard-second-paste.ps1')) {
        $SourceRoot = $candidate
    } else {
        $SourceRoot = $PSScriptRoot
    }
}

$appDir = Join-Path $env:APPDATA 'ClipboardSecondPaste'
$srcDir = Join-Path $SourceRoot 'src'
$helper = Join-Path $srcDir 'clipboard-second-paste.ps1'
$starter = Join-Path $srcDir 'start-clipboard-hotkeys.ps1'
$installedHelper = Join-Path $appDir 'clipboard-second-paste.ps1'
$installedStarter = Join-Path $appDir 'start-clipboard-hotkeys.ps1'
$dittoPath = 'C:\Program Files\Ditto\Ditto.exe'
$taskName = 'Clipboard Second Paste'

if (-not (Test-Path -LiteralPath $helper) -or -not (Test-Path -LiteralPath $starter)) {
    throw 'Installer files are incomplete.'
}

Write-Host 'Installing Clipboard Second Paste...'

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
Copy-Item -LiteralPath $starter -Destination $installedStarter -Force

New-Item -Path 'HKCU:\Software\Ditto' -Force | Out-Null
Set-ItemProperty -Path 'HKCU:\Software\Ditto' -Name 'Position1' -Type DWord -Value 0
Set-ItemProperty -Path 'HKCU:\Software\Ditto' -Name 'Position2' -Type DWord -Value 1917
Set-ItemProperty -Path 'HKCU:\Software\Ditto' -Name 'SendPasteOnFirstTenHotKeys' -Type DWord -Value 0
Set-ItemProperty -Path 'HKCU:\Software\Ditto' -Name 'MoveClipsOnGlobal10' -Type DWord -Value 0
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'Ditto' -Type String -Value $dittoPath

$runCmd = 'powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $installedStarter + '"'
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'ClipboardSecondPaste' -Type String -Value $runCmd

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $installedStarter + '"')
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$trigger.Delay = 'PT15S'
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

& $installedStarter

Write-Host 'Installed. Hotkeys: Ctrl+1 = paste current clipboard, Ctrl+2/Ctrl+B = paste second clipboard-history item.'
