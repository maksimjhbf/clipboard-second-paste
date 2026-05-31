Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$logPath = Join-Path $env:APPDATA 'ClipDeck\clipboard-hotkeys.log'
$settingsPath = Join-Path $env:APPDATA 'ClipDeck\clipdeck-settings.json'
$appRoot = Join-Path $env:APPDATA 'ClipDeck'
$toolsRoot = Join-Path $appRoot 'tools'
"$(Get-Date -Format o) starting clipboard hotkey helper pid=$PID" | Add-Content -LiteralPath $logPath

$dittoPath = 'C:\Program Files\Ditto\Ditto.exe'
if (-not (Get-Process -Name Ditto -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $dittoPath)) {
    Start-Process -FilePath $dittoPath
    Start-Sleep -Seconds 2
}

Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Threading;
using System.Windows.Forms;
using System.Runtime.InteropServices;
using System.IO;
using System.Text.RegularExpressions;
using System.Diagnostics;
using System.Text;

public class ClipboardHotkeyWindow : Form
{
    private const int WM_HOTKEY = 0x0312;
    private const int MOD_ALT = 0x0001;
    private const int MOD_CONTROL = 0x0002;
    private const int MOD_SHIFT = 0x0004;
    private const int MOD_WIN = 0x0008;
    private const int KEYEVENTF_KEYUP = 0x0002;
    private const int VK_CONTROL = 0x11;
    private const int VK_ALT = 0x12;
    private const int VK_SHIFT = 0x10;
    private const int VK_F14 = 0x7D;
    private const int VK_F15 = 0x7E;
    private const int VK_V = 0x56;
    private const int VK_D = 0x44;
    public static string LogPath = null;
    public static string SettingsPath = null;
    public static string AppRoot = null;
    public static string ToolsRoot = null;
    private static RulerOverlayForm Ruler = null;

