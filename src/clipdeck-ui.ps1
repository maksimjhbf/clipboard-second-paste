Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'SilentlyContinue'

$watchdogPath = Join-Path $PSScriptRoot 'clipboard-hotkeys-watchdog.ps1'
$root = Join-Path $env:APPDATA 'ClipDeck'
$watchdogLog = Join-Path $root 'clipboard-hotkeys-watchdog.log'
$helperLog = Join-Path $root 'clipboard-hotkeys.log'
$settingsPath = Join-Path $root 'clipdeck-settings.json'
$iconPath = Join-Path $root 'ClipDeck.ico'

function Initialize-ClipDeckSettings {
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    $defaultStorageRoot = Join-Path ([Environment]::GetFolderPath('Desktop')) 'ClipDeck'
    if (-not (Test-Path -LiteralPath $settingsPath)) {
        @{
            idleShutdownEnabled = $false
            idleShutdownHours = 2
            screenshotSaveEnabled = $false
            pasteCurrentHotkey = 'Ctrl+1'
            pasteSecondHotkey = 'Ctrl+2'
            pasteThirdHotkey = 'Ctrl+3'
            storageRoot = $defaultStorageRoot
            retentionDays = 7
            lastCleanupUtc = ''
            screenshotHotkey = 'Win+Shift+D'
            ocrHotkey = 'Win+Shift+Z'
            recordHotkey = 'Win+Shift+R'
            rulerHotkey = 'Alt+Shift+W'
            recordingFormat = 'MP4'
            recordingFps = 24
            recordingCaptureCursor = $true
            androidMirrorEnabled = $false
            androidMirrorRoot = ''
        } |
            ConvertTo-Json -Depth 5 |
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
        if ($null -eq $settings.PSObject.Properties['screenshotSaveEnabled']) {
            $settings | Add-Member -NotePropertyName screenshotSaveEnabled -NotePropertyValue $false
            $changed = $true
        }
        if ($null -eq $settings.PSObject.Properties['pasteCurrentHotkey']) {
            $settings | Add-Member -NotePropertyName pasteCurrentHotkey -NotePropertyValue 'Ctrl+1'
            $changed = $true
        }
        if ($null -eq $settings.PSObject.Properties['pasteSecondHotkey']) {
            $settings | Add-Member -NotePropertyName pasteSecondHotkey -NotePropertyValue 'Ctrl+2'
            $changed = $true
        }
        if ($null -eq $settings.PSObject.Properties['pasteThirdHotkey']) {
            $settings | Add-Member -NotePropertyName pasteThirdHotkey -NotePropertyValue 'Ctrl+3'
            $changed = $true
        }
        $defaults = @{
            storageRoot = $defaultStorageRoot
            retentionDays = 7
            lastCleanupUtc = ''
            screenshotHotkey = 'Win+Shift+D'
            ocrHotkey = 'Win+Shift+Z'
            recordHotkey = 'Win+Shift+R'
            rulerHotkey = 'Alt+Shift+W'
            recordingFormat = 'MP4'
            recordingFps = 24
            recordingCaptureCursor = $true
            androidMirrorEnabled = $false
            androidMirrorRoot = ''
        }
        foreach ($name in $defaults.Keys) {
            if ($null -eq $settings.PSObject.Properties[$name]) {
                $settings | Add-Member -NotePropertyName $name -NotePropertyValue $defaults[$name]
                $changed = $true
            }
        }
        if ($changed) {
            $settings |
                ConvertTo-Json -Depth 5 |
                Set-Content -LiteralPath $settingsPath -Encoding UTF8
        }
    } catch {
        @{
            idleShutdownEnabled = $false
            idleShutdownHours = 2
            screenshotSaveEnabled = $false
            pasteCurrentHotkey = 'Ctrl+1'
            pasteSecondHotkey = 'Ctrl+2'
            pasteThirdHotkey = 'Ctrl+3'
            storageRoot = $defaultStorageRoot
            retentionDays = 7
            lastCleanupUtc = ''
            screenshotHotkey = 'Win+Shift+D'
            ocrHotkey = 'Win+Shift+Z'
            recordHotkey = 'Win+Shift+R'
            rulerHotkey = 'Alt+Shift+W'
            recordingFormat = 'MP4'
            recordingFps = 24
            recordingCaptureCursor = $true
            androidMirrorEnabled = $false
            androidMirrorRoot = ''
        } |
            ConvertTo-Json -Depth 5 |
            Set-Content -LiteralPath $settingsPath -Encoding UTF8
    }
}

function Get-ClipDeckSettings {
    Initialize-ClipDeckSettings
    try {
        return (Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json)
    } catch {
        return [pscustomobject]@{
            idleShutdownEnabled = $false
            idleShutdownHours = 2
            screenshotSaveEnabled = $false
            pasteCurrentHotkey = 'Ctrl+1'
            pasteSecondHotkey = 'Ctrl+2'
            pasteThirdHotkey = 'Ctrl+3'
            storageRoot = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'ClipDeck')
            retentionDays = 7
            lastCleanupUtc = ''
            screenshotHotkey = 'Win+Shift+D'
            ocrHotkey = 'Win+Shift+Z'
            recordHotkey = 'Win+Shift+R'
            rulerHotkey = 'Alt+Shift+W'
            recordingFormat = 'MP4'
            recordingFps = 24
            recordingCaptureCursor = $true
            androidMirrorEnabled = $false
            androidMirrorRoot = ''
        }
    }
}

function Save-ClipDeckSettings {
    param(
        [bool]$IdleShutdownEnabled,
        [int]$IdleShutdownHours,
        [bool]$ScreenshotSaveEnabled,
        [string]$PasteCurrentHotkey = (Get-PasteCurrentHotkey),
        [string]$PasteSecondHotkey = (Get-PasteSecondHotkey),
        [string]$PasteThirdHotkey = (Get-PasteThirdHotkey),
        [string]$StorageRoot = (Get-StorageRoot),
        [int]$RetentionDays = (Get-RetentionDays),
        [string]$LastCleanupUtc = (Get-LastCleanupUtc),
        [string]$ScreenshotHotkey = (Get-ScreenshotHotkey),
        [string]$OcrHotkey = (Get-OcrHotkey),
        [string]$RecordHotkey = (Get-RecordHotkey),
        [string]$RulerHotkey = (Get-RulerHotkey),
        [string]$RecordingFormat = (Get-RecordingFormat),
        [int]$RecordingFps = (Get-RecordingFps),
        [bool]$RecordingCaptureCursor = (Get-RecordingCaptureCursor),
        [bool]$AndroidMirrorEnabled = (Get-AndroidMirrorEnabled),
        [string]$AndroidMirrorRoot = (Get-AndroidMirrorRoot)
    )
    if ($IdleShutdownHours -lt 1) { $IdleShutdownHours = 1 }
    if ($IdleShutdownHours -gt 5) { $IdleShutdownHours = 5 }
    if ($RetentionDays -lt 1) { $RetentionDays = 1 }
    if ($RetentionDays -gt 365) { $RetentionDays = 365 }
    if ($RecordingFps -notin @(24, 30, 60)) { $RecordingFps = 24 }
    if ($RecordingFormat -notin @('MP4', 'GIF')) { $RecordingFormat = 'MP4' }
    @{
        idleShutdownEnabled = $IdleShutdownEnabled
        idleShutdownHours = $IdleShutdownHours
        screenshotSaveEnabled = $ScreenshotSaveEnabled
        pasteCurrentHotkey = $PasteCurrentHotkey
        pasteSecondHotkey = $PasteSecondHotkey
        pasteThirdHotkey = $PasteThirdHotkey
        storageRoot = $StorageRoot
        retentionDays = $RetentionDays
        lastCleanupUtc = $LastCleanupUtc
        screenshotHotkey = $ScreenshotHotkey
        ocrHotkey = $OcrHotkey
        recordHotkey = $RecordHotkey
        rulerHotkey = $RulerHotkey
        recordingFormat = $RecordingFormat
        recordingFps = $RecordingFps
        recordingCaptureCursor = $RecordingCaptureCursor
        androidMirrorEnabled = $AndroidMirrorEnabled
        androidMirrorRoot = $AndroidMirrorRoot
    } |
        ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath $settingsPath -Encoding UTF8
}

