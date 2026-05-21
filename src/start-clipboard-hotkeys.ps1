$ErrorActionPreference = 'SilentlyContinue'

$dittoPath = 'C:\Program Files\Ditto\Ditto.exe'
$appDir = Join-Path $env:APPDATA 'ClipboardSecondPaste'
$helperPath = Join-Path $appDir 'clipboard-second-paste.ps1'

New-Item -Path 'HKCU:\Software\Ditto' -Force | Out-Null

# Ditto owns the clipboard history. This app owns the visible hotkeys and uses
# a hidden Ditto hotkey to load clipboard-history position 2.
Set-ItemProperty -Path 'HKCU:\Software\Ditto' -Name 'Position1' -Type DWord -Value 0
Set-ItemProperty -Path 'HKCU:\Software\Ditto' -Name 'Position2' -Type DWord -Value 1917
Set-ItemProperty -Path 'HKCU:\Software\Ditto' -Name 'SendPasteOnFirstTenHotKeys' -Type DWord -Value 0
Set-ItemProperty -Path 'HKCU:\Software\Ditto' -Name 'MoveClipsOnGlobal10' -Type DWord -Value 0
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'Ditto' -Type String -Value $dittoPath

if ((Test-Path -LiteralPath $dittoPath) -and -not (Get-Process -Name Ditto -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $dittoPath
    Start-Sleep -Seconds 2
}

$currentPid = $PID
Get-CimInstance Win32_Process |
    Where-Object {
        $_.ProcessId -ne $currentPid -and
        $_.CommandLine -like '*powershell.exe*' -and
        $_.CommandLine -notlike '* -Command *' -and
        $_.CommandLine -like '*-File*clipboard-second-paste.ps1*'
    } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

if (Test-Path -LiteralPath $helperPath) {
    Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoProfile',
        '-STA',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        $helperPath
    ) -WindowStyle Hidden
}