    [DllImport("user32.dll", SetLastError=true)]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, int fsModifiers, int vk);

    [DllImport("user32.dll", SetLastError=true)]
    private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    [DllImport("user32.dll", SetLastError=true)]
    private static extern void keybd_event(byte bVk, byte bScan, int dwFlags, UIntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    private static extern uint GetClipboardSequenceNumber();

    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int vKey);

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        RegisterConfiguredHotKey(this.Handle, 1, "pasteCurrentHotkey", "Ctrl+1");
        RegisterConfiguredHotKey(this.Handle, 2, "pasteSecondHotkey", "Ctrl+2");
        RegisterConfiguredHotKey(this.Handle, 3, "pasteThirdHotkey", "Ctrl+3");
        RegisterOptionalHotKey(this.Handle, 4, MOD_CONTROL, 0x42, "Ctrl+B");
        RegisterConfiguredHotKey(this.Handle, 5, "screenshotHotkey", "Win+Shift+D");
        RegisterConfiguredHotKey(this.Handle, 6, "ocrHotkey", "Win+Shift+Z");
        RegisterConfiguredHotKey(this.Handle, 7, "recordHotkey", "Win+Shift+R", "Ctrl+Alt+R");
        RegisterConfiguredHotKey(this.Handle, 8, "rulerHotkey", "Alt+Shift+W");
        Log("hotkeys registered");
    }

    protected override void OnHandleDestroyed(EventArgs e)
    {
        UnregisterHotKey(this.Handle, 1);
        UnregisterHotKey(this.Handle, 2);
        UnregisterHotKey(this.Handle, 3);
        UnregisterHotKey(this.Handle, 4);
        UnregisterHotKey(this.Handle, 5);
        UnregisterHotKey(this.Handle, 6);
        UnregisterHotKey(this.Handle, 7);
        UnregisterHotKey(this.Handle, 8);
        base.OnHandleDestroyed(e);
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == WM_HOTKEY)
        {
            int id = m.WParam.ToInt32();
            if (id == 1)
            {
                SendCtrlV();
            }
            else if (id == 2 || id == 4)
            {
                PasteDittoPosition2();
            }
            else if (id == 3)
            {
                PasteDittoPosition3();
            }
            else if (id == 5)
            {
                StartRegionCapture(CaptureMode.Screenshot);
            }
            else if (id == 6)
            {
                StartRegionCapture(CaptureMode.Ocr);
            }
            else if (id == 7)
            {
                StartRegionCapture(CaptureMode.Record);
            }
            else if (id == 8)
            {
                ToggleRuler();
            }
            return;
        }
        base.WndProc(ref m);
    }

    private static void PasteDittoPosition2()
    {
        uint sequenceBefore = GetClipboardSequenceNumber();
        SendDittoPosition(VK_F14);
        WaitForClipboardChange(sequenceBefore, 450);
        WaitForCtrlRelease(700);
        SendCtrlV();
    }

    private static void PasteDittoPosition3()
    {
        uint sequenceBefore = GetClipboardSequenceNumber();
        SendDittoPosition(VK_F15);
        WaitForClipboardChange(sequenceBefore, 450);
        WaitForCtrlRelease(700);
        SendCtrlV();
    }

    private static void WaitForClipboardChange(uint sequenceBefore, int timeoutMs)
    {
        int waited = 0;
        while (waited < timeoutMs)
        {
            Thread.Sleep(20);
            waited += 20;
            if (GetClipboardSequenceNumber() != sequenceBefore)
            {
                Thread.Sleep(30);
                return;
            }
        }
    }

    private static void SendDittoPosition(int functionKey)
    {
        PressDown(VK_CONTROL);
        PressDown(VK_ALT);
        PressDown(VK_SHIFT);
        KeyTap(functionKey);
        PressUp(VK_SHIFT);
        PressUp(VK_ALT);
        PressUp(VK_CONTROL);
    }

    private static void SendCtrlV()
    {
        WaitForCtrlRelease(700);
        PressDown(VK_CONTROL);
        KeyTap(VK_V);
        PressUp(VK_CONTROL);
    }

    private static void StartRegionCapture(CaptureMode mode)
    {
        if (mode == CaptureMode.Screenshot && !IsScreenshotSaveEnabled())
        {
            Log("screenshot ignored because screenshot saving is disabled");
            return;
        }

        try
        {
            ClipDeckRuntimeSettings settings = ClipDeckRuntimeSettings.Load(SettingsPath);
            settings.EnsureStorageFolders();
            settings.CleanupOldFiles(Log);

            using (RegionSelectionForm selector = new RegionSelectionForm(mode, settings, LogPath, ToolsRoot))
            {
                selector.ShowDialog();
            }
        }
        catch (Exception ex)
        {
            Log("failed to start screenshot selection: " + ex.Message);
        }
    }

    private static void ToggleRuler()
    {
        try
        {
            if (Ruler != null && !Ruler.IsDisposed)
            {
                Ruler.Close();
                Ruler = null;
                Log("ruler hidden");
                return;
            }

            Ruler = new RulerOverlayForm();
            Ruler.FormClosed += delegate { Ruler = null; };
            Ruler.Show();
            Log("ruler shown");
        }
        catch (Exception ex)
        {
            Log("failed to toggle ruler: " + ex.Message);
        }
    }

    private static bool IsScreenshotSaveEnabled()
    {
        try
        {
            if (String.IsNullOrEmpty(SettingsPath) || !File.Exists(SettingsPath)) return false;
            string json = File.ReadAllText(SettingsPath, Encoding.UTF8);
            return Regex.IsMatch(json, "\"screenshotSaveEnabled\"\\s*:\\s*true", RegexOptions.IgnoreCase);
        }
        catch
        {
            return false;
        }
    }

    private class HotkeySpec
    {
        public int Modifiers;
        public int Vk;
        public string Name;
    }

    private static void RegisterConfiguredHotKey(IntPtr handle, int id, string settingName, string fallback)
    {
        RegisterConfiguredHotKey(handle, id, settingName, fallback, null);
    }

    private static void RegisterConfiguredHotKey(IntPtr handle, int id, string settingName, string fallback, string conflictFallback)
    {
        string configured = ReadSettingString(settingName, fallback);
        HotkeySpec spec = ParseHotkey(configured);
        if (spec == null)
        {
            Log("invalid " + settingName + "=" + configured + ", using " + fallback);
            spec = ParseHotkey(fallback);
        }

        if (spec == null)
        {
            Log("failed to parse fallback hotkey " + fallback);
            return;
        }

        if (!RegisterHotKey(handle, id, spec.Modifiers, spec.Vk))
        {
            int error = Marshal.GetLastWin32Error();
            Log("failed to register " + spec.Name + " for " + settingName + " error=" + error);

            string fallbackCandidate = String.IsNullOrWhiteSpace(conflictFallback) ? fallback : conflictFallback;
            HotkeySpec fallbackSpec = ParseHotkey(fallbackCandidate);
            if (fallbackSpec != null && fallbackSpec.Name != spec.Name)
            {
                if (RegisterHotKey(handle, id, fallbackSpec.Modifiers, fallbackSpec.Vk))
                {
                    WriteSettingString(settingName, fallbackSpec.Name);
                    Log("registered fallback " + fallbackSpec.Name + " for " + settingName);
                }
                else
                {
                    Log("failed to register fallback " + fallbackSpec.Name + " for " + settingName + " error=" + Marshal.GetLastWin32Error());
                }
            }
            return;
        }
        Log("registered " + spec.Name + " for " + settingName);
    }

    private static void RegisterOptionalHotKey(IntPtr handle, int id, int modifiers, int vk, string name)
    {
        if (!RegisterHotKey(handle, id, modifiers, vk))
        {
            int error = Marshal.GetLastWin32Error();
            Log("failed to register " + name + " error=" + error);
            return;
        }
        Log("registered " + name);
    }

    private static string ReadSettingString(string key, string fallback)
    {
        try
        {
            if (String.IsNullOrEmpty(SettingsPath) || !File.Exists(SettingsPath)) return fallback;
            string json = File.ReadAllText(SettingsPath, Encoding.UTF8);
            Match match = Regex.Match(json, "\"" + Regex.Escape(key) + "\"\\s*:\\s*\"([^\"]+)\"", RegexOptions.IgnoreCase);
            if (!match.Success) return fallback;
            return Regex.Unescape(match.Groups[1].Value);
        }
        catch
        {
            return fallback;
        }
    }

    private static void WriteSettingString(string key, string value)
    {
        try
        {
            if (String.IsNullOrEmpty(SettingsPath) || !File.Exists(SettingsPath)) return;
            string json = File.ReadAllText(SettingsPath, Encoding.UTF8);
            string pattern = "\"" + Regex.Escape(key) + "\"\\s*:\\s*\"([^\"]*)\"";
            string replacement = "\"" + key + "\": \"" + value.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
            if (Regex.IsMatch(json, pattern, RegexOptions.IgnoreCase))
            {
                json = Regex.Replace(json, pattern, replacement, RegexOptions.IgnoreCase);
            }
            else
            {
                int insert = json.LastIndexOf('}');
                if (insert > 0)
                {
                    string prefix = json.Substring(0, insert).TrimEnd();
                    if (!prefix.EndsWith("{")) prefix += ",";
                    json = prefix + Environment.NewLine + "  " + replacement + Environment.NewLine + "}";
                }
            }
            File.WriteAllText(SettingsPath, json, Encoding.UTF8);
        }
        catch { }
    }

    private static HotkeySpec ParseHotkey(string hotkey)
    {
        if (String.IsNullOrWhiteSpace(hotkey)) return null;
        string[] parts = hotkey.Split(new char[] { '+' }, StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length < 2) return null;

        int modifiers = 0;
        string keyName = null;
        foreach (string rawPart in parts)
        {
            string part = rawPart.Trim();
            if (part.Equals("Ctrl", StringComparison.OrdinalIgnoreCase) || part.Equals("Control", StringComparison.OrdinalIgnoreCase))
            {
                modifiers |= MOD_CONTROL;
            }
            else if (part.Equals("Alt", StringComparison.OrdinalIgnoreCase))
            {
                modifiers |= MOD_ALT;
            }
            else if (part.Equals("Shift", StringComparison.OrdinalIgnoreCase))
            {
                modifiers |= MOD_SHIFT;
            }
            else if (part.Equals("Win", StringComparison.OrdinalIgnoreCase) || part.Equals("Windows", StringComparison.OrdinalIgnoreCase))
            {
                modifiers |= MOD_WIN;
            }
            else
            {
                keyName = part;
            }
        }

        if (modifiers == 0 || String.IsNullOrWhiteSpace(keyName)) return null;
        int vk = KeyNameToVirtualKey(keyName);
        if (vk <= 0) return null;

        return new HotkeySpec { Modifiers = modifiers, Vk = vk, Name = NormalizeHotkeyName(modifiers, keyName) };
    }

    private static string NormalizeHotkeyName(int modifiers, string keyName)
    {
        string name = "";
        if ((modifiers & MOD_CONTROL) != 0) name += "Ctrl+";
        if ((modifiers & MOD_ALT) != 0) name += "Alt+";
        if ((modifiers & MOD_SHIFT) != 0) name += "Shift+";
        if ((modifiers & MOD_WIN) != 0) name += "Win+";
        return name + keyName.ToUpperInvariant();
    }

    private static int KeyNameToVirtualKey(string keyName)
    {
        string key = keyName.Trim();
        if (key.Length == 1)
        {
            char c = Char.ToUpperInvariant(key[0]);
            if (c >= 'A' && c <= 'Z') return (int)c;
            if (c >= '0' && c <= '9') return (int)c;
            switch (c)
            {
                case '-': return 0xBD;
                case '=': return 0xBB;
                case '[': return 0xDB;
                case ']': return 0xDD;
                case '\\': return 0xDC;
                case ';': return 0xBA;
                case '\'': return 0xDE;
                case ',': return 0xBC;
                case '.': return 0xBE;
                case '/': return 0xBF;
                case '`': return 0xC0;
            }
        }

        Match fKey = Regex.Match(key, "^F([1-9]|1[0-9]|2[0-4])$", RegexOptions.IgnoreCase);
        if (fKey.Success) return 0x70 + Int32.Parse(fKey.Groups[1].Value) - 1;

        Match numKey = Regex.Match(key, "^Num([0-9])$", RegexOptions.IgnoreCase);
        if (numKey.Success) return 0x60 + Int32.Parse(numKey.Groups[1].Value);

        switch (key.ToUpperInvariant())
        {
            case "SPACE": return 0x20;
            case "ENTER": return 0x0D;
            case "TAB": return 0x09;
            case "ESC":
            case "ESCAPE": return 0x1B;
            case "BACKSPACE": return 0x08;
            case "DELETE": return 0x2E;
            case "INSERT": return 0x2D;
            case "HOME": return 0x24;
            case "END": return 0x23;
            case "PAGEUP": return 0x21;
            case "PAGEDOWN": return 0x22;
            case "UP": return 0x26;
            case "DOWN": return 0x28;
            case "LEFT": return 0x25;
            case "RIGHT": return 0x27;
        }

        return 0;
    }

    public static void Log(string message)
    {
        if (String.IsNullOrEmpty(LogPath)) return;
        try
        {
            File.AppendAllText(LogPath, DateTime.Now.ToString("o") + " " + message + Environment.NewLine);
        }
        catch { }
    }

    private static void WaitForCtrlRelease(int timeoutMs)
    {
        int waited = 0;
        while (waited < timeoutMs)
        {
            bool ctrlDown =
                (GetAsyncKeyState(0x11) & 0x8000) != 0 ||
                (GetAsyncKeyState(0xA2) & 0x8000) != 0 ||
                (GetAsyncKeyState(0xA3) & 0x8000) != 0;

            if (!ctrlDown)
            {
                Thread.Sleep(20);
                return;
            }

            Thread.Sleep(10);
            waited += 10;
        }
    }

    private static void KeyTap(int vk)
    {
        PressDown(vk);
        PressUp(vk);
    }

    private static void PressDown(int vk)
    {
        keybd_event((byte)vk, 0, 0, UIntPtr.Zero);
    }

    private static void PressUp(int vk)
    {
        keybd_event((byte)vk, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }
}

