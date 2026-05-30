# ClipDeck

ClipDeck is a small Windows 10/11 utility for fast clipboard-history pasting and an optional idle shutdown guard.

Version 2.0 adds the new ClipDeck UI, a desktop shortcut, watchdog-based autostart, and `Ctrl+3` for pasting the third saved clipboard-history item.

## Download

Download the installer from GitHub Releases:

[ClipDeckSetup.exe](https://github.com/maksimjhbf/clipboard-second-paste/releases/latest)

Run it once. ClipDeck configures Ditto, starts the hotkey watchdog, creates a desktop shortcut, and keeps the hotkeys working after reboot.

## Hotkeys

| Hotkey | Action |
| --- | --- |
| `Ctrl+V` | Normal Windows paste, unchanged |
| `Ctrl+1` | Paste the current clipboard item |
| `Ctrl+2` | Paste the second saved clipboard-history item |
| `Ctrl+3` | Paste the third saved clipboard-history item |
| `Ctrl+B` | Paste the second saved clipboard-history item |
| `Win+Shift+D` | Select a screen region and save it as a desktop PNG, when enabled |

`Ctrl+B` overrides the usual Bold shortcut while ClipDeck is running.

## What You Get

- A compact ClipDeck window with health status for the watchdog, hotkeys, and Ditto.
- `Ctrl+1`, `Ctrl+2`, and `Ctrl+3` for fast clipboard insertion.
- Optional idle shutdown guard: after 10 minutes without cursor movement, ClipDeck can start a shutdown countdown.
- Shutdown countdown duration is configurable from 1 to 5 hours.
- Optional desktop screenshot hotkey: `Win+Shift+D` lets you select a screen region and saves it as a PNG on the desktop without using the clipboard.
- `Delete shot` removes the newest `ClipDeck Screenshot *.png` from the desktop after confirmation.
- Current-user install; no admin rights required for ClipDeck itself.
- A desktop shortcut and Start Menu shortcut named `ClipDeck`.
- Autostart through both a current-user Run entry and a scheduled task.

## How It Works

ClipDeck uses [Ditto](https://ditto-cp.sourceforge.io/) as the clipboard-history backend. Ditto stores clipboard history, while ClipDeck owns the visible hotkeys and triggers Ditto's hidden shortcuts for history positions 2 and 3.

The installer creates:

- `%APPDATA%\ClipDeck\clipboard-second-paste.ps1`
- `%APPDATA%\ClipDeck\clipboard-hotkeys-watchdog.ps1`
- `%APPDATA%\ClipDeck\clipdeck-ui.ps1`
- `%APPDATA%\ClipDeck\ClipDeck.ico`
- a current-user startup entry named `ClipDeckWatchdog`
- a current-user Scheduled Task named `ClipDeck Watchdog`
- a desktop shortcut named `ClipDeck`
- a Start Menu shortcut named `ClipDeck`

## Manual Install From Source

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Lang en
```

If Ditto is not installed, the script tries to install it with `winget`.

## Uninstall

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1 -Lang en
```

Ditto is left installed because it may contain the user's clipboard history.

## Build The Installer

Install Inno Setup 6, then run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-installer.ps1
```

The output is written to `dist\ClipDeckSetup.exe`.