function Get-IdleShutdownEnabled {
    $settings = Get-ClipDeckSettings
    return [bool]$settings.idleShutdownEnabled
}

function Get-IdleShutdownHours {
    $settings = Get-ClipDeckSettings
    $hours = [int]$settings.idleShutdownHours
    if ($hours -lt 1) { return 1 }
    if ($hours -gt 5) { return 5 }
    return $hours
}

function Set-IdleShutdownEnabled {
    param([bool]$Enabled)
    Save-ClipDeckSettings -IdleShutdownEnabled $Enabled -IdleShutdownHours (Get-IdleShutdownHours) -ScreenshotSaveEnabled (Get-ScreenshotSaveEnabled)

    if (-not $Enabled) {
        shutdown.exe /a | Out-Null
    }
}

function Set-IdleShutdownHours {
    param([int]$Hours)
    Save-ClipDeckSettings -IdleShutdownEnabled (Get-IdleShutdownEnabled) -IdleShutdownHours $Hours -ScreenshotSaveEnabled (Get-ScreenshotSaveEnabled)
}

function Get-ScreenshotSaveEnabled {
    $settings = Get-ClipDeckSettings
    return [bool]$settings.screenshotSaveEnabled
}

function Set-ScreenshotSaveEnabled {
    param([bool]$Enabled)
    Save-ClipDeckSettings -IdleShutdownEnabled (Get-IdleShutdownEnabled) -IdleShutdownHours (Get-IdleShutdownHours) -ScreenshotSaveEnabled $Enabled
}

function Get-PasteCurrentHotkey {
    $settings = Get-ClipDeckSettings
    if ([string]::IsNullOrWhiteSpace($settings.pasteCurrentHotkey)) { return 'Ctrl+1' }
    return [string]$settings.pasteCurrentHotkey
}

function Get-PasteSecondHotkey {
    $settings = Get-ClipDeckSettings
    if ([string]::IsNullOrWhiteSpace($settings.pasteSecondHotkey)) { return 'Ctrl+2' }
    return [string]$settings.pasteSecondHotkey
}

function Get-PasteThirdHotkey {
    $settings = Get-ClipDeckSettings
    if ([string]::IsNullOrWhiteSpace($settings.pasteThirdHotkey)) { return 'Ctrl+3' }
    return [string]$settings.pasteThirdHotkey
}

function Get-StorageRoot {
    $settings = Get-ClipDeckSettings
    if ([string]::IsNullOrWhiteSpace($settings.storageRoot)) {
        return (Join-Path ([Environment]::GetFolderPath('Desktop')) 'ClipDeck')
    }
    return [string]$settings.storageRoot
}

function Get-RetentionDays {
    $settings = Get-ClipDeckSettings
    $days = [int]$settings.retentionDays
    if ($days -lt 1) { return 7 }
    if ($days -gt 365) { return 365 }
    return $days
}

function Get-LastCleanupUtc {
    $settings = Get-ClipDeckSettings
    if ([string]::IsNullOrWhiteSpace($settings.lastCleanupUtc)) { return '' }
    return [string]$settings.lastCleanupUtc
}

function Get-ScreenshotHotkey {
    $settings = Get-ClipDeckSettings
    if ([string]::IsNullOrWhiteSpace($settings.screenshotHotkey)) { return 'Win+Shift+D' }
    return [string]$settings.screenshotHotkey
}

function Get-OcrHotkey {
    $settings = Get-ClipDeckSettings
    if ([string]::IsNullOrWhiteSpace($settings.ocrHotkey)) { return 'Win+Shift+Z' }
    return [string]$settings.ocrHotkey
}

function Get-RecordHotkey {
    $settings = Get-ClipDeckSettings
    if ([string]::IsNullOrWhiteSpace($settings.recordHotkey)) { return 'Win+Shift+R' }
    return [string]$settings.recordHotkey
}

function Get-RulerHotkey {
    $settings = Get-ClipDeckSettings
    if ([string]::IsNullOrWhiteSpace($settings.rulerHotkey)) { return 'Alt+Shift+W' }
    return [string]$settings.rulerHotkey
}

function Get-RecordingFormat {
    $settings = Get-ClipDeckSettings
    $format = ([string]$settings.recordingFormat).ToUpperInvariant()
    if ($format -notin @('MP4', 'GIF')) { return 'MP4' }
    return $format
}

function Get-RecordingFps {
    $settings = Get-ClipDeckSettings
    $fps = [int]$settings.recordingFps
    if ($fps -notin @(24, 30, 60)) { return 24 }
    return $fps
}

function Get-RecordingCaptureCursor {
    $settings = Get-ClipDeckSettings
    return [bool]$settings.recordingCaptureCursor
}

function Get-AndroidMirrorEnabled {
    $settings = Get-ClipDeckSettings
    return [bool]$settings.androidMirrorEnabled
}

function Get-AndroidMirrorRoot {
    $settings = Get-ClipDeckSettings
    if ([string]::IsNullOrWhiteSpace($settings.androidMirrorRoot)) { return '' }
    return [string]$settings.androidMirrorRoot
}

function Set-StorageRoot {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    Save-ClipDeckSettings -IdleShutdownEnabled (Get-IdleShutdownEnabled) -IdleShutdownHours (Get-IdleShutdownHours) -ScreenshotSaveEnabled (Get-ScreenshotSaveEnabled) -StorageRoot $Path
}

function Set-RetentionDays {
    param([int]$Days)
    Save-ClipDeckSettings -IdleShutdownEnabled (Get-IdleShutdownEnabled) -IdleShutdownHours (Get-IdleShutdownHours) -ScreenshotSaveEnabled (Get-ScreenshotSaveEnabled) -RetentionDays $Days
}

function Set-RecordingOptions {
    param([string]$Format, [int]$Fps, [bool]$CaptureCursor)
    Save-ClipDeckSettings `
        -IdleShutdownEnabled (Get-IdleShutdownEnabled) `
        -IdleShutdownHours (Get-IdleShutdownHours) `
        -ScreenshotSaveEnabled (Get-ScreenshotSaveEnabled) `
        -RecordingFormat $Format `
        -RecordingFps $Fps `
        -RecordingCaptureCursor $CaptureCursor
}

function Set-AndroidMirror {
    param([bool]$Enabled, [string]$Path)
    Save-ClipDeckSettings `
        -IdleShutdownEnabled (Get-IdleShutdownEnabled) `
        -IdleShutdownHours (Get-IdleShutdownHours) `
        -ScreenshotSaveEnabled (Get-ScreenshotSaveEnabled) `
        -AndroidMirrorEnabled $Enabled `
        -AndroidMirrorRoot $Path
}

function Set-PasteHotkey {
    param(
        [ValidateSet('current', 'second', 'third')]
        [string]$Slot,
        [string]$Hotkey
    )
    $current = Get-PasteCurrentHotkey
    $second = Get-PasteSecondHotkey
    $third = Get-PasteThirdHotkey
    if ($Slot -eq 'current') { $current = $Hotkey }
    if ($Slot -eq 'second') { $second = $Hotkey }
    if ($Slot -eq 'third') { $third = $Hotkey }

    Save-ClipDeckSettings `
        -IdleShutdownEnabled (Get-IdleShutdownEnabled) `
        -IdleShutdownHours (Get-IdleShutdownHours) `
        -ScreenshotSaveEnabled (Get-ScreenshotSaveEnabled) `
        -PasteCurrentHotkey $current `
        -PasteSecondHotkey $second `
        -PasteThirdHotkey $third
}

function Set-CaptureHotkey {
    param(
        [ValidateSet('screenshot', 'ocr', 'record', 'ruler')]
        [string]$Slot,
        [string]$Hotkey
    )
    $screenshot = Get-ScreenshotHotkey
    $ocr = Get-OcrHotkey
    $record = Get-RecordHotkey
    $ruler = Get-RulerHotkey
    if ($Slot -eq 'screenshot') { $screenshot = $Hotkey }
    if ($Slot -eq 'ocr') { $ocr = $Hotkey }
    if ($Slot -eq 'record') { $record = $Hotkey }
    if ($Slot -eq 'ruler') { $ruler = $Hotkey }

    Save-ClipDeckSettings `
        -IdleShutdownEnabled (Get-IdleShutdownEnabled) `
        -IdleShutdownHours (Get-IdleShutdownHours) `
        -ScreenshotSaveEnabled (Get-ScreenshotSaveEnabled) `
        -ScreenshotHotkey $screenshot `
        -OcrHotkey $ocr `
        -RecordHotkey $record `
        -RulerHotkey $ruler
}