public enum CaptureMode
{
    Screenshot,
    Ocr,
    Record
}

public class ClipDeckRuntimeSettings
{
    public string StorageRoot;
    public int RetentionDays;
    public string RecordingFormat;
    public int RecordingFps;
    public bool RecordingCaptureCursor;
    public bool AndroidMirrorEnabled;
    public string AndroidMirrorRoot;

    public string ScreenshotsDir { get { return Path.Combine(StorageRoot, "Screenshots"); } }
    public string RecordingsDir { get { return Path.Combine(StorageRoot, "Recordings"); } }
    public string OcrDir { get { return Path.Combine(StorageRoot, "OCR"); } }
    public string AndroidScreenshotsDir { get { return Path.Combine(AndroidMirrorRoot ?? "", "Screenshots"); } }
    public string AndroidRecordingsDir { get { return Path.Combine(AndroidMirrorRoot ?? "", "Recordings"); } }
    public string AndroidOcrDir { get { return Path.Combine(AndroidMirrorRoot ?? "", "OCR"); } }

    public static ClipDeckRuntimeSettings Load(string settingsPath)
    {
        string desktop = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
        ClipDeckRuntimeSettings settings = new ClipDeckRuntimeSettings();
        settings.StorageRoot = Path.Combine(desktop, "ClipDeck");
        settings.RetentionDays = 7;
        settings.RecordingFormat = "MP4";
        settings.RecordingFps = 24;
        settings.RecordingCaptureCursor = true;
        settings.AndroidMirrorEnabled = false;
        settings.AndroidMirrorRoot = "";

        try
        {
            if (!String.IsNullOrEmpty(settingsPath) && File.Exists(settingsPath))
            {
                string json = File.ReadAllText(settingsPath, Encoding.UTF8);
                settings.StorageRoot = ReadJsonString(json, "storageRoot", settings.StorageRoot);
                settings.RetentionDays = ReadJsonInt(json, "retentionDays", settings.RetentionDays);
                settings.RecordingFormat = ReadJsonString(json, "recordingFormat", settings.RecordingFormat).ToUpperInvariant();
                settings.RecordingFps = ReadJsonInt(json, "recordingFps", settings.RecordingFps);
                settings.RecordingCaptureCursor = ReadJsonBool(json, "recordingCaptureCursor", settings.RecordingCaptureCursor);
                settings.AndroidMirrorEnabled = ReadJsonBool(json, "androidMirrorEnabled", settings.AndroidMirrorEnabled);
                settings.AndroidMirrorRoot = ReadJsonString(json, "androidMirrorRoot", settings.AndroidMirrorRoot);
            }
        }
        catch { }

        if (String.IsNullOrWhiteSpace(settings.StorageRoot)) settings.StorageRoot = Path.Combine(desktop, "ClipDeck");
        if (settings.RetentionDays < 1) settings.RetentionDays = 7;
        if (settings.RetentionDays > 365) settings.RetentionDays = 365;
        if (settings.RecordingFormat != "MP4" && settings.RecordingFormat != "GIF") settings.RecordingFormat = "MP4";
        if (settings.RecordingFps != 24 && settings.RecordingFps != 30 && settings.RecordingFps != 60) settings.RecordingFps = 24;
        if (String.IsNullOrWhiteSpace(settings.AndroidMirrorRoot)) settings.AndroidMirrorEnabled = false;
        return settings;
    }

