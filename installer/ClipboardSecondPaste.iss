#define AppName "ClipDeck"
#define AppVersion "2.0.0"
#define AppPublisher "escfrompoor-cpu"

[Setup]
AppId={{68E77898-2B8E-4DAD-86F7-9751F8285E39}}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={userappdata}\ClipDeckInstaller
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=ClipDeckSetup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName={#AppName}
SetupIconFile=..\assets\ClipDeck.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Files]
Source: "..\src\clipboard-second-paste.ps1"; DestDir: "{app}\src"; Flags: ignoreversion
Source: "..\src\clipboard-hotkeys-watchdog.ps1"; DestDir: "{app}\src"; Flags: ignoreversion
Source: "..\src\clipdeck-ui.ps1"; DestDir: "{app}\src"; Flags: ignoreversion
Source: "..\assets\ClipDeck.ico"; DestDir: "{app}\assets"; Flags: ignoreversion
Source: "..\assets\tools\*"; DestDir: "{app}\assets\tools"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\scripts\install.ps1"; DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "..\scripts\uninstall.ps1"; DestDir: "{app}\scripts"; Flags: ignoreversion

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\scripts\install.ps1"" -SourceRoot ""{app}"" -Lang ""{language}"""; Flags: runhidden waituntilterminated

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\scripts\uninstall.ps1"" -Lang ""{language}"""; Flags: runhidden waituntilterminated; RunOnceId: "RemoveClipDeck"