function Get-ProcessByCommandLine {
    param([string]$Needle)
    $currentPid = $PID
    Get-CimInstance Win32_Process |
        Where-Object {
            $_.ProcessId -ne $currentPid -and
            -not [string]::IsNullOrWhiteSpace($_.CommandLine) -and
            $_.CommandLine.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
        }
}

function Start-ClipDeckWatchdog {
    if (-not (Test-Path -LiteralPath $watchdogPath)) {
        return
    }

    $running = @(Get-ProcessByCommandLine -Needle 'clipboard-hotkeys-watchdog.ps1')
    if ($running.Count -gt 0) {
        return
    }

    Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        $watchdogPath
    ) -WindowStyle Hidden
}

function Restart-ClipDeckWatchdog {
    Get-ProcessByCommandLine -Needle 'clipboard-hotkeys-watchdog.ps1' |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
    Get-ProcessByCommandLine -Needle 'clipboard-second-paste.ps1' |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
    Start-Sleep -Milliseconds 700
    Start-ClipDeckWatchdog
}

function Get-LastLogLine {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return 'no log'
    }
    $line = Get-Content -Tail 1 -LiteralPath $Path
    if ([string]::IsNullOrWhiteSpace($line)) {
        return 'empty log'
    }
    return $line
}

function Cancel-ClipDeckShutdown {
    shutdown.exe /a | Out-Null
}

function Remove-LatestClipDeckScreenshot {
    $screenshots = Join-Path (Get-StorageRoot) 'Screenshots'
    $latest = Get-ChildItem -LiteralPath $screenshots -Filter 'ClipDeck Screenshot *.png' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $latest) {
        [System.Windows.Forms.MessageBox]::Show('No ClipDeck screenshots found on the desktop.', 'ClipDeck', 'OK', 'Information') | Out-Null
        return
    }

    $answer = [System.Windows.Forms.MessageBox]::Show(
        ('Delete latest ClipDeck screenshot?' + [Environment]::NewLine + $latest.Name),
        'ClipDeck',
        'YesNo',
        'Warning'
    )
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
        return
    }

    Remove-Item -LiteralPath $latest.FullName -Force
}

function Initialize-StorageFolders {
    $rootPath = Get-StorageRoot
    foreach ($name in @('', 'Screenshots', 'Recordings', 'OCR')) {
        $path = if ([string]::IsNullOrWhiteSpace($name)) { $rootPath } else { Join-Path $rootPath $name }
        New-Item -ItemType Directory -Force -Path $path | Out-Null
    }

    $androidRoot = Get-AndroidMirrorRoot
    if ((Get-AndroidMirrorEnabled) -and -not [string]::IsNullOrWhiteSpace($androidRoot)) {
        foreach ($name in @('', 'Screenshots', 'Recordings', 'OCR')) {
            $path = if ([string]::IsNullOrWhiteSpace($name)) { $androidRoot } else { Join-Path $androidRoot $name }
            New-Item -ItemType Directory -Force -Path $path | Out-Null
        }
    }
}

function Invoke-StorageCleanup {
    Initialize-StorageFolders
    $cutoff = (Get-Date).AddDays(-1 * (Get-RetentionDays))
    foreach ($name in @('Screenshots', 'Recordings', 'OCR')) {
        $path = Join-Path (Get-StorageRoot) $name
        Get-ChildItem -LiteralPath $path -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

function Get-LastCapturePath {
    $path = Join-Path $root 'last-capture.txt'
    if (-not (Test-Path -LiteralPath $path)) { return '' }
    return (Get-Content -Raw -LiteralPath $path).Trim()
}

function Open-StorageRoot {
    Initialize-StorageFolders
    Start-Process -FilePath (Get-StorageRoot)
}

function Open-LastCapture {
    $path = Get-LastCapturePath
    if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path)) {
        [System.Windows.Forms.MessageBox]::Show('No saved ClipDeck capture found yet.', 'ClipDeck', 'OK', 'Information') | Out-Null
        return
    }
    Start-Process -FilePath $path
}

