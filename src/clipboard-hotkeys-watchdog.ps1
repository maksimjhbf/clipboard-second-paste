$ErrorActionPreference = 'SilentlyContinue'

$root = Join-Path $env:APPDATA 'ClipDeck'
$helperPath = Join-Path $root 'clipboard-second-paste.ps1'
$logPath = Join-Path $root 'clipboard-hotkeys-watchdog.log'
$settingsPath = Join-Path $root 'clipdeck-settings.json'
$dittoPath = 'C:\Program Files\Ditto\Ditto.exe'
$idleShutdownAfterSeconds = 10 * 60

New-Item -ItemType Directory -Force -Path $root | Out-Null

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class ClipDeckCursorNative {
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT {
        public int X;
        public int Y;
    }

    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out POINT lpPoint);
}
'@

function Write-WatchdogLog {
    param([string]$Message)
    Add-Content -LiteralPath $logPath -Value ('{0} {1}' -f (Get-Date -Format o), $Message)
}

function Initialize-ClipDeckSettings {
    if (-not (Test-Path -LiteralPath $settingsPath)) {
        @{
            idleShutdownEnabled = $false
            idleShutdownHours = 2
        } |
            ConvertTo-Json -Depth 3 |
            Set-Content -LiteralPath $settingsPath -Encoding UTF8
        return
    }

    try {
        $settings = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json
        $changed = $false
        if ($null -eq $settings.PSObject.Properties['idleShutdownEnabled']) {
            $settings | Add-Member -NotePropertyName idleShutdownEnabled -NotePropertyValue $false
            $changed = $true
        }
        if ($null -eq $settings.PSObject.Properties['idleShutdownHours']) {
            $settings | Add-Member -NotePropertyName idleShutdownHours -NotePropertyValue 2
            $changed = $true
        }
        if ($changed) {
            $settings |
                ConvertTo-Json -Depth 3 |
                Set-Content -LiteralPath $settingsPath -Encoding UTF8
        }
    } catch {
        @{
            idleShutdownEnabled = $false
            idleShutdownHours = 2
        } |
            ConvertTo-Json -Depth 3 |
            Set-Content -LiteralPath $settingsPath -Encoding UTF8
    }
}

function Get-IdleShutdownEnabled {
    Initialize-ClipDeckSettings
    try {
        $settings = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json
        return [bool]$settings.idleShutdownEnabled
    } catch {
        return $false
    }
}

function Get-IdleShutdownHours {
    Initialize-ClipDeckSettings
    try {
        $settings = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json
        $hours = [int]$settings.idleShutdownHours
        if ($hours -lt 1) { return 1 }
        if ($hours -gt 5) { return 5 }
        return $hours
    } catch {
        return 2
    }
}

$createdNew = $false
$watchdogMutex = New-Object System.Threading.Mutex($true, 'Global\ClipDeckClipboardHotkeysWatchdog', [ref]$createdNew)
if (-not $createdNew) {
    Write-WatchdogLog "watchdog already running, exiting pid=$PID"
    return
}

function Set-DittoDefaults {
    New-Item -Path 'HKCU:\Software\Ditto' -Force | Out-Null
    Set-ItemProperty -Path 'HKCU:\Software\Ditto' -Name 'Position1' -Type DWord -Value 0
    Set-ItemProperty -Path 'HKCU:\Software\Ditto' -Name 'Position2' -Type DWord -Value 1917
    Set-ItemProperty -Path 'HKCU:\Software\Ditto' -Name 'Position3' -Type DWord -Value 1918
    Set-ItemProperty -Path 'HKCU:\Software\Ditto' -Name 'SendPasteOnFirstTenHotKeys' -Type DWord -Value 0
    Set-ItemProperty -Path 'HKCU:\Software\Ditto' -Name 'MoveClipsOnGlobal10' -Type DWord -Value 0
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'Ditto' -Type String -Value $dittoPath
}

function Get-ClipboardHelperProcess {
    $currentPid = $PID
    Get-CimInstance Win32_Process |
        Where-Object {
            $_.ProcessId -ne $currentPid -and
            $_.CommandLine -like '*clipboard-second-paste.ps1*'
        }
}

