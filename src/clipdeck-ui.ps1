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
    if (-not (Test-Path -LiteralPath $settingsPath)) {
        @{
            idleShutdownEnabled = $false
            idleShutdownHours = 2
            screenshotSaveEnabled = $false
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
        if ($null -eq $settings.PSObject.Properties['screenshotSaveEnabled']) {
            $settings | Add-Member -NotePropertyName screenshotSaveEnabled -NotePropertyValue $false
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
            screenshotSaveEnabled = $false
        } |
            ConvertTo-Json -Depth 3 |
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
        }
    }
}

function Save-ClipDeckSettings {
    param(
        [bool]$IdleShutdownEnabled,
        [int]$IdleShutdownHours,
        [bool]$ScreenshotSaveEnabled
    )
    if ($IdleShutdownHours -lt 1) { $IdleShutdownHours = 1 }
    if ($IdleShutdownHours -gt 5) { $IdleShutdownHours = 5 }
    @{
        idleShutdownEnabled = $IdleShutdownEnabled
        idleShutdownHours = $IdleShutdownHours
        screenshotSaveEnabled = $ScreenshotSaveEnabled
    } |
        ConvertTo-Json -Depth 3 |
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
    $desktop = [Environment]::GetFolderPath('Desktop')
    $latest = Get-ChildItem -LiteralPath $desktop -Filter 'ClipDeck Screenshot *.png' -File -ErrorAction SilentlyContinue |
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

Start-ClipDeckWatchdog

$bg = [System.Drawing.Color]::FromArgb(11, 17, 29)
$surface = [System.Drawing.Color]::FromArgb(17, 25, 40)
$surface2 = [System.Drawing.Color]::FromArgb(22, 32, 49)
$line = [System.Drawing.Color]::FromArgb(48, 60, 82)
$text = [System.Drawing.Color]::FromArgb(244, 247, 252)
$muted = [System.Drawing.Color]::FromArgb(145, 158, 180)
$green = [System.Drawing.Color]::FromArgb(52, 211, 153)
$pink = [System.Drawing.Color]::FromArgb(255, 73, 143)
$blue = [System.Drawing.Color]::FromArgb(76, 181, 255)
$yellow = [System.Drawing.Color]::FromArgb(248, 196, 72)

$form = New-Object System.Windows.Forms.Form
$form.Text = 'ClipDeck'
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(430, 438)
$form.MinimumSize = New-Object System.Drawing.Size(446, 477)
$form.MaximumSize = New-Object System.Drawing.Size(446, 477)
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.BackColor = $bg
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
if (Test-Path -LiteralPath $iconPath) {
    $form.Icon = New-Object System.Drawing.Icon($iconPath)
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
    param([int]$Left, [int]$Top, [int]$Width, [int]$Height)
    $card = New-Object System.Windows.Forms.Panel
    $card.BackColor = $surface
    $card.Location = New-Object System.Drawing.Point($Left, $Top)
    $card.Size = New-Object System.Drawing.Size($Width, $Height)
    $form.Controls.Add($card)
    return $card
}

$logo = New-Object System.Windows.Forms.PictureBox
$logo.Location = New-Object System.Drawing.Point(24, 24)
$logo.Size = New-Object System.Drawing.Size(44, 44)
$logo.SizeMode = 'StretchImage'
if (Test-Path -LiteralPath $iconPath) {
    $logo.Image = ([System.Drawing.Icon]::ExtractAssociatedIcon($iconPath)).ToBitmap()
}
$form.Controls.Add($logo)

New-Text -Text 'ClipDeck' -Left 82 -Top 23 -Width 170 -Height 32 -Color $text -Font (New-Object System.Drawing.Font('Segoe UI Semibold', 19)) | Out-Null
New-Text -Text 'Clipboard launcher and safety guard' -Left 84 -Top 58 -Width 220 -Height 22 -Color $muted -Font (New-Object System.Drawing.Font('Segoe UI', 9)) | Out-Null

$guardLabel = New-Object System.Windows.Forms.Label
$guardLabel.Text = 'Idle guard'
$guardLabel.ForeColor = $muted
$guardLabel.Location = New-Object System.Drawing.Point(298, 25)
$guardLabel.Size = New-Object System.Drawing.Size(72, 20)
$form.Controls.Add($guardLabel)

$idleCheckbox = New-Object System.Windows.Forms.CheckBox
$idleCheckbox.Text = ''
$idleCheckbox.BackColor = $bg
$idleCheckbox.Location = New-Object System.Drawing.Point(379, 25)
$idleCheckbox.Size = New-Object System.Drawing.Size(18, 18)
$idleCheckbox.Checked = Get-IdleShutdownEnabled
$form.Controls.Add($idleCheckbox)

$hoursBox = New-Object System.Windows.Forms.NumericUpDown
$hoursBox.Minimum = 1
$hoursBox.Maximum = 5
$hoursBox.Increment = 1
$hoursBox.Value = Get-IdleShutdownHours
$hoursBox.Location = New-Object System.Drawing.Point(303, 52)
$hoursBox.Size = New-Object System.Drawing.Size(54, 23)
$hoursBox.BackColor = $surface
$hoursBox.ForeColor = $text
$hoursBox.BorderStyle = 'FixedSingle'
$form.Controls.Add($hoursBox)

$hoursLabel = New-Object System.Windows.Forms.Label
$hoursLabel.Text = 'hours'
$hoursLabel.ForeColor = $muted
$hoursLabel.Location = New-Object System.Drawing.Point(363, 54)
$hoursLabel.Size = New-Object System.Drawing.Size(48, 18)
$form.Controls.Add($hoursLabel)

$screenshotLabel = New-Object System.Windows.Forms.Label
$screenshotLabel.Text = 'Shot save'
$screenshotLabel.ForeColor = $muted
$screenshotLabel.Location = New-Object System.Drawing.Point(298, 76)
$screenshotLabel.Size = New-Object System.Drawing.Size(72, 18)
$form.Controls.Add($screenshotLabel)

$screenshotCheckbox = New-Object System.Windows.Forms.CheckBox
$screenshotCheckbox.Text = ''
$screenshotCheckbox.BackColor = $bg
$screenshotCheckbox.Location = New-Object System.Drawing.Point(379, 76)
$screenshotCheckbox.Size = New-Object System.Drawing.Size(18, 18)
$screenshotCheckbox.Checked = Get-ScreenshotSaveEnabled
$form.Controls.Add($screenshotCheckbox)

$hotkeysBox = New-Card -Left 24 -Top 96 -Width 382 -Height 174
$hotkeysHeader = New-Object System.Windows.Forms.Label
$hotkeysHeader.Text = 'HOTKEY PASTE'
$hotkeysHeader.ForeColor = $muted
$hotkeysHeader.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8)
$hotkeysHeader.Location = New-Object System.Drawing.Point(18, 14)
$hotkeysHeader.Size = New-Object System.Drawing.Size(140, 18)
$hotkeysBox.Controls.Add($hotkeysHeader)