function Test-ClipDeckTool {
    param([string]$Name)
    $toolPath = Join-Path $root "tools\$Name"
    if (Test-Path -LiteralPath $toolPath) { return $true }
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

Start-ClipDeckWatchdog
Initialize-StorageFolders
Invoke-StorageCleanup

$bg = [System.Drawing.Color]::FromArgb(9, 13, 23)
$surface = [System.Drawing.Color]::FromArgb(18, 24, 37)
$surface2 = [System.Drawing.Color]::FromArgb(27, 35, 51)
$surface3 = [System.Drawing.Color]::FromArgb(36, 45, 64)
$line = [System.Drawing.Color]::FromArgb(57, 69, 92)
$text = [System.Drawing.Color]::FromArgb(249, 250, 252)
$muted = [System.Drawing.Color]::FromArgb(151, 164, 187)
$green = [System.Drawing.Color]::FromArgb(52, 211, 153)
$pink = [System.Drawing.Color]::FromArgb(255, 78, 146)
$red = [System.Drawing.Color]::FromArgb(248, 113, 113)
$orange = [System.Drawing.Color]::FromArgb(251, 146, 60)
$blue = [System.Drawing.Color]::FromArgb(56, 189, 248)
$cyan = [System.Drawing.Color]::FromArgb(34, 211, 238)
$yellow = [System.Drawing.Color]::FromArgb(250, 204, 21)
$purple = [System.Drawing.Color]::FromArgb(129, 140, 248)
$neonPurple = [System.Drawing.Color]::FromArgb(202, 107, 255)
$neonPurpleSoft = [System.Drawing.Color]::FromArgb(118, 202, 107, 255)
$neonPurpleFaint = [System.Drawing.Color]::FromArgb(62, 202, 107, 255)

$form = New-Object System.Windows.Forms.Form
$form.Text = 'ClipDeck'
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(468, 958)
$form.MinimumSize = New-Object System.Drawing.Size(484, 997)
$form.MaximumSize = New-Object System.Drawing.Size(484, 997)
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.BackColor = $bg
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
if (Test-Path -LiteralPath $iconPath) {
    $form.Icon = New-Object System.Drawing.Icon($iconPath)
}

function New-RoundedPath {
    param([System.Drawing.Rectangle]$Bounds, [int]$Radius)
    $diameter = $Radius * 2
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($Bounds.X, $Bounds.Y, $diameter, $diameter, 180, 90)
    $path.AddArc(($Bounds.Right - $diameter), $Bounds.Y, $diameter, $diameter, 270, 90)
    $path.AddArc(($Bounds.Right - $diameter), ($Bounds.Bottom - $diameter), $diameter, $diameter, 0, 90)
    $path.AddArc($Bounds.X, ($Bounds.Bottom - $diameter), $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Set-RoundedRegion {
    param($Control, [int]$Radius)
    if ($Control.Width -le 0 -or $Control.Height -le 0) { return }
    $bounds = New-Object System.Drawing.Rectangle(0, 0, $Control.Width, $Control.Height)
    $Control.Region = New-Object System.Drawing.Region((New-RoundedPath -Bounds $bounds -Radius $Radius))
}

function Add-RoundedBorder {
    param($Control, [int]$Radius, [System.Drawing.Color]$BorderColor)
    $Control.Add_SizeChanged({
        param($sender, $eventArgs)
        Set-RoundedRegion -Control $sender -Radius $Radius
        $sender.Invalidate()
    }.GetNewClosure())
    $Control.Add_Paint({
        param($sender, $eventArgs)
        $eventArgs.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $rect = New-Object System.Drawing.Rectangle(0, 0, ($sender.Width - 1), ($sender.Height - 1))
        $path = New-RoundedPath -Bounds $rect -Radius $Radius
        $pen = New-Object System.Drawing.Pen($BorderColor, 1)
        $eventArgs.Graphics.DrawPath($pen, $path)
        $pen.Dispose()
        $path.Dispose()
    }.GetNewClosure())
    Set-RoundedRegion -Control $Control -Radius $Radius
}

function New-Text {
    param(
        [string]$Text,
        [int]$Left,
        [int]$Top,
        [int]$Width,
        [int]$Height,
        [System.Drawing.Color]$Color,
        [System.Drawing.Font]$Font
    )
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.ForeColor = $Color
    $label.BackColor = [System.Drawing.Color]::Transparent
    $label.Location = New-Object System.Drawing.Point($Left, $Top)
    $label.Size = New-Object System.Drawing.Size($Width, $Height)
    $label.Font = $Font
    $form.Controls.Add($label)
    return $label
}

function New-Card {
    param(
        [int]$Left,
        [int]$Top,
        [int]$Width,
        [int]$Height,
        [System.Drawing.Color]$Back = $surface,
        [System.Drawing.Color]$Accent = $neonPurpleFaint
    )
    $card = New-Object System.Windows.Forms.Panel
    $card.BackColor = $Back
    $card.Location = New-Object System.Drawing.Point($Left, $Top)
    $card.Size = New-Object System.Drawing.Size($Width, $Height)
    Add-RoundedBorder -Control $card -Radius 16 -BorderColor $Accent
    $form.Controls.Add($card)

    $accentStrip = New-Object System.Windows.Forms.Panel
    $accentStrip.BackColor = $Accent
    $accentStrip.Location = New-Object System.Drawing.Point(0, 16)
    $accentStrip.Size = New-Object System.Drawing.Size(4, ($Height - 32))
    Add-RoundedBorder -Control $accentStrip -Radius 3 -BorderColor $Accent
    $card.Controls.Add($accentStrip)

    return $card
}

function Set-ToggleChecked {
    param($Toggle, [bool]$Checked)
    $Toggle.Tag.Checked = $Checked
    $Toggle.Invalidate()
}

function Get-ToggleChecked {
    param($Toggle)
    return [bool]$Toggle.Tag.Checked
}

function New-Toggle {
    param(
        [int]$Left,
        [int]$Top,
        [bool]$Checked,
        [scriptblock]$OnChanged
    )
    $toggle = New-Object System.Windows.Forms.Panel
    $toggle.Location = New-Object System.Drawing.Point($Left, $Top)
    $toggle.Size = New-Object System.Drawing.Size(52, 28)
    $toggle.Cursor = 'Hand'
    $toggle.BackColor = [System.Drawing.Color]::Transparent
    $toggle.Tag = [pscustomobject]@{
        Checked = $Checked
        Handler = $OnChanged
    }
    $toggle.Add_Paint({
        param($sender, $eventArgs)
        $checkedNow = [bool]$sender.Tag.Checked
        $eventArgs.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $trackRect = New-Object System.Drawing.Rectangle(0, 0, 51, 27)
        $trackPath = New-RoundedPath -Bounds $trackRect -Radius 14
        $trackColor = if ($checkedNow) { [System.Drawing.Color]::FromArgb(44, 205, 135) } else { [System.Drawing.Color]::FromArgb(50, 61, 82) }
        $trackBrush = New-Object System.Drawing.SolidBrush($trackColor)
        $eventArgs.Graphics.FillPath($trackBrush, $trackPath)
        $trackBrush.Dispose()
        $trackPath.Dispose()

        $thumbX = if ($checkedNow) { 26 } else { 3 }
        $thumbRect = New-Object System.Drawing.Rectangle($thumbX, 3, 22, 22)
        $shadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(55, 0, 0, 0))
        $eventArgs.Graphics.FillEllipse($shadowBrush, ($thumbX + 1), 5, 22, 22)
        $shadowBrush.Dispose()
        $thumbBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(250, 250, 252))
        $eventArgs.Graphics.FillEllipse($thumbBrush, $thumbRect)
        $thumbBrush.Dispose()
    })
    $toggle.Add_Click({
        param($sender, $eventArgs)
        $sender.Tag.Checked = -not [bool]$sender.Tag.Checked
        $sender.Invalidate()
        if ($sender.Tag.Handler) {
            & $sender.Tag.Handler ([bool]$sender.Tag.Checked)
        }
    })
    $form.Controls.Add($toggle)
    return $toggle
}

$guardLabel = New-Object System.Windows.Forms.Label
$guardLabel.Text = 'Idle guard'
$guardLabel.ForeColor = $muted
$guardLabel.TextAlign = 'MiddleRight'
$guardLabel.Location = New-Object System.Drawing.Point(84, 22)
$guardLabel.Size = New-Object System.Drawing.Size(78, 22)
$form.Controls.Add($guardLabel)

$idleToggle = New-Toggle -Left 24 -Top 19 -Checked (Get-IdleShutdownEnabled) -OnChanged {
    param([bool]$Enabled)
    Set-IdleShutdownEnabled -Enabled $Enabled
}

$hoursStepper = New-Object System.Windows.Forms.Panel
$hoursStepper.BackColor = $surface2
$hoursStepper.Location = New-Object System.Drawing.Point(170, 18)
$hoursStepper.Size = New-Object System.Drawing.Size(98, 30)
Add-RoundedBorder -Control $hoursStepper -Radius 12 -BorderColor $neonPurpleSoft
$form.Controls.Add($hoursStepper)

$hoursValueLabel = New-Object System.Windows.Forms.Label
$hoursValueLabel.ForeColor = $text
$hoursValueLabel.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
$hoursValueLabel.TextAlign = 'MiddleCenter'
$hoursValueLabel.Location = New-Object System.Drawing.Point(31, 4)
$hoursValueLabel.Size = New-Object System.Drawing.Size(36, 22)
$hoursStepper.Controls.Add($hoursValueLabel)

function New-StepperButton {
    param([string]$Caption, [int]$Left, [scriptblock]$Handler)
    $button = New-Object System.Windows.Forms.Label
    $button.Text = $Caption
    $button.ForeColor = $muted
    $button.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 11)
    $button.TextAlign = 'MiddleCenter'
    $button.Location = New-Object System.Drawing.Point($Left, 3)
    $button.Size = New-Object System.Drawing.Size(26, 24)
    $button.Cursor = 'Hand'
    $button.Add_Click($Handler)
    $hoursStepper.Controls.Add($button)
    return $button
}

function Set-HoursUi {
    param([int]$Hours)
    if ($Hours -lt 1) { $Hours = 1 }
    if ($Hours -gt 5) { $Hours = 5 }
    $hoursValueLabel.Text = ('{0}h' -f $Hours)
}

$minusHourButton = New-StepperButton -Caption '-' -Left 4 -Handler {
    $next = (Get-IdleShutdownHours) - 1
    if ($next -lt 1) { $next = 1 }
    Set-IdleShutdownHours -Hours $next
    Set-HoursUi -Hours $next
}
$plusHourButton = New-StepperButton -Caption '+' -Left 68 -Handler {
    $next = (Get-IdleShutdownHours) + 1
    if ($next -gt 5) { $next = 5 }
    Set-IdleShutdownHours -Hours $next
    Set-HoursUi -Hours $next
}
Set-HoursUi -Hours (Get-IdleShutdownHours)

$screenshotLabel = New-Object System.Windows.Forms.Label
$screenshotLabel.Text = 'Shot save'
$screenshotLabel.ForeColor = $muted
$screenshotLabel.TextAlign = 'MiddleRight'
$screenshotLabel.Location = New-Object System.Drawing.Point(300, 22)
$screenshotLabel.Size = New-Object System.Drawing.Size(78, 22)
$form.Controls.Add($screenshotLabel)

$screenshotToggle = New-Toggle -Left 386 -Top 19 -Checked (Get-ScreenshotSaveEnabled) -OnChanged {
    param([bool]$Enabled)
    Set-ScreenshotSaveEnabled -Enabled $Enabled
}

$hotkeysBox = New-Card -Left 24 -Top 68 -Width 420 -Height 188 -Accent $red
$hotkeysHeader = New-Object System.Windows.Forms.Label
$hotkeysHeader.Text = 'HOTKEY PASTE'
$hotkeysHeader.ForeColor = $red
$hotkeysHeader.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8)
$hotkeysHeader.Location = New-Object System.Drawing.Point(20, 16)
$hotkeysHeader.Size = New-Object System.Drawing.Size(140, 18)
$hotkeysBox.Controls.Add($hotkeysHeader)

