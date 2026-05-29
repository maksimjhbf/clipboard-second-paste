$ErrorActionPreference = 'Stop'

$iscc = Get-Command iscc.exe -ErrorAction SilentlyContinue
if (-not $iscc) {
    $candidates = @(
        'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
        'C:\Program Files\Inno Setup 6\ISCC.exe',
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
    )
    $iscc = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if (-not $iscc) {
    throw 'ISCC.exe was not found. Install Inno Setup 6, then rerun this script.'
}

$root = Split-Path -Parent $PSScriptRoot
$iss = Join-Path $root 'installer\ClipboardSecondPaste.iss'
& $iscc $iss

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$zip = Join-Path $dist 'ClipDeck-2.0.0-source.zip'
if (Test-Path -LiteralPath $zip) {
    Remove-Item -LiteralPath $zip -Force
}

$items = @(
    (Join-Path $root 'README.md'),
    (Join-Path $root 'LICENSE'),
    (Join-Path $root 'src'),
    (Join-Path $root 'scripts'),
    (Join-Path $root 'installer'),
    (Join-Path $root 'assets')
)
Compress-Archive -LiteralPath $items -DestinationPath $zip -Force
Write-Host "Built $zip"