function New-HotkeyRow {
    param([int]$Top, [string]$KeyText, [string]$CaptionText, [string]$HintText)
    $key = New-Object System.Windows.Forms.Label
    $key.Text = $KeyText
    $key.ForeColor = $text
    $key.BackColor = $surface2
    $key.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
    $key.TextAlign = 'MiddleCenter'
    $key.Location = New-Object System.Drawing.Point(18, $Top)
    $key.Size = New-Object System.Drawing.Size(76, 30)
    $hotkeysBox.Controls.Add($key)

    $caption = New-Object System.Windows.Forms.Label
    $caption.Text = $CaptionText
    $caption.ForeColor = $text
    $caption.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
    $caption.Location = New-Object System.Drawing.Point(108, ($Top - 2))
    $caption.Size = New-Object System.Drawing.Size(230, 18)
    $hotkeysBox.Controls.Add($caption)

    $hint = New-Object System.Windows.Forms.Label
    $hint.Text = $HintText
    $hint.ForeColor = $muted
    $hint.Location = New-Object System.Drawing.Point(108, ($Top + 16))
    $hint.Size = New-Object System.Drawing.Size(245, 18)
    $hotkeysBox.Controls.Add($hint)
}

New-HotkeyRow -Top 42 -KeyText 'Ctrl + 1' -CaptionText 'Paste current clipboard' -HintText 'fast insert from the active clipboard slot'
New-HotkeyRow -Top 86 -KeyText 'Ctrl + 2' -CaptionText 'Paste second saved clip' -HintText 'quick insert from Ditto history position 2'
New-HotkeyRow -Top 130 -KeyText 'Ctrl + 3' -CaptionText 'Paste third saved clip' -HintText 'quick insert from Ditto history position 3'