function Convert-KeyEventToHotkeyText {
    param([System.Windows.Forms.KeyEventArgs]$EventArgs)
    $key = $EventArgs.KeyCode
    if ($key -in @(
        [System.Windows.Forms.Keys]::ControlKey,
        [System.Windows.Forms.Keys]::ShiftKey,
        [System.Windows.Forms.Keys]::Menu,
        [System.Windows.Forms.Keys]::LControlKey,
        [System.Windows.Forms.Keys]::RControlKey,
        [System.Windows.Forms.Keys]::LShiftKey,
        [System.Windows.Forms.Keys]::RShiftKey,
        [System.Windows.Forms.Keys]::LMenu,
        [System.Windows.Forms.Keys]::RMenu,
        [System.Windows.Forms.Keys]::LWin,
        [System.Windows.Forms.Keys]::RWin
    )) {
        return $null
    }

    $parts = @()
    if ($EventArgs.Control) { $parts += 'Ctrl' }
    if ($EventArgs.Alt) { $parts += 'Alt' }
    if ($EventArgs.Shift) { $parts += 'Shift' }
    if ($parts.Count -eq 0) { return $null }

    $keyName = $key.ToString()
    if ($keyName -match '^D([0-9])$') {
        $keyName = $matches[1]
    } elseif ($keyName -match '^NumPad([0-9])$') {
        $keyName = 'Num' + $matches[1]
    } elseif ($keyName -eq 'Oemtilde') {
        $keyName = '`'
    } elseif ($keyName -eq 'OemMinus') {
        $keyName = '-'
    } elseif ($keyName -eq 'Oemplus') {
        $keyName = '='
    } elseif ($keyName -eq 'OemOpenBrackets') {
        $keyName = '['
    } elseif ($keyName -eq 'OemCloseBrackets') {
        $keyName = ']'
    } elseif ($keyName -eq 'OemPipe') {
        $keyName = '\'
    } elseif ($keyName -eq 'OemSemicolon') {
        $keyName = ';'
    } elseif ($keyName -eq 'OemQuotes') {
        $keyName = "'"
    } elseif ($keyName -eq 'Oemcomma') {
        $keyName = ','
    } elseif ($keyName -eq 'OemPeriod') {
        $keyName = '.'
    } elseif ($keyName -eq 'OemQuestion') {
        $keyName = '/'
    }

    return (($parts + $keyName) -join '+')
}

function Show-HotkeyCaptureDialog {
    param([string]$CurrentHotkey)
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = 'Set hotkey'
    $dialog.StartPosition = 'CenterParent'
    $dialog.ClientSize = New-Object System.Drawing.Size(330, 148)
    $dialog.FormBorderStyle = 'FixedDialog'
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.TopMost = $true
    $dialog.KeyPreview = $true
    $dialog.BackColor = $bg
    $dialog.ForeColor = $text
    $dialog.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'Press new shortcut'
    $title.ForeColor = $text
    $title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
    $title.Location = New-Object System.Drawing.Point(22, 20)
    $title.Size = New-Object System.Drawing.Size(260, 28)
    $dialog.Controls.Add($title)

    $hint = New-Object System.Windows.Forms.Label
    $hint.Text = ('Current: {0}. Use Ctrl / Alt / Shift + key. Esc cancels.' -f $CurrentHotkey)
    $hint.ForeColor = $muted
    $hint.Location = New-Object System.Drawing.Point(24, 58)
    $hint.Size = New-Object System.Drawing.Size(280, 36)
    $dialog.Controls.Add($hint)

    $preview = New-Object System.Windows.Forms.Label
    $preview.Text = 'waiting...'
    $preview.ForeColor = $green
    $preview.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 11)
    $preview.TextAlign = 'MiddleCenter'
    $preview.Location = New-Object System.Drawing.Point(24, 102)
    $preview.Size = New-Object System.Drawing.Size(282, 28)
    $preview.BackColor = $surface2
    Add-RoundedBorder -Control $preview -Radius 10 -BorderColor $neonPurpleSoft
    $dialog.Controls.Add($preview)

    $dialog.Tag = $null
    $dialog.Add_KeyDown({
        param($sender, $eventArgs)
        if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
            $sender.Close()
            return
        }
        $hotkey = Convert-KeyEventToHotkeyText -EventArgs $eventArgs
        if ([string]::IsNullOrWhiteSpace($hotkey)) {
            $preview.Text = 'use modifier + key'
            $preview.ForeColor = $pink
            return
        }
        $sender.Tag = $hotkey
        $sender.Close()
    })

    $dialog.ShowDialog($form) | Out-Null
    return [string]$dialog.Tag
}

function Test-HotkeyDuplicate {
    param([string]$Slot, [string]$Hotkey)
    $target = $Hotkey.ToLowerInvariant()
    $pairs = @{
        current = (Get-PasteCurrentHotkey)
        second = (Get-PasteSecondHotkey)
        third = (Get-PasteThirdHotkey)
    }
    foreach ($key in $pairs.Keys) {
        if ($key -ne $Slot -and $pairs[$key].ToLowerInvariant() -eq $target) {
            return $true
        }
    }
    return $false
}

function Test-AnyHotkeyDuplicate {
    param([string]$Slot, [string]$Hotkey)
    $target = $Hotkey.ToLowerInvariant()
    $pairs = @{
        current = (Get-PasteCurrentHotkey)
        second = (Get-PasteSecondHotkey)
        third = (Get-PasteThirdHotkey)
        screenshot = (Get-ScreenshotHotkey)
        ocr = (Get-OcrHotkey)
        record = (Get-RecordHotkey)
        ruler = (Get-RulerHotkey)
    }
    foreach ($key in $pairs.Keys) {
        if ($key -ne $Slot -and $pairs[$key].ToLowerInvariant() -eq $target) {
            return $true
        }
    }
    return $false
}

function Change-PasteHotkey {
    param([string]$Slot, $KeyLabel)
    $newHotkey = Show-HotkeyCaptureDialog -CurrentHotkey $KeyLabel.Text
    if ([string]::IsNullOrWhiteSpace($newHotkey)) {
        return
    }
    if (Test-AnyHotkeyDuplicate -Slot $Slot -Hotkey $newHotkey) {
        [System.Windows.Forms.MessageBox]::Show('This shortcut is already used by another ClipDeck paste action.', 'ClipDeck', 'OK', 'Warning') | Out-Null
        return
    }
    Set-PasteHotkey -Slot $Slot -Hotkey $newHotkey
    $KeyLabel.Text = $newHotkey.Replace('+', ' + ')
    Restart-ClipDeckWatchdog
    Start-Sleep -Milliseconds 500
    Update-Status
}

function Change-CaptureHotkey {
    param([string]$Slot, $KeyLabel)
    $newHotkey = Show-HotkeyCaptureDialog -CurrentHotkey $KeyLabel.Text
    if ([string]::IsNullOrWhiteSpace($newHotkey)) {
        return
    }
    if (Test-AnyHotkeyDuplicate -Slot $Slot -Hotkey $newHotkey) {
        [System.Windows.Forms.MessageBox]::Show('This shortcut is already used by another ClipDeck action.', 'ClipDeck', 'OK', 'Warning') | Out-Null
        return
    }
    Set-CaptureHotkey -Slot $Slot -Hotkey $newHotkey
    $KeyLabel.Text = $newHotkey.Replace('+', ' + ')
    Restart-ClipDeckWatchdog
    Start-Sleep -Milliseconds 500
    Update-Status
}