    public void EnsureStorageFolders()
    {
        Directory.CreateDirectory(StorageRoot);
        Directory.CreateDirectory(ScreenshotsDir);
        Directory.CreateDirectory(RecordingsDir);
        Directory.CreateDirectory(OcrDir);
        EnsureAndroidMirrorFolders();
    }

    public void EnsureAndroidMirrorFolders()
    {
        if (!AndroidMirrorEnabled || String.IsNullOrWhiteSpace(AndroidMirrorRoot)) return;
        Directory.CreateDirectory(AndroidMirrorRoot);
        Directory.CreateDirectory(AndroidScreenshotsDir);
        Directory.CreateDirectory(AndroidRecordingsDir);
        Directory.CreateDirectory(AndroidOcrDir);
    }

    public void MirrorCapture(string sourcePath, string kind, Action<string> log)
    {
        try
        {
            if (!AndroidMirrorEnabled || String.IsNullOrWhiteSpace(AndroidMirrorRoot)) return;
            if (String.IsNullOrWhiteSpace(sourcePath) || !File.Exists(sourcePath)) return;

            string targetDir = AndroidMirrorRoot;
            if (kind == "Screenshots") targetDir = AndroidScreenshotsDir;
            else if (kind == "Recordings") targetDir = AndroidRecordingsDir;
            else if (kind == "OCR") targetDir = AndroidOcrDir;

            Directory.CreateDirectory(targetDir);
            string targetPath = Path.Combine(targetDir, Path.GetFileName(sourcePath));
            File.Copy(sourcePath, targetPath, true);
            if (log != null) log("android mirror copied " + sourcePath + " -> " + targetPath);
        }
        catch (Exception ex)
        {
            if (log != null) log("android mirror failed: " + ex.Message);
        }
    }

