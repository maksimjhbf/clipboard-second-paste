Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$logPath = Join-Path $env:APPDATA 'ClipDeck\clipboard-hotkeys.log'
$settingsPath = Join-Path $env:APPDATA 'ClipDeck\clipdeck-settings.json'
$desktopPath = [Environment]::GetFolderPath('Desktop')
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

public class ClipboardHotkeyWindow : Form
{
    private const int WM_HOTKEY = 0x0312;
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
    public static string DesktopPath = null;

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
        RegisterRequiredHotKey(this.Handle, 1, MOD_CONTROL, 0x31, "Ctrl+1");
        RegisterRequiredHotKey(this.Handle, 2, MOD_CONTROL, 0x32, "Ctrl+2");
        RegisterRequiredHotKey(this.Handle, 3, MOD_CONTROL, 0x33, "Ctrl+3");
        RegisterRequiredHotKey(this.Handle, 4, MOD_CONTROL, 0x42, "Ctrl+B");
        RegisterRequiredHotKey(this.Handle, 5, MOD_WIN | MOD_SHIFT, VK_D, "Win+Shift+D");
        Log("hotkeys registered");
    }

    protected override void OnHandleDestroyed(EventArgs e)
    {
        UnregisterHotKey(this.Handle, 1);
        UnregisterHotKey(this.Handle, 2);
        UnregisterHotKey(this.Handle, 3);
        UnregisterHotKey(this.Handle, 4);
        UnregisterHotKey(this.Handle, 5);
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
                StartRegionScreenshotIfEnabled();
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

    private static void StartRegionScreenshotIfEnabled()
    {
        if (!IsScreenshotSaveEnabled())
        {
            Log("Win+Shift+D ignored because screenshot saving is disabled");
            return;
        }

        try
        {
            string desktop = String.IsNullOrEmpty(DesktopPath)
                ? Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory)
                : DesktopPath;
            Directory.CreateDirectory(desktop);

            using (ScreenshotSelectionForm selector = new ScreenshotSelectionForm(desktop, LogPath))
            {
                selector.ShowDialog();
            }
        }
        catch (Exception ex)
        {
            Log("failed to start screenshot selection: " + ex.Message);
        }
    }

    private static bool IsScreenshotSaveEnabled()
    {
        try
        {
            if (String.IsNullOrEmpty(SettingsPath) || !File.Exists(SettingsPath)) return false;
            string json = File.ReadAllText(SettingsPath);
            return Regex.IsMatch(json, "\"screenshotSaveEnabled\"\\s*:\\s*true", RegexOptions.IgnoreCase);
        }
        catch
        {
            return false;
        }
    }

    private static void RegisterRequiredHotKey(IntPtr handle, int id, int modifiers, int vk, string name)
    {
        if (!RegisterHotKey(handle, id, modifiers, vk))
        {
            int error = Marshal.GetLastWin32Error();
            Log("failed to register " + name + " error=" + error);
            throw new InvalidOperationException("Failed to register " + name + ". Win32 error " + error);
        }
        Log("registered " + name);
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

public class ScreenshotSelectionForm : Form
{
    private readonly string desktopPath;
    private readonly string logPath;
    private Point dragStart;
    private Point dragCurrent;
    private bool isDragging = false;

    public ScreenshotSelectionForm(string desktopPath, string logPath)
    {
        this.desktopPath = desktopPath;
        this.logPath = logPath;
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
        Log("screenshot selection started");
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
        try
        {
            Directory.CreateDirectory(desktopPath);
            using (Bitmap bitmap = new Bitmap(screenRect.Width, screenRect.Height))
            using (Graphics graphics = Graphics.FromImage(bitmap))
            {
                graphics.CopyFromScreen(screenRect.Left, screenRect.Top, 0, 0, screenRect.Size);
                string path = CreateScreenshotPath();
                bitmap.Save(path, ImageFormat.Png);
                Log("saved selected screenshot " + path);
            }
        }
        catch (Exception ex)
        {
            Log("failed to save selected screenshot: " + ex.Message);
        }
    }

    private string CreateScreenshotPath()
    {
        string baseName = "ClipDeck Screenshot " + DateTime.Now.ToString("yyyy-MM-dd HH-mm-ss");
        string path = Path.Combine(desktopPath, baseName + ".png");
        int suffix = 2;
        while (File.Exists(path))
        {
            path = Path.Combine(desktopPath, baseName + " " + suffix + ".png");
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
}
'@

$form = New-Object ClipboardHotkeyWindow
[ClipboardHotkeyWindow]::LogPath = $logPath
[ClipboardHotkeyWindow]::SettingsPath = $settingsPath
[ClipboardHotkeyWindow]::DesktopPath = $desktopPath
$form.ShowInTaskbar = $false
$form.WindowState = 'Minimized'
$form.Opacity = 0
[System.Windows.Forms.Application]::Run($form)