function New-HotkeyRow {
    param([int]$Top, [string]$KeyText, [string]$CaptionText, [string]$HintText)
    $key = New-Object System.Windows.Forms.Label
    $key.Text = $KeyText.Replace('+', ' + ')
    $key.ForeColor = $text
    $key.BackColor = $surface3
    $key.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
    $key.TextAlign = 'MiddleCenter'
    $key.Location = New-Object System.Drawing.Point(20, $Top)
    $key.Size = New-Object System.Drawing.Size(104, 32)
    $key.Cursor = 'Hand'
    Add-RoundedBorder -Control $key -Radius 9 -BorderColor $neonPurpleSoft
    $hotkeysBox.Controls.Add($key)

    $caption = New-Object System.Windows.Forms.Label
    $caption.Text = $CaptionText
    $caption.ForeColor = $text
    $caption.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
    $caption.Location = New-Object System.Drawing.Point(144, ($Top - 2))
    $caption.Size = New-Object System.Drawing.Size(230, 18)
    $hotkeysBox.Controls.Add($caption)

    $hint = New-Object System.Windows.Forms.Label
    $hint.Text = $HintText
    $hint.ForeColor = $muted
    $hint.Location = New-Object System.Drawing.Point(144, ($Top + 18))
    $hint.Size = New-Object System.Drawing.Size(248, 18)
    $hotkeysBox.Controls.Add($hint)

    return $key
}

$currentHotkeyLabel = New-HotkeyRow -Top 46 -KeyText (Get-PasteCurrentHotkey) -CaptionText 'Paste current clipboard' -HintText 'click shortcut to change it'
$secondHotkeyLabel = New-HotkeyRow -Top 94 -KeyText (Get-PasteSecondHotkey) -CaptionText 'Paste second saved clip' -HintText 'click shortcut to change it'
$thirdHotkeyLabel = New-HotkeyRow -Top 142 -KeyText (Get-PasteThirdHotkey) -CaptionText 'Paste third saved clip' -HintText 'click shortcut to change it'

$currentHotkeyLabel.Add_Click({ Change-PasteHotkey -Slot 'current' -KeyLabel $currentHotkeyLabel })
$secondHotkeyLabel.Add_Click({ Change-PasteHotkey -Slot 'second' -KeyLabel $secondHotkeyLabel })
$thirdHotkeyLabel.Add_Click({ Change-PasteHotkey -Slot 'third' -KeyLabel $thirdHotkeyLabel })

$storageBox = New-Card -Left 24 -Top 272 -Width 420 -Height 126 -Accent $orange
$storageHeader = New-Object System.Windows.Forms.Label
$storageHeader.Text = 'CAPTURE STORAGE'
$storageHeader.ForeColor = $orange
$storageHeader.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8)
$storageHeader.Location = New-Object System.Drawing.Point(20, 14)
$storageHeader.Size = New-Object System.Drawing.Size(160, 16)
$storageBox.Controls.Add($storageHeader)

$storagePathLabel = New-Object System.Windows.Forms.Label
$storagePathLabel.Text = Get-StorageRoot
$storagePathLabel.ForeColor = $text
$storagePathLabel.BackColor = $surface2
$storagePathLabel.Font = New-Object System.Drawing.Font('Segoe UI', 8)
$storagePathLabel.Location = New-Object System.Drawing.Point(20, 42)
$storagePathLabel.Size = New-Object System.Drawing.Size(250, 28)
$storagePathLabel.TextAlign = 'MiddleLeft'
Add-RoundedBorder -Control $storagePathLabel -Radius 9 -BorderColor $neonPurpleFaint
$storageBox.Controls.Add($storagePathLabel)

function New-InnerButton {
    param($Parent, [string]$Caption, [int]$Left, [int]$Top, [int]$Width, [scriptblock]$Handler)
    $button = New-Object System.Windows.Forms.Label
    $button.Text = $Caption
    $button.ForeColor = $text
    $button.BackColor = $surface3
    $button.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8)
    $button.TextAlign = 'MiddleCenter'
    $button.Location = New-Object System.Drawing.Point($Left, $Top)
    $button.Size = New-Object System.Drawing.Size($Width, 28)
    $button.Cursor = 'Hand'
    Add-RoundedBorder -Control $button -Radius 9 -BorderColor $neonPurpleSoft
    $button.Add_Click($Handler)
    $Parent.Controls.Add($button)
    return $button
}

New-InnerButton -Parent $storageBox -Caption 'Browse' -Left 282 -Top 42 -Width 56 -Handler {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Choose ClipDeck capture storage folder'
    $dialog.SelectedPath = Get-StorageRoot
    if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        Set-StorageRoot -Path $dialog.SelectedPath
        Initialize-StorageFolders
        $storagePathLabel.Text = Get-StorageRoot
        Update-Status
    }
} | Out-Null

New-InnerButton -Parent $storageBox -Caption 'Open' -Left 346 -Top 42 -Width 52 -Handler { Open-StorageRoot } | Out-Null

$retentionLabel = New-Object System.Windows.Forms.Label
$retentionLabel.Text = 'Delete old files after'
$retentionLabel.ForeColor = $muted
$retentionLabel.Location = New-Object System.Drawing.Point(20, 86)
$retentionLabel.Size = New-Object System.Drawing.Size(136, 20)
$storageBox.Controls.Add($retentionLabel)

$retentionValueLabel = New-Object System.Windows.Forms.Label
$retentionValueLabel.ForeColor = $text
$retentionValueLabel.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
$retentionValueLabel.TextAlign = 'MiddleCenter'
$retentionValueLabel.Location = New-Object System.Drawing.Point(170, 82)
$retentionValueLabel.Size = New-Object System.Drawing.Size(70, 28)
$retentionValueLabel.BackColor = $surface2
Add-RoundedBorder -Control $retentionValueLabel -Radius 9 -BorderColor $neonPurpleSoft
$storageBox.Controls.Add($retentionValueLabel)

New-InnerButton -Parent $storageBox -Caption '-' -Left 250 -Top 82 -Width 32 -Handler {
    Set-RetentionDays -Days ((Get-RetentionDays) - 1)
    Update-Status
} | Out-Null
New-InnerButton -Parent $storageBox -Caption '+' -Left 288 -Top 82 -Width 32 -Handler {
    Set-RetentionDays -Days ((Get-RetentionDays) + 1)
    Update-Status
} | Out-Null
New-InnerButton -Parent $storageBox -Caption 'Last' -Left 346 -Top 82 -Width 52 -Handler { Open-LastCapture } | Out-Null

$androidBox = New-Card -Left 24 -Top 414 -Width 420 -Height 94 -Accent $yellow
$androidHeader = New-Object System.Windows.Forms.Label
$androidHeader.Text = 'ANDROID MIRROR'
$androidHeader.ForeColor = $yellow
$androidHeader.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8)
$androidHeader.Location = New-Object System.Drawing.Point(20, 14)
$androidHeader.Size = New-Object System.Drawing.Size(160, 16)
$androidBox.Controls.Add($androidHeader)

$androidPathLabel = New-Object System.Windows.Forms.Label
$androidPathLabel.Text = if ([string]::IsNullOrWhiteSpace((Get-AndroidMirrorRoot))) { 'Choose Android/sync folder' } else { Get-AndroidMirrorRoot }
$androidPathLabel.ForeColor = $text
$androidPathLabel.BackColor = $surface2
$androidPathLabel.Font = New-Object System.Drawing.Font('Segoe UI', 8)
$androidPathLabel.Location = New-Object System.Drawing.Point(20, 48)
$androidPathLabel.Size = New-Object System.Drawing.Size(196, 28)
$androidPathLabel.TextAlign = 'MiddleLeft'
Add-RoundedBorder -Control $androidPathLabel -Radius 9 -BorderColor $neonPurpleFaint
$androidBox.Controls.Add($androidPathLabel)

$androidMirrorLabel = New-Object System.Windows.Forms.Label
$androidMirrorLabel.Text = 'mirror'
$androidMirrorLabel.ForeColor = $muted
$androidMirrorLabel.Location = New-Object System.Drawing.Point(224, 52)
$androidMirrorLabel.Size = New-Object System.Drawing.Size(46, 20)
$androidBox.Controls.Add($androidMirrorLabel)

$androidToggle = New-Toggle -Left 0 -Top 0 -Checked (Get-AndroidMirrorEnabled) -OnChanged {
    param([bool]$Enabled)
    Set-AndroidMirror -Enabled $Enabled -Path (Get-AndroidMirrorRoot)
    Initialize-StorageFolders
    Update-Status
}
$androidToggle.Parent = $androidBox
$androidToggle.Location = New-Object System.Drawing.Point(272, 48)

