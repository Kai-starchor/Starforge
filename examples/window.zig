const std = @import("std");
const builtin = @import("builtin");

const starforge = @import("starforge");

const windows = starforge.window.windows;
const kernel32 = windows.kernel32;
const user32 = windows.user32;

const WM_QUIT: u32 = 0x0012;

fn windowProc(
    hWnd: user32.HWND,
    uMsg: u32,
    wParam: user32.WPARAM,
    lParam: user32.LPARAM,
) callconv(.winapi) user32.LRESULT {
    if (uMsg == user32.WM_DESTROY) {
        user32.PostQuitMessage(0);
        return 0;
    }

    return user32.DefWindowProcW(hWnd, uMsg, wParam, lParam);
}

pub fn main() !void {
    if (builtin.os.tag != .windows) {
        return error.UnsupportedTarget;
    }

    const class_name = std.unicode.utf8ToUtf16LeStringLiteral("StarforgeWindowClass");
    const window_title = std.unicode.utf8ToUtf16LeStringLiteral("Starforge Window");

    const hmodule = kernel32.GetModuleHandleW(null) orelse return error.GetModuleHandleFailed;
    const instance: user32.HINSTANCE = @ptrCast(hmodule);

    var wc = user32.WNDCLASSEXW{
        .style = user32.ClassStyle.CS_HREDRAW | user32.ClassStyle.CS_VREDRAW,
        .lpfnWndProc = windowProc,
        .hInstance = instance,
        .hIcon = null,
        .hCursor = null,
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = class_name,
        .hIconSm = null,
    };

    if (user32.RegisterClassExW(&wc) == 0) {
        return error.RegisterClassFailed;
    }

    const hWnd = user32.CreateWindowExW(
        0,
        class_name,
        window_title,
        user32.WindowStyle.WS_OVERLAPPEDWINDOW,
        user32.CW_USEDEFAULT,
        user32.CW_USEDEFAULT,
        800,
        600,
        null,
        null,
        instance,
        null,
    ) orelse return error.CreateWindowFailed;

    _ = user32.ShowWindow(hWnd, user32.ShowWindowCmd.SW_SHOW);
    _ = user32.UpdateWindow(hWnd);

    var msg: user32.MSG = std.mem.zeroes(user32.MSG);

    while (true) {
        while (user32.PeekMessageW(&msg, null, 0, 0, user32.PeekMessageRemove.PM_REMOVE) != 0) {
            if (msg.message == WM_QUIT) return;
            _ = user32.TranslateMessage(&msg);
            _ = user32.DispatchMessageW(&msg);
        }

        std.Thread.yield() catch {};
    }
}
