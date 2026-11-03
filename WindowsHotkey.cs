using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public static class WordGlanceWindowsHotkey
{
    // Ctrl + Alt + Win, with key-repeat suppressed. Shift is deliberately absent.
    private const uint Modifiers = 0x0002 | 0x0001 | 0x0008 | 0x4000;
    private const uint KeyW = 0x57;
    private const int HotkeyId = 19505;
    private const string Destination = "http://127.0.0.1:18743/cambridge";

    [StructLayout(LayoutKind.Sequential)]
    private struct Message
    {
        public IntPtr Window;
        public uint Id;
        public UIntPtr WParam;
        public IntPtr LParam;
        public uint Time;
        public int X;
        public int Y;
        public uint Private;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool RegisterHotKey(IntPtr window, int id, uint modifiers, uint key);
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnregisterHotKey(IntPtr window, int id);
    [DllImport("user32.dll", SetLastError = true)]
    private static extern int GetMessage(out Message message, IntPtr window, uint min, uint max);

    public static void Run(string logFolder, bool checkOnly)
    {
        Directory.CreateDirectory(logFolder);
        if (!RegisterHotKey(IntPtr.Zero, HotkeyId, Modifiers, KeyW))
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Cannot register Ctrl+Alt+Win+W");
        try
        {
            if (checkOnly) return;
            string status = "{\"combination\":\"Ctrl+Alt+Win+W\",\"modifiers\":16395,\"key\":87,\"pid\":"
                + Process.GetCurrentProcess().Id + ",\"registeredAt\":\"" + DateTime.Now.ToString("o") + "\"}";
            File.WriteAllText(Path.Combine(logFolder, "hotkey-status.json"), status, Encoding.UTF8);
            Log(logFolder, "Registered Ctrl+Alt+Win+W");
            Message message;
            int result;
            while ((result = GetMessage(out message, IntPtr.Zero, 0, 0)) > 0)
            {
                if (message.Id != 0x0312 || message.WParam.ToUInt64() != HotkeyId) continue;
                try
                {
                    Process.Start(new ProcessStartInfo(Destination) { UseShellExecute = true });
                    Log(logFolder, "Cambridge open requested");
                }
                catch (Exception error) { Log(logFolder, "Open failed: " + error.Message); }
            }
            if (result < 0) throw new Win32Exception(Marshal.GetLastWin32Error());
        }
        finally { UnregisterHotKey(IntPtr.Zero, HotkeyId); }
    }

    private static void Log(string folder, string message)
    {
        File.AppendAllText(Path.Combine(folder, "hotkey.log"), DateTime.Now.ToString("o") + " " + message + Environment.NewLine, Encoding.UTF8);
    }
}