function Start-DittoIfNeeded {
    if ((Test-Path -LiteralPath $dittoPath) -and -not (Get-Process -Name Ditto -ErrorAction SilentlyContinue)) {
        Start-Process -FilePath $dittoPath
        Write-WatchdogLog 'started Ditto'
        Start-Sleep -Seconds 2
    }
}

function Start-ClipboardHelperIfNeeded {
    if (-not (Test-Path -LiteralPath $helperPath)) {
        Write-WatchdogLog "helper missing: $helperPath"
        return
    }

    $running = @(Get-ClipboardHelperProcess)
    if ($running.Count -gt 0) {
        return
    }

    Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList @(
        '-NoProfile',
        '-STA',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        $helperPath
    ) -WindowStyle Hidden
    Write-WatchdogLog 'started clipboard helper'
}

function Get-CursorPositionKey {
    $point = New-Object 'ClipDeckCursorNative+POINT'
    [ClipDeckCursorNative]::GetCursorPos([ref]$point) | Out-Null
    return ('{0},{1}' -f $point.X, $point.Y)
}

function Start-IdleShutdownCountdown {
    $shutdownHours = Get-IdleShutdownHours
    $shutdownDelaySeconds = $shutdownHours * 60 * 60
    shutdown.exe /s /t $shutdownDelaySeconds /c "ClipDeck: cursor idle for 10 minutes. Auto shutdown in $shutdownHours hour(s)." | Out-Null
    Write-WatchdogLog "scheduled shutdown after cursor idle: delaySeconds=$shutdownDelaySeconds hours=$shutdownHours"
}

function Stop-IdleShutdownCountdown {
    shutdown.exe /a | Out-Null
    Write-WatchdogLog 'cancelled scheduled shutdown because cursor moved'
}

Write-WatchdogLog "watchdog started pid=$PID"
Initialize-ClipDeckSettings
$lastCursorPosition = Get-CursorPositionKey
$lastCursorMoveUtc = [DateTime]::UtcNow
$idleShutdownScheduled = $false
$lastIdleShutdownHours = Get-IdleShutdownHours

while ($true) {
    Set-DittoDefaults
    Start-DittoIfNeeded
    Start-ClipboardHelperIfNeeded

    $idleShutdownEnabled = Get-IdleShutdownEnabled
    $currentIdleShutdownHours = Get-IdleShutdownHours
    if (-not $idleShutdownEnabled) {
        if ($idleShutdownScheduled) {
            Stop-IdleShutdownCountdown
            $idleShutdownScheduled = $false
        }
        $lastIdleShutdownHours = $currentIdleShutdownHours
        $lastCursorPosition = Get-CursorPositionKey
        $lastCursorMoveUtc = [DateTime]::UtcNow
        Start-Sleep -Seconds 5
        continue
    }

    if ($idleShutdownScheduled -and $currentIdleShutdownHours -ne $lastIdleShutdownHours) {
        Stop-IdleShutdownCountdown
        Start-IdleShutdownCountdown
        $lastIdleShutdownHours = $currentIdleShutdownHours
    }

    $cursorPosition = Get-CursorPositionKey
    if ($cursorPosition -ne $lastCursorPosition) {
        $lastCursorPosition = $cursorPosition
        $lastCursorMoveUtc = [DateTime]::UtcNow
        $lastIdleShutdownHours = $currentIdleShutdownHours
        if ($idleShutdownScheduled) {
            Stop-IdleShutdownCountdown
            $idleShutdownScheduled = $false
        }
    } elseif (-not $idleShutdownScheduled) {
        $idleSeconds = ([DateTime]::UtcNow - $lastCursorMoveUtc).TotalSeconds
        if ($idleSeconds -ge $idleShutdownAfterSeconds) {
            Start-IdleShutdownCountdown
            $lastIdleShutdownHours = $currentIdleShutdownHours
            $idleShutdownScheduled = $true
        }
    }

    Start-Sleep -Seconds 5
}
