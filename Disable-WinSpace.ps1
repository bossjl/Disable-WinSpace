$source = @'
using System;
using System.Runtime.InteropServices;

public static class WinSpaceBlocker
{
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_KEYUP = 0x0101;
    private const int WM_SYSKEYDOWN = 0x0104;
    private const int WM_SYSKEYUP = 0x0105;

    private static bool swallowSpace;
    private static HookProc callback = Hook;
    private static IntPtr hook;

    private delegate IntPtr HookProc(int code, IntPtr wParam, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    private struct KeyboardData
    {
        public uint vkCode, scanCode, flags, time;
        public UIntPtr extraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct Point { public int x, y; }

    [StructLayout(LayoutKind.Sequential)]
    private struct Message
    {
        public IntPtr hwnd;
        public uint message;
        public UIntPtr wParam;
        public IntPtr lParam;
        public uint time;
        public Point point;
        public uint privateData;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int id, HookProc proc, IntPtr module, uint threadId);

    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hook, int code, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnhookWindowsHookEx(IntPtr hook);

    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int key);

    [DllImport("user32.dll")]
    private static extern int GetMessage(out Message msg, IntPtr hwnd, uint min, uint max);

    [DllImport("user32.dll")]
    private static extern bool TranslateMessage(ref Message msg);

    [DllImport("user32.dll")]
    private static extern IntPtr DispatchMessage(ref Message msg);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
    private static extern IntPtr GetModuleHandle(string moduleName);

    private static bool IsWindowsKeyDown()
    {
        return (GetAsyncKeyState(0x5B) & 0x8000) != 0 ||
               (GetAsyncKeyState(0x5C) & 0x8000) != 0;
    }

    private static IntPtr Hook(int code, IntPtr wParam, IntPtr lParam)
    {
        if (code >= 0)
        {
            int message = wParam.ToInt32();
            bool down = message == WM_KEYDOWN || message == WM_SYSKEYDOWN;
            bool up = message == WM_KEYUP || message == WM_SYSKEYUP;

            if (down || up)
            {
                var key = (KeyboardData)Marshal.PtrToStructure(
                    lParam, typeof(KeyboardData));

                if (key.vkCode == 0x20) // Space
                {
                    if (down && (swallowSpace || IsWindowsKeyDown()))
                    {
                        swallowSpace = true;
                        return new IntPtr(1);
                    }

                    if (up && swallowSpace)
                    {
                        swallowSpace = false;
                        return new IntPtr(1);
                    }
                }
            }
        }

        return CallNextHookEx(hook, code, wParam, lParam);
    }

    public static void Run()
    {
        hook = SetWindowsHookEx(WH_KEYBOARD_LL, callback, GetModuleHandle(null), 0);
        if (hook == IntPtr.Zero)
            throw new InvalidOperationException("Could not install the keyboard hook.");

        Console.WriteLine("Win+Space is disabled. Leave this window open; press Ctrl+C to stop.");

        try
        {
            Message msg;
            while (GetMessage(out msg, IntPtr.Zero, 0, 0) > 0)
            {
                TranslateMessage(ref msg);
                DispatchMessage(ref msg);
            }
        }
        finally
        {
            UnhookWindowsHookEx(hook);
        }
    }
}
'@

Add-Type -TypeDefinition $source -Language CSharp
[WinSpaceBlocker]::Run()