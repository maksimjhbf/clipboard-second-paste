# Second Paste for Windows

Paste your current or previous clipboard item without opening clipboard history.

Second Paste for Windows adds three practical hotkeys to Windows 10/11:

- `Ctrl+1` pastes the current clipboard item, just like `Ctrl+V`.
- `Ctrl+2` pastes the previous clipboard-history item.
- `Ctrl+B` also pastes the previous clipboard-history item for fast one-hand use.

It is useful when you constantly copy two things back and forth: prompts and answers, names and links, emails and codes, IDs and notes, text snippets while editing, or repeated form fields.

## Download

Download the installer from GitHub Releases:

[ClipboardSecondPasteSetup.exe](https://github.com/maksimjhbf/clipboard-second-paste/releases/latest)

Run it once. The hotkeys start automatically and keep working after reboot.

## What You Get

- Faster pasting of the previous clipboard item.
- No need to open `Win+V` clipboard history.
- `Ctrl+V` keeps working normally.
- `Ctrl+1` becomes a predictable duplicate of `Ctrl+V`.
- `Ctrl+2` and `Ctrl+B` paste the second clipboard-history item.
- Works on Windows 10 and Windows 11.
- English and Russian installer UI.
- Current-user install; no admin rights required for the helper.

`Ctrl+B` overrides the usual Bold shortcut while this helper is running.

## Hotkeys

| Hotkey | Action |
| --- | --- |
| `Ctrl+V` | Normal Windows paste, unchanged |
| `Ctrl+1` | Paste the current clipboard item |
| `Ctrl+2` | Paste the previous item from clipboard history |
| `Ctrl+B` | Paste the previous item from clipboard history |

## How It Works

Second Paste uses [Ditto](https://ditto-cp.sourceforge.io/) as the clipboard-history backend. Ditto stores clipboard history, while this helper owns the visible hotkeys and triggers Ditto's hidden shortcut for the second history item.

The installer creates:

- `%APPDATA%\ClipboardSecondPaste\clipboard-second-paste.ps1`
- `%APPDATA%\ClipboardSecondPaste\start-clipboard-hotkeys.ps1`
- a current-user startup entry
- a current-user Scheduled Task named `Clipboard Second Paste`

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

The output is written to `dist\ClipboardSecondPasteSetup.exe`.

---

# Second Paste for Windows на русском

Вставляйте текущий или предыдущий элемент буфера обмена без открытия истории буфера.

Second Paste for Windows добавляет три практичные горячие клавиши для Windows 10/11:

- `Ctrl+1` вставляет текущий элемент буфера, как `Ctrl+V`.
- `Ctrl+2` вставляет предыдущий элемент из истории буфера.
- `Ctrl+B` тоже вставляет предыдущий элемент из истории буфера, чтобы было удобно нажимать одной рукой.

Это удобно, когда вы постоянно копируете туда-сюда две вещи: промпты и ответы, имена и ссылки, email и коды, ID и заметки, текстовые фрагменты при редактировании или повторяющиеся поля в формах.

## Скачать

Скачайте установщик из GitHub Releases:

[ClipboardSecondPasteSetup.exe](https://github.com/maksimjhbf/clipboard-second-paste/releases/latest)

Запустите один раз. Горячие клавиши начнут работать автоматически и сохранятся после перезагрузки.

## Что вы получаете

- Быструю вставку предыдущего элемента буфера обмена.
- Не нужно открывать историю через `Win+V`.
- `Ctrl+V` продолжает работать как обычно.
- `Ctrl+1` становится понятным дублем `Ctrl+V`.
- `Ctrl+2` и `Ctrl+B` вставляют второй элемент из истории буфера.
- Работает на Windows 10 и Windows 11.
- Установщик на английском и русском.
- Установка для текущего пользователя; права администратора для helper не нужны.

`Ctrl+B` перехватывает стандартную команду жирного текста, пока helper запущен.

## Горячие клавиши

| Клавиша | Действие |
| --- | --- |
| `Ctrl+V` | Обычная вставка Windows, не меняется |
| `Ctrl+1` | Вставить текущий элемент буфера |
| `Ctrl+2` | Вставить предыдущий элемент из истории буфера |
| `Ctrl+B` | Вставить предыдущий элемент из истории буфера |

## Как это работает

Second Paste использует [Ditto](https://ditto-cp.sourceforge.io/) как движок истории буфера обмена. Ditto хранит историю, а этот helper держит видимые горячие клавиши и вызывает скрытую клавишу Ditto для второго элемента истории.

Установщик создаёт:

- `%APPDATA%\ClipboardSecondPaste\clipboard-second-paste.ps1`
- `%APPDATA%\ClipboardSecondPaste\start-clipboard-hotkeys.ps1`
- запись автозагрузки текущего пользователя
- задачу планировщика `Clipboard Second Paste`

## Ручная установка из исходников

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Lang ru
```

Если Ditto не установлен, скрипт попробует установить его через `winget`.

## Удаление

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1 -Lang ru
```

Ditto остаётся установленным, потому что там может быть история буфера пользователя.
