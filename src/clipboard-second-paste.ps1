Add-Type -AssemblyName System.Windows.Forms

$dittoPath = 'C:\Program Files\Ditto\Ditto.exe'
if (-not (Get-Process -Name Ditto -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $dittoPath)) {
    Start-Process -FilePath $dittoPath
    Start-Sleep -Seconds 2
}

Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @'
using System;
using System.Threading;
using System.Windows.Forms;
using System.Runtime.InteropServices;

public class ClipboardHotkeyWindow : Form
{
    private const int WM_HOTKEY = 0x0312;
    private const int MOD_CONTROL = 0x0002;
    private const int KEYEVENTF_KEYUP = 0x0002;
    private const int VK_CONTROL = 0x11;
    private const int VK_ALT = 0x12;
    private const int VK_SHIFT = 0x10;
    private const int VK_F14 = 0x7D;

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
        RegisterHotKey(this.Handle, 1, MOD_CONTROL, 0x31); // Ctrl+1
        RegisterHotKey(this.Handle, 2, MOD_CONTROL, 0x32); // Ctrl+2
        RegisterHotKey(this.Handle, 3, MOD_CONTROL, 0x42); // Ctrl+B
    }

    protected override void OnHandleDestroyed(EventArgs e)
    {
        UnregisterHotKey(this.Handle, 1);
        UnregisterHotKey(this.Handle, 2);
        UnregisterHotKey(this.Handle, 3);
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
            else if (id == 2 || id == 3)
            {
                PasteDittoPosition2();
            }
            return;
        }
        base.WndProc(ref m);
    }

    private static void PasteDittoPosition2()
    {
        uint sequenceBefore = GetClipboardSequenceNumber();
        SendDittoPosition2();
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

    private static void SendDittoPosition2()
    {
        PressDown(VK_CONTROL);
        PressDown(VK_ALT);
        PressDown(VK_SHIFT);
        KeyTap(VK_F14);
        PressUp(VK_SHIFT);
        PressUp(VK_ALT);
        PressUp(VK_CONTROL);
    }

    private static void SendCtrlV()
    {
        WaitForCtrlRelease(700);
        SendKeys.SendWait("^v");
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
'@

$form = New-Object ClipboardHotkeyWindow
$form.ShowInTaskbar = $false
$form.WindowState = 'Minimized'
$form.Opacity = 0
[System.Windows.Forms.Application]::Run($form)