New-InnerButton -Parent $androidBox -Caption 'Browse' -Left 330 -Top 48 -Width 56 -Handler {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Choose Android mirror folder'
    if (-not [string]::IsNullOrWhiteSpace((Get-AndroidMirrorRoot))) {
        $dialog.SelectedPath = Get-AndroidMirrorRoot
    }
    if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        Set-AndroidMirror -Enabled (Get-AndroidMirrorEnabled) -Path $dialog.SelectedPath
        Initialize-StorageFolders
        $androidPathLabel.Text = Get-AndroidMirrorRoot
        Update-Status
    }
} | Out-Null

$captureBox = New-Card -Left 24 -Top 524 -Width 420 -Height 198 -Accent $cyan
$captureHeader = New-Object System.Windows.Forms.Label
$captureHeader.Text = 'CAPTURE TOOLS'
$captureHeader.ForeColor = $cyan
$captureHeader.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8)
$captureHeader.Location = New-Object System.Drawing.Point(20, 14)
$captureHeader.Size = New-Object System.Drawing.Size(160, 16)
$captureBox.Controls.Add($captureHeader)

function New-CaptureHotkeyRow {
    param([int]$Top, [string]$Slot, [string]$KeyText, [string]$CaptionText)
    $key = New-Object System.Windows.Forms.Label
    $key.Text = $KeyText.Replace('+', ' + ')
    $key.ForeColor = $text
    $key.BackColor = $surface3
    $key.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8)
    $key.TextAlign = 'MiddleCenter'
    $key.Location = New-Object System.Drawing.Point(20, $Top)
    $key.Size = New-Object System.Drawing.Size(118, 28)
    $key.Cursor = 'Hand'
    Add-RoundedBorder -Control $key -Radius 9 -BorderColor $neonPurpleSoft
    $captureBox.Controls.Add($key)

    $caption = New-Object System.Windows.Forms.Label
    $caption.Text = $CaptionText
    $caption.ForeColor = $text
    $caption.Location = New-Object System.Drawing.Point(148, ($Top + 4))
    $caption.Size = New-Object System.Drawing.Size(112, 20)
    $captureBox.Controls.Add($caption)

    $key.Add_Click({ Change-CaptureHotkey -Slot $Slot -KeyLabel $key }.GetNewClosure())
    return $key
}

$screenshotHotkeyLabel = New-CaptureHotkeyRow -Top 42 -Slot 'screenshot' -KeyText (Get-ScreenshotHotkey) -CaptionText 'Region screenshot'
$ocrHotkeyLabel = New-CaptureHotkeyRow -Top 78 -Slot 'ocr' -KeyText (Get-OcrHotkey) -CaptionText 'OCR ru+en to clipboard'
$recordHotkeyLabel = New-CaptureHotkeyRow -Top 114 -Slot 'record' -KeyText (Get-RecordHotkey) -CaptionText 'Record selected area'

$rulerHotkeyLabel = New-Object System.Windows.Forms.Label
$rulerHotkeyLabel.Text = (Get-RulerHotkey).Replace('+', ' + ')
$rulerHotkeyLabel.ForeColor = $text
$rulerHotkeyLabel.BackColor = $surface3
$rulerHotkeyLabel.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8)
$rulerHotkeyLabel.TextAlign = 'MiddleCenter'
$rulerHotkeyLabel.Location = New-Object System.Drawing.Point(272, 42)
$rulerHotkeyLabel.Size = New-Object System.Drawing.Size(126, 28)
$rulerHotkeyLabel.Cursor = 'Hand'
Add-RoundedBorder -Control $rulerHotkeyLabel -Radius 9 -BorderColor $neonPurpleSoft
$captureBox.Controls.Add($rulerHotkeyLabel)
$rulerHotkeyLabel.Add_Click({ Change-CaptureHotkey -Slot 'ruler' -KeyLabel $rulerHotkeyLabel })

$formatBox = New-Object System.Windows.Forms.ComboBox
$formatBox.DropDownStyle = 'DropDownList'
$formatBox.Items.AddRange(@('MP4', 'GIF'))
$formatBox.SelectedItem = Get-RecordingFormat
$formatBox.Location = New-Object System.Drawing.Point(272, 86)
$formatBox.Size = New-Object System.Drawing.Size(58, 24)
$captureBox.Controls.Add($formatBox)

$fpsBox = New-Object System.Windows.Forms.ComboBox
$fpsBox.DropDownStyle = 'DropDownList'
$fpsBox.Items.AddRange(@('24', '30', '60'))
$fpsBox.SelectedItem = [string](Get-RecordingFps)
$fpsBox.Location = New-Object System.Drawing.Point(340, 86)
$fpsBox.Size = New-Object System.Drawing.Size(58, 24)
$captureBox.Controls.Add($fpsBox)

$cursorToggleLabel = New-Object System.Windows.Forms.Label
$cursorToggleLabel.Text = 'capture cursor'
$cursorToggleLabel.ForeColor = $muted
$cursorToggleLabel.Location = New-Object System.Drawing.Point(272, 132)
$cursorToggleLabel.Size = New-Object System.Drawing.Size(96, 20)
$captureBox.Controls.Add($cursorToggleLabel)

$cursorToggle = New-Toggle -Left 382 -Top 642 -Checked (Get-RecordingCaptureCursor) -OnChanged {
    param([bool]$Enabled)
    Set-RecordingOptions -Format (Get-RecordingFormat) -Fps (Get-RecordingFps) -CaptureCursor $Enabled
}
$cursorToggle.Parent = $captureBox
$cursorToggle.Location = New-Object System.Drawing.Point(346, 126)

$dependencyLabel = New-Object System.Windows.Forms.Label
$dependencyLabel.ForeColor = $muted
$dependencyLabel.Font = New-Object System.Drawing.Font('Segoe UI', 8)
$dependencyLabel.Location = New-Object System.Drawing.Point(20, 160)
$dependencyLabel.Size = New-Object System.Drawing.Size(378, 20)
$captureBox.Controls.Add($dependencyLabel)

$formatBox.Add_SelectedIndexChanged({
    Set-RecordingOptions -Format ([string]$formatBox.SelectedItem) -Fps (Get-RecordingFps) -CaptureCursor (Get-RecordingCaptureCursor)
})
$fpsBox.Add_SelectedIndexChanged({
    Set-RecordingOptions -Format (Get-RecordingFormat) -Fps ([int]$fpsBox.SelectedItem) -CaptureCursor (Get-RecordingCaptureCursor)
})

$statusBox = New-Card -Left 24 -Top 738 -Width 420 -Height 92 -Accent $green
$statusHeader = New-Object System.Windows.Forms.Label
$statusHeader.Text = 'SYSTEM'
$statusHeader.ForeColor = $green
$statusHeader.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8)
$statusHeader.Location = New-Object System.Drawing.Point(20, 14)
$statusHeader.Size = New-Object System.Drawing.Size(120, 16)
$statusBox.Controls.Add($statusHeader)

function New-StatusRow {
    param([int]$Top, [int]$Left, [string]$Caption)
    $dot = New-Object System.Windows.Forms.Panel
    $dot.BackColor = $line
    $dot.Location = New-Object System.Drawing.Point($Left, ($Top + 6))
    $dot.Size = New-Object System.Drawing.Size(8, 8)
    Add-RoundedBorder -Control $dot -Radius 4 -BorderColor $neonPurple
    $statusBox.Controls.Add($dot)

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Caption
    $label.ForeColor = $muted
    $label.Location = New-Object System.Drawing.Point(($Left + 20), $Top)
    $label.Size = New-Object System.Drawing.Size(78, 22)
    $statusBox.Controls.Add($label)

    $value = New-Object System.Windows.Forms.Label
    $value.Text = 'checking'
    $value.ForeColor = $text
    $value.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
    $value.Location = New-Object System.Drawing.Point(($Left + 115), $Top)
    $value.Size = New-Object System.Drawing.Size(72, 22)
    $statusBox.Controls.Add($value)
    return @{ Dot = $dot; Caption = $label; Value = $value }
}

$watchdogStatus = New-StatusRow -Top 28 -Left 20 -Caption 'Watchdog'
$helperStatus = New-StatusRow -Top 56 -Left 20 -Caption 'Hotkeys'
$dittoStatus = New-StatusRow -Top 28 -Left 226 -Caption 'Ditto'
$dittoStatus.Caption.Size = New-Object System.Drawing.Size(44, 22)
$dittoStatus.Value.Location = New-Object System.Drawing.Point(300, 28)
$dittoStatus.Value.Size = New-Object System.Drawing.Size(72, 22)
$watchdogValue = $watchdogStatus.Value
$helperValue = $helperStatus.Value
$dittoValue = $dittoStatus.Value

