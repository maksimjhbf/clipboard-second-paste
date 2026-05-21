# Clipboard Second Paste

Windows 10/11 hotkeys for faster clipboard-history pasting.

## Hotkeys

- `Ctrl+V`: normal Windows paste, unchanged.
- `Ctrl+1`: paste the current clipboard item, same as `Ctrl+V`.
- `Ctrl+2`: paste the second item from Ditto clipboard history.
- `Ctrl+B`: paste the second item from Ditto clipboard history.

`Ctrl+B` overrides the usual Bold shortcut while this helper is running.

## Install

Recommended: download `ClipboardSecondPasteSetup.exe` from GitHub Releases and run it.

Manual install from source:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Lang en
```

The installer uses Ditto as the clipboard-history backend. If Ditto is not installed, the script tries to install it with `winget`.

## Uninstall

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1 -Lang en
```

Ditto is left installed because it may contain the user's clipboard history.

## How It Works

Ditto stores clipboard history and owns a hidden internal hotkey for history position 2. This helper owns the visible hotkeys and sends the hidden Ditto hotkey when the user presses `Ctrl+2` or `Ctrl+B`.

The installer creates:

- `%APPDATA%\ClipboardSecondPaste\clipboard-second-paste.ps1`
- `%APPDATA%\ClipboardSecondPaste\start-clipboard-hotkeys.ps1`
- a current-user startup entry
- a current-user Scheduled Task named `Clipboard Second Paste`

No admin privileges are required for the helper itself.

## Build The EXE Installer

Install Inno Setup 6, then run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-installer.ps1
```

The output is written to `dist\ClipboardSecondPasteSetup.exe`.

---

# Clipboard Second Paste RU

Горячие клавиши для Windows 10/11, чтобы быстрее вставлять элементы из истории буфера обмена.

## Горячие клавиши

- `Ctrl+V`: обычная вставка Windows, не меняется.
- `Ctrl+1`: вставить текущий элемент буфера, дубль `Ctrl+V`.
- `Ctrl+2`: вставить второй элемент из истории буфера Ditto.
- `Ctrl+B`: вставить второй элемент из истории буфера Ditto.

`Ctrl+B` перехватывает стандартную команду жирного текста, пока helper запущен.

## Установка

Рекомендуемый вариант: скачать `ClipboardSecondPasteSetup.exe` из GitHub Releases и запустить.

Ручная установка из исходников:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Lang ru
```

Установщик использует Ditto как движок истории буфера обмена. Если Ditto не установлен, скрипт попробует установить его через `winget`.

## Удаление

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1 -Lang ru
```

Ditto остаётся установленным, потому что там может быть история буфера пользователя.

## Как Это Работает

Ditto хранит историю буфера и держит скрытую внутреннюю горячую клавишу для второго элемента истории. Helper держит видимые горячие клавиши и вызывает скрытую клавишу Ditto, когда пользователь нажимает `Ctrl+2` или `Ctrl+B`.

Установщик создаёт:

- `%APPDATA%\ClipboardSecondPaste\clipboard-second-paste.ps1`
- `%APPDATA%\ClipboardSecondPaste\start-clipboard-hotkeys.ps1`
- запись автозагрузки текущего пользователя
- задачу планировщика `Clipboard Second Paste`

Для самого helper-а права администратора не нужны.
