param(
    [ValidateSet('en', 'ru', 'english', 'russian')]
    [string] $Lang = ''
)

$ErrorActionPreference = 'SilentlyContinue'

$appDir = Join-Path $env:APPDATA 'ClipboardSecondPaste'
$taskName = 'Clipboard Second Paste'

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'ClipboardSecondPaste'

Get-CimInstance Win32_Process |
    Where-Object {
        $_.Name -eq 'powershell.exe' -and
        $_.CommandLine -like '*-File*clipboard-second-paste.ps1*'
    } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

Remove-Item -LiteralPath $appDir -Recurse -Force

Write-Host 'Clipboard Second Paste has been removed. Ditto was left installed.'