$idleHintBox = New-Card -Left 24 -Top 846 -Width 420 -Height 36 -Back ([System.Drawing.Color]::FromArgb(14, 21, 34)) -Accent $purple
$idleHint = New-Object System.Windows.Forms.Label
$idleHint.ForeColor = $muted
$idleHint.Location = New-Object System.Drawing.Point(20, 9)
$idleHint.Size = New-Object System.Drawing.Size(376, 18)
$idleHintBox.Controls.Add($idleHint)

function New-Button {
    param([string]$CaptionText, [int]$Left, [System.Drawing.Color]$Color, [int]$Width = 116)
    $button = New-Object System.Windows.Forms.Panel
    $button.BackColor = [System.Drawing.Color]::FromArgb(16, 24, 38)
    $button.Size = New-Object System.Drawing.Size($Width, 42)
    $button.Location = New-Object System.Drawing.Point($Left, 900)
    $button.Cursor = 'Hand'
    Add-RoundedBorder -Control $button -Radius 14 -BorderColor $neonPurpleSoft

    $caption = New-Object System.Windows.Forms.Label
    $caption.Text = $CaptionText
    $caption.ForeColor = $text
    $caption.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
    $caption.TextAlign = 'MiddleCenter'
    $caption.Dock = 'Fill'
    $caption.Cursor = 'Hand'
    $button.Controls.Add($caption)

    $accent = New-Object System.Windows.Forms.Panel
    $accent.BackColor = $Color
    $accent.Dock = 'Bottom'
    $accent.Height = 3
    $button.Controls.Add($accent)

    $form.Controls.Add($button)
    return $button
}

function Register-ButtonClick {
    param($Button, [scriptblock]$Handler)
    $Button.Add_Click($Handler)
    foreach ($child in $Button.Controls) {
        $child.Add_Click($Handler)
    }
}

$restartButton = New-Button -CaptionText 'Restart' -Left 24 -Color $blue -Width 96
$deleteShotButton = New-Button -CaptionText 'Delete shot' -Left 132 -Color $pink -Width 96
$cancelButton = New-Button -CaptionText 'Cancel timer' -Left 240 -Color $yellow -Width 96
$closeButton = New-Button -CaptionText 'Close' -Left 348 -Color $purple -Width 96

Register-ButtonClick -Button $restartButton -Handler {
    Restart-ClipDeckWatchdog
    Start-Sleep -Milliseconds 500
    Update-Status
}

Register-ButtonClick -Button $cancelButton -Handler {
    Cancel-ClipDeckShutdown
    [System.Windows.Forms.MessageBox]::Show('Scheduled shutdown cancelled.', 'ClipDeck', 'OK', 'Information') | Out-Null
}

Register-ButtonClick -Button $deleteShotButton -Handler {
    Remove-LatestClipDeckScreenshot
}

Register-ButtonClick -Button $closeButton -Handler {
    $form.Close()
}

function Set-StateText {
    param($Label, $Dot, [bool]$Ok, [string]$OkText, [string]$FailText)
    if ($Ok) {
        $Label.Text = $OkText
        $Label.ForeColor = $green
        if ($Dot) { $Dot.BackColor = $green }
    } else {
        $Label.Text = $FailText
        $Label.ForeColor = $pink
        if ($Dot) { $Dot.BackColor = $pink }
    }
}

function Update-Status {
    $watchdog = @(Get-ProcessByCommandLine -Needle 'clipboard-hotkeys-watchdog.ps1')
    $helper = @(Get-ProcessByCommandLine -Needle 'clipboard-second-paste.ps1')
    $ditto = Get-Process -Name Ditto -ErrorAction SilentlyContinue

    Set-StateText -Label $watchdogValue -Dot $watchdogStatus.Dot -Ok ($watchdog.Count -gt 0) -OkText 'running' -FailText 'stopped'
    Set-StateText -Label $helperValue -Dot $helperStatus.Dot -Ok ($helper.Count -gt 0) -OkText 'active' -FailText 'not active'
    Set-StateText -Label $dittoValue -Dot $dittoStatus.Dot -Ok ([bool]$ditto) -OkText 'running' -FailText 'stopped'
    $settings = Get-ClipDeckSettings
    if ((Get-ToggleChecked -Toggle $idleToggle) -ne [bool]$settings.idleShutdownEnabled) {
        Set-ToggleChecked -Toggle $idleToggle -Checked ([bool]$settings.idleShutdownEnabled)
    }
    $settingsHours = [int]$settings.idleShutdownHours
    if ($settingsHours -lt 1) { $settingsHours = 1 }
    if ($settingsHours -gt 5) { $settingsHours = 5 }
    Set-HoursUi -Hours $settingsHours
    if ((Get-ToggleChecked -Toggle $screenshotToggle) -ne [bool]$settings.screenshotSaveEnabled) {
        Set-ToggleChecked -Toggle $screenshotToggle -Checked ([bool]$settings.screenshotSaveEnabled)
    }
    $currentHotkeyLabel.Text = (Get-PasteCurrentHotkey).Replace('+', ' + ')
    $secondHotkeyLabel.Text = (Get-PasteSecondHotkey).Replace('+', ' + ')
    $thirdHotkeyLabel.Text = (Get-PasteThirdHotkey).Replace('+', ' + ')
    $screenshotHotkeyLabel.Text = (Get-ScreenshotHotkey).Replace('+', ' + ')
    $ocrHotkeyLabel.Text = (Get-OcrHotkey).Replace('+', ' + ')
    $recordHotkeyLabel.Text = (Get-RecordHotkey).Replace('+', ' + ')
    $rulerHotkeyLabel.Text = (Get-RulerHotkey).Replace('+', ' + ')
    $storagePathLabel.Text = Get-StorageRoot
    $androidPathLabel.Text = if ([string]::IsNullOrWhiteSpace((Get-AndroidMirrorRoot))) { 'Choose Android/sync folder' } else { Get-AndroidMirrorRoot }
    if ((Get-ToggleChecked -Toggle $androidToggle) -ne (Get-AndroidMirrorEnabled)) {
        Set-ToggleChecked -Toggle $androidToggle -Checked (Get-AndroidMirrorEnabled)
    }
    $retentionValueLabel.Text = ('{0} days' -f (Get-RetentionDays))
    if ($formatBox.SelectedItem -ne (Get-RecordingFormat)) { $formatBox.SelectedItem = Get-RecordingFormat }
    if ($fpsBox.SelectedItem -ne [string](Get-RecordingFps)) { $fpsBox.SelectedItem = [string](Get-RecordingFps) }
    if ((Get-ToggleChecked -Toggle $cursorToggle) -ne (Get-RecordingCaptureCursor)) {
        Set-ToggleChecked -Toggle $cursorToggle -Checked (Get-RecordingCaptureCursor)
    }
    $ffmpegStatus = if (Test-ClipDeckTool -Name 'ffmpeg.exe') { 'ffmpeg ok' } else { 'ffmpeg missing' }
    $ocrStatus = if (Test-ClipDeckTool -Name 'tesseract.exe') { 'ocr ok' } else { 'ocr missing dependency' }
    $dependencyLabel.Text = ($ffmpegStatus + ' | ' + $ocrStatus)
    $dependencyLabel.ForeColor = if ($ocrStatus -like '*missing*') { $yellow } else { $green }
    $androidState = if ((Get-AndroidMirrorEnabled) -and -not [string]::IsNullOrWhiteSpace((Get-AndroidMirrorRoot))) { 'android mirror on' } else { 'android mirror off' }
    $idleHint.Text = ('Idle {0}h | shot {1} | record {2} {3}fps | {4}' -f $settingsHours, (Get-ScreenshotHotkey), (Get-RecordingFormat), (Get-RecordingFps), $androidState)

    $form.Text = 'ClipDeck'
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2000
$timer.Add_Tick({ Update-Status })
$timer.Start()

$form.Add_Shown({ Update-Status })
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::Run($form)