    public void CleanupOldFiles(Action<string> log)
    {
        try
        {
            EnsureStorageFolders();
            DateTime cutoff = DateTime.Now.AddDays(-RetentionDays);
            foreach (string dir in new string[] { ScreenshotsDir, RecordingsDir, OcrDir })
            {
                foreach (string file in Directory.GetFiles(dir))
                {
                    try
                    {
                        FileInfo info = new FileInfo(file);
                        if (info.LastWriteTime < cutoff)
                        {
                            info.Delete();
                            if (log != null) log("cleanup deleted " + file);
                        }
                    }
                    catch (Exception ex)
                    {
                        if (log != null) log("cleanup skipped file: " + ex.Message);
                    }
                }
            }
        }
        catch (Exception ex)
        {
            if (log != null) log("cleanup failed: " + ex.Message);
        }
    }

    private static string ReadJsonString(string json, string key, string fallback)
    {
        Match match = Regex.Match(json, "\"" + Regex.Escape(key) + "\"\\s*:\\s*\"([^\"]*)\"", RegexOptions.IgnoreCase);
        if (!match.Success) return fallback;
        return Regex.Unescape(match.Groups[1].Value);
    }

    private static int ReadJsonInt(string json, string key, int fallback)
    {
        Match match = Regex.Match(json, "\"" + Regex.Escape(key) + "\"\\s*:\\s*([0-9]+)", RegexOptions.IgnoreCase);
        if (!match.Success) return fallback;
        int value;
        if (!Int32.TryParse(match.Groups[1].Value, out value)) return fallback;
        return value;
    }

    private static bool ReadJsonBool(string json, string key, bool fallback)
    {
        Match match = Regex.Match(json, "\"" + Regex.Escape(key) + "\"\\s*:\\s*(true|false)", RegexOptions.IgnoreCase);
        if (!match.Success) return fallback;
        return match.Groups[1].Value.Equals("true", StringComparison.OrdinalIgnoreCase);
    }
}

public class RegionSelectionForm : Form
{
    private readonly CaptureMode mode;
    private readonly ClipDeckRuntimeSettings settings;
    private readonly string logPath;
    private readonly string toolsRoot;
    private Point dragStart;
    private Point dragCurrent;
    private bool isDragging = false;