$statusBox = New-Card -Left 24 -Top 286 -Width 382 -Height 76
$statusHeader = New-Object System.Windows.Forms.Label
$statusHeader.Text = 'SYSTEM'
$statusHeader.ForeColor = $muted
$statusHeader.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8)
$statusHeader.Location = New-Object System.Drawing.Point(18, 10)
$statusHeader.Size = New-Object System.Drawing.Size(120, 16)
$statusBox.Controls.Add($statusHeader)

function New-StatusRow {
    param([int]$Top, [int]$Left, [string]$Caption)
    $dot = New-Object System.Windows.Forms.Panel
    $dot.BackColor = $line
    $dot.Location = New-Object System.Drawing.Point($Left, ($Top + 6))
    $dot.Size = New-Object System.Drawing.Size(8, 8)
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
$helperStatus = New-StatusRow -Top 48 -Left 20 -Caption 'Hotkeys'
$dittoStatus = New-StatusRow -Top 28 -Left 212 -Caption 'Ditto'
$dittoStatus.Caption.Size = New-Object System.Drawing.Size(44, 22)
$dittoStatus.Value.Location = New-Object System.Drawing.Point(284, 28)
$dittoStatus.Value.Size = New-Object System.Drawing.Size(72, 22)
$watchdogValue = $watchdogStatus.Value
$helperValue = $helperStatus.Value
$dittoValue = $dittoStatus.Value

$idleHintBox = New-Card -Left 24 -Top 376 -Width 382 -Height 24
$idleHint = New-Object System.Windows.Forms.Label
$idleHint.ForeColor = $muted
$idleHint.Location = New-Object System.Drawing.Point(18, 4)
$idleHint.Size = New-Object System.Drawing.Size(345, 18)
$idleHintBox.Controls.Add($idleHint)

function New-Button {
    param([string]$CaptionText, [int]$Left, [System.Drawing.Color]$Color, [int]$Width = 116)
    $button = New-Object System.Windows.Forms.Panel
    $button.BackColor = [System.Drawing.Color]::FromArgb(13, 20, 34)
    $button.Size = New-Object System.Drawing.Size($Width, 34)
    $button.Location = New-Object System.Drawing.Point($Left, 404)
    $button.Cursor = 'Hand'

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
    $accent.Height = 2
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

$restartButton = New-Button -CaptionText 'Restart' -Left 24 -Color $blue -Width 86
$deleteShotButton = New-Button -CaptionText 'Delete shot' -Left 122 -Color $pink -Width 86
$cancelButton = New-Button -CaptionText 'Cancel timer' -Left 220 -Color $yellow -Width 86
$closeButton = New-Button -CaptionText 'Close' -Left 318 -Color $line -Width 88

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

$idleCheckbox.Add_CheckedChanged({
    Set-IdleShutdownEnabled -Enabled $idleCheckbox.Checked
})

$hoursBox.Add_ValueChanged({
    Set-IdleShutdownHours -Hours ([int]$hoursBox.Value)
})

$screenshotCheckbox.Add_CheckedChanged({
    Set-ScreenshotSaveEnabled -Enabled $screenshotCheckbox.Checked
})

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
    if ($idleCheckbox.Checked -ne [bool]$settings.idleShutdownEnabled) {
        $idleCheckbox.Checked = [bool]$settings.idleShutdownEnabled
    }
    $settingsHours = [int]$settings.idleShutdownHours
    if ($settingsHours -lt 1) { $settingsHours = 1 }
    if ($settingsHours -gt 5) { $settingsHours = 5 }
    if ([int]$hoursBox.Value -ne $settingsHours) {
        $hoursBox.Value = $settingsHours
    }
    if ($screenshotCheckbox.Checked -ne [bool]$settings.screenshotSaveEnabled) {
        $screenshotCheckbox.Checked = [bool]$settings.screenshotSaveEnabled
    }
    $idleHint.Text = ('Idle: 10m -> shutdown {0}h. Region shot: Win+Shift+D.' -f $settingsHours)

    $form.Text = 'ClipDeck'
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2000
$timer.Add_Tick({ Update-Status })
$timer.Start()

$form.Add_Shown({ Update-Status })
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::Run($form)