    public RegionSelectionForm(CaptureMode mode, ClipDeckRuntimeSettings settings, string logPath, string toolsRoot)
    {
        this.mode = mode;
        this.settings = settings;
        this.logPath = logPath;
        this.toolsRoot = toolsRoot;
        this.StartPosition = FormStartPosition.Manual;
        this.Bounds = SystemInformation.VirtualScreen;
        this.FormBorderStyle = FormBorderStyle.None;
        this.ShowInTaskbar = false;
        this.TopMost = true;
        this.BackColor = Color.Black;
        this.Opacity = 0.22;
        this.Cursor = Cursors.Cross;
        this.DoubleBuffered = true;
        this.KeyPreview = true;
    }

    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);
        this.Activate();
        Log(mode.ToString().ToLowerInvariant() + " selection started");
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        if (e.Button != MouseButtons.Left) return;
        isDragging = true;
        dragStart = e.Location;
        dragCurrent = e.Location;
        Invalidate();
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        if (!isDragging) return;
        dragCurrent = e.Location;
        Invalidate();
    }

    protected override void OnMouseUp(MouseEventArgs e)
    {
        if (e.Button != MouseButtons.Left || !isDragging) return;
        isDragging = false;
        dragCurrent = e.Location;

        Rectangle clientRect = NormalizeRectangle(dragStart, dragCurrent);
        if (clientRect.Width < 4 || clientRect.Height < 4)
        {
            Log("screenshot selection cancelled: region too small");
            Close();
            return;
        }

        Rectangle screenRect = new Rectangle(
            this.Left + clientRect.Left,
            this.Top + clientRect.Top,
            clientRect.Width,
            clientRect.Height
        );

        this.Hide();
        Application.DoEvents();
        Thread.Sleep(120);
        SaveRegion(screenRect);
        Close();
    }

    protected override void OnKeyDown(KeyEventArgs e)
    {
        if (e.KeyCode == Keys.Escape)
        {
            Log("screenshot selection cancelled with Escape");
            Close();
            return;
        }
        base.OnKeyDown(e);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        if (!isDragging) return;

        Rectangle rect = NormalizeRectangle(dragStart, dragCurrent);
        using (Pen border = new Pen(Color.FromArgb(255, 76, 181, 255), 3))
        using (Brush fill = new SolidBrush(Color.FromArgb(35, 76, 181, 255)))
        {
            e.Graphics.FillRectangle(fill, rect);
            e.Graphics.DrawRectangle(border, rect);
        }
    }

    private static Rectangle NormalizeRectangle(Point a, Point b)
    {
        int left = Math.Min(a.X, b.X);
        int top = Math.Min(a.Y, b.Y);
        int right = Math.Max(a.X, b.X);
        int bottom = Math.Max(a.Y, b.Y);
        return Rectangle.FromLTRB(left, top, right, bottom);
    }

    private void SaveRegion(Rectangle screenRect)
    {
        if (mode == CaptureMode.Screenshot)
        {
            SaveScreenshot(screenRect);
        }
        else if (mode == CaptureMode.Ocr)
        {
            RunOcr(screenRect);
        }
        else if (mode == CaptureMode.Record)
        {
            StartRecording(screenRect);
        }
    }

    private void SaveScreenshot(Rectangle screenRect)
    {
        try
        {
            Directory.CreateDirectory(settings.ScreenshotsDir);
            using (Bitmap bitmap = new Bitmap(screenRect.Width, screenRect.Height))
            using (Graphics graphics = Graphics.FromImage(bitmap))
            {
                graphics.CopyFromScreen(screenRect.Left, screenRect.Top, 0, 0, screenRect.Size);
                string path = CreateUniquePath(settings.ScreenshotsDir, "ClipDeck Screenshot ", ".png");
                bitmap.Save(path, ImageFormat.Png);
                Log("saved selected screenshot " + path);
                settings.MirrorCapture(path, "Screenshots", Log);
                WriteLastCapture(path);
            }
        }
        catch (Exception ex)
        {
            Log("failed to save selected screenshot: " + ex.Message);
        }
    }

    private void RunOcr(Rectangle screenRect)
    {
        string imagePath = null;
        try
        {
            Directory.CreateDirectory(settings.OcrDir);
            imagePath = CreateUniquePath(settings.OcrDir, "ClipDeck OCR ", ".png");
            using (Bitmap bitmap = new Bitmap(screenRect.Width, screenRect.Height))
            using (Graphics graphics = Graphics.FromImage(bitmap))
            {
                graphics.CopyFromScreen(screenRect.Left, screenRect.Top, 0, 0, screenRect.Size);
                bitmap.Save(imagePath, ImageFormat.Png);
            }
            settings.MirrorCapture(imagePath, "OCR", Log);

            string tesseract = FindTesseract();
            if (String.IsNullOrEmpty(tesseract))
            {
                Log("ocr missing dependency: tesseract.exe");
                ShowToast("ClipDeck OCR", "missing dependency: tesseract.exe");
                WriteLastCapture(imagePath);
                return;
            }

            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = tesseract;
            psi.Arguments = Quote(imagePath) + " stdout -l rus+eng --psm 6";
            psi.UseShellExecute = false;
            psi.RedirectStandardOutput = true;
            psi.RedirectStandardError = true;
            psi.CreateNoWindow = true;
            string tessdata = FindTessdata(tesseract);
            if (!String.IsNullOrEmpty(tessdata))
            {
                psi.EnvironmentVariables["TESSDATA_PREFIX"] = tessdata;
            }

            using (Process process = Process.Start(psi))
            {
                string output = process.StandardOutput.ReadToEnd();
                string error = process.StandardError.ReadToEnd();
                process.WaitForExit(20000);
                if (process.ExitCode != 0 || String.IsNullOrWhiteSpace(output))
                {
                    Log("ocr failed: " + error.Trim());
                    ShowToast("ClipDeck OCR", "text not recognized");
                    WriteLastCapture(imagePath);
                    return;
                }

                Clipboard.SetText(output.Trim());
                Log("ocr copied text chars=" + output.Trim().Length + " source=" + imagePath);
                ShowToast("ClipDeck OCR", "text copied to clipboard");
                WriteLastCapture(imagePath);
            }
        }
        catch (Exception ex)
        {
            Log("ocr failed: " + ex.Message);
            ShowToast("ClipDeck OCR", "OCR failed");
            if (!String.IsNullOrEmpty(imagePath)) WriteLastCapture(imagePath);
        }
    }

    private void StartRecording(Rectangle screenRect)
    {
        try
        {
            Directory.CreateDirectory(settings.RecordingsDir);
            string ffmpeg = FindFfmpeg();
            if (String.IsNullOrEmpty(ffmpeg))
            {
                Log("record missing dependency: ffmpeg.exe");
                ShowToast("ClipDeck Record", "missing dependency: ffmpeg.exe");
                return;
            }

            string extension = settings.RecordingFormat == "GIF" ? ".gif" : ".mp4";
            string path = CreateUniquePath(settings.RecordingsDir, "ClipDeck Recording ", extension);
            RecordingControllerForm controller = new RecordingControllerForm(ffmpeg, path, screenRect, settings, logPath);
            controller.Show();
            WriteLastCapture(path);
        }
        catch (Exception ex)
        {
            Log("failed to start recording: " + ex.Message);
            ShowToast("ClipDeck Record", "recording failed");
        }
    }

    private string CreateUniquePath(string directory, string prefix, string extension)
    {
        string baseName = prefix + DateTime.Now.ToString("yyyy-MM-dd HH-mm-ss");
        string path = Path.Combine(directory, baseName + extension);
        int suffix = 2;
        while (File.Exists(path))
        {
            path = Path.Combine(directory, baseName + " " + suffix + extension);
            suffix++;
        }
        return path;
    }

    private void Log(string message)
    {
        if (String.IsNullOrEmpty(logPath)) return;
        try
        {
            File.AppendAllText(logPath, DateTime.Now.ToString("o") + " " + message + Environment.NewLine);
        }
        catch { }
    }

    private string FindFfmpeg()
    {
        string[] candidates = new string[] {
            Path.Combine(toolsRoot ?? "", "ffmpeg.exe"),
            Path.Combine(toolsRoot ?? "", "ffmpeg", "ffmpeg.exe"),
            @"E:\MediGen\portable_bundle\ffmpeg\ffmpeg-8.0.1-essentials_build\bin\ffmpeg.exe"
        };
        foreach (string candidate in candidates)
        {
            if (!String.IsNullOrEmpty(candidate) && File.Exists(candidate)) return candidate;
        }
        return FindOnPath("ffmpeg.exe");
    }

    private string FindTesseract()
    {
        string[] candidates = new string[] {
            Path.Combine(toolsRoot ?? "", "tesseract.exe"),
            Path.Combine(toolsRoot ?? "", "tesseract", "tesseract.exe")
        };
        foreach (string candidate in candidates)
        {
            if (!String.IsNullOrEmpty(candidate) && File.Exists(candidate)) return candidate;
        }
        return FindOnPath("tesseract.exe");
    }

    private string FindTessdata(string tesseractPath)
    {
        string[] candidates = new string[] {
            Path.Combine(toolsRoot ?? "", "tessdata"),
            Path.Combine(Path.GetDirectoryName(tesseractPath), "tessdata")
        };
        foreach (string candidate in candidates)
        {
            if (Directory.Exists(candidate)) return candidate;
        }
        return null;
    }

    private static string FindOnPath(string exeName)
    {
        try
        {
            string pathEnv = Environment.GetEnvironmentVariable("PATH") ?? "";
            foreach (string part in pathEnv.Split(Path.PathSeparator))
            {
                if (String.IsNullOrWhiteSpace(part)) continue;
                string candidate = Path.Combine(part.Trim(), exeName);
                if (File.Exists(candidate)) return candidate;
            }
        }
        catch { }
        return null;
    }

    private void WriteLastCapture(string path)
    {
        try
        {
            string root = String.IsNullOrEmpty(ClipboardHotkeyWindow.AppRoot)
                ? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "ClipDeck")
                : ClipboardHotkeyWindow.AppRoot;
            Directory.CreateDirectory(root);
            File.WriteAllText(Path.Combine(root, "last-capture.txt"), path, Encoding.UTF8);
        }
        catch { }
    }

    private static string Quote(string value)
    {
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }

    private void ShowToast(string title, string message)
    {
        try
        {
            MessageBox.Show(message, title, MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
        catch { }
    }
}

public class RecordingControllerForm : Form
{
    private readonly string ffmpegPath;
    private readonly string outputPath;
    private readonly Rectangle screenRect;
    private readonly ClipDeckRuntimeSettings settings;
    private readonly string logPath;
    private Process ffmpegProcess;
    private bool paused = false;
    private Button pauseButton;
    private Button finishButton;

    [DllImport("ntdll.dll")]
    private static extern int NtSuspendProcess(IntPtr processHandle);

    [DllImport("ntdll.dll")]
    private static extern int NtResumeProcess(IntPtr processHandle);

    public RecordingControllerForm(string ffmpegPath, string outputPath, Rectangle screenRect, ClipDeckRuntimeSettings settings, string logPath)
    {
        this.ffmpegPath = ffmpegPath;
        this.outputPath = outputPath;
        this.screenRect = screenRect;
        this.settings = settings;
        this.logPath = logPath;

        this.StartPosition = FormStartPosition.Manual;
        this.Location = new Point(Math.Max(screenRect.Right - 210, screenRect.Left), Math.Max(screenRect.Top + 8, 0));
        this.Size = new Size(202, 44);
        this.FormBorderStyle = FormBorderStyle.None;
        this.TopMost = true;
        this.BackColor = Color.FromArgb(14, 21, 34);
        this.Opacity = 0.94;
        this.ShowInTaskbar = false;

        pauseButton = new Button();
        pauseButton.Text = "????";
        pauseButton.Left = 6;
        pauseButton.Top = 7;
        pauseButton.Width = 86;
        pauseButton.Height = 30;
        pauseButton.Click += delegate { TogglePause(); };
        this.Controls.Add(pauseButton);

        finishButton = new Button();
        finishButton.Text = "?????????";
        finishButton.Left = 100;
        finishButton.Top = 7;
        finishButton.Width = 96;
        finishButton.Height = 30;
        finishButton.Click += delegate { FinishRecording(); };
        this.Controls.Add(finishButton);

        this.Shown += delegate { StartFfmpeg(); };
        this.FormClosing += delegate { if (ffmpegProcess != null && !ffmpegProcess.HasExited) FinishRecording(); };
    }

    private void StartFfmpeg()
    {
        try
        {
            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = ffmpegPath;
            psi.Arguments = BuildArguments();
            psi.UseShellExecute = false;
            psi.RedirectStandardInput = true;
            psi.RedirectStandardError = true;
            psi.CreateNoWindow = true;
            ffmpegProcess = Process.Start(psi);
            Log("recording started output=" + outputPath + " args=" + psi.Arguments);
        }
        catch (Exception ex)
        {
            Log("recording failed to start: " + ex.Message);
            MessageBox.Show("recording failed", "ClipDeck Record", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            Close();
        }
    }

    private string BuildArguments()
    {
        string drawMouse = settings.RecordingCaptureCursor ? "1" : "0";
        string input = "-y -f gdigrab -framerate " + settings.RecordingFps +
            " -offset_x " + screenRect.Left +
            " -offset_y " + screenRect.Top +
            " -video_size " + screenRect.Width + "x" + screenRect.Height +
            " -draw_mouse " + drawMouse +
            " -i desktop ";

        if (settings.RecordingFormat == "GIF")
        {
            return input + "-vf fps=" + settings.RecordingFps + " " + Quote(outputPath);
        }

        return input + "-c:v libx264 -preset ultrafast -pix_fmt yuv420p " + Quote(outputPath);
    }

    private void TogglePause()
    {
        try
        {
            if (ffmpegProcess == null || ffmpegProcess.HasExited) return;
            if (!paused)
            {
                NtSuspendProcess(ffmpegProcess.Handle);
                paused = true;
                pauseButton.Text = "??????????";
                Log("recording paused");
            }
            else
            {
                NtResumeProcess(ffmpegProcess.Handle);
                paused = false;
                pauseButton.Text = "????";
                Log("recording resumed");
            }
        }
        catch (Exception ex)
        {
            Log("pause/resume failed: " + ex.Message);
        }
    }

    private void FinishRecording()
    {
        try
        {
            if (ffmpegProcess != null && !ffmpegProcess.HasExited)
            {
                if (paused)
                {
                    NtResumeProcess(ffmpegProcess.Handle);
                    paused = false;
                }
                ffmpegProcess.StandardInput.WriteLine("q");
                if (!ffmpegProcess.WaitForExit(5000))
                {
                    ffmpegProcess.Kill();
                }
            }
            Log("recording finished output=" + outputPath);
            settings.MirrorCapture(outputPath, "Recordings", Log);
        }
        catch (Exception ex)
        {
            Log("recording finish failed: " + ex.Message);
        }
        finally
        {
            Close();
        }
    }

    private static string Quote(string value)
    {
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }

    private void Log(string message)
    {
        if (String.IsNullOrEmpty(logPath)) return;
        try { File.AppendAllText(logPath, DateTime.Now.ToString("o") + " " + message + Environment.NewLine); }
        catch { }
    }
}

public class RulerOverlayForm : Form
{
    public RulerOverlayForm()
    {
        Rectangle area = Screen.PrimaryScreen.WorkingArea;
        this.StartPosition = FormStartPosition.Manual;
        this.Location = new Point(area.Left + 80, area.Top + 90);
        this.Size = new Size(Math.Min(920, area.Width - 160), 112);
        this.FormBorderStyle = FormBorderStyle.None;
        this.TopMost = true;
        this.ShowInTaskbar = false;
        this.BackColor = Color.FromArgb(14, 21, 34);
        this.Opacity = 0.88;
        this.DoubleBuffered = true;
        this.Cursor = Cursors.SizeAll;
        this.MouseDown += delegate(object sender, MouseEventArgs e) { if (e.Button == MouseButtons.Right) Close(); };
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        using (Pen border = new Pen(Color.FromArgb(202, 107, 255), 2))
        using (Pen tick = new Pen(Color.FromArgb(145, 158, 180), 1))
        using (Pen major = new Pen(Color.FromArgb(56, 189, 248), 1))
        using (Brush textBrush = new SolidBrush(Color.FromArgb(249, 250, 252)))
        using (Font font = new Font("Segoe UI Semibold", 8))
        {
            e.Graphics.DrawRectangle(border, 1, 1, Width - 3, Height - 3);
            int baseY = 72;
            e.Graphics.DrawLine(major, 24, baseY, Width - 24, baseY);
            for (int x = 24; x < Width - 24; x += 10)
            {
                bool isMajor = ((x - 24) % 100) == 0;
                bool isHalf = ((x - 24) % 50) == 0;
                int height = isMajor ? 30 : (isHalf ? 22 : 12);
                e.Graphics.DrawLine(isMajor ? major : tick, x, baseY, x, baseY - height);
                if (isMajor)
                {
                    string label = ((x - 24)).ToString() + "px";
                    e.Graphics.DrawString(label, font, textBrush, x - 10, baseY - 48);
                }
            }
            e.Graphics.DrawString("Alt+Shift+W toggles ruler. Right-click to close.", font, textBrush, 24, 16);
        }
    }
}
'@

$form = New-Object ClipboardHotkeyWindow
[ClipboardHotkeyWindow]::LogPath = $logPath
[ClipboardHotkeyWindow]::SettingsPath = $settingsPath
[ClipboardHotkeyWindow]::AppRoot = $appRoot
[ClipboardHotkeyWindow]::ToolsRoot = $toolsRoot
$form.ShowInTaskbar = $false
$form.WindowState = 'Minimized'
$form.Opacity = 0
[System.Windows.Forms.Application]::Run($form)
