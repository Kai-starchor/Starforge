pub const WindowStyle = @import("window_style.zig");
pub const ClassStyle = @import("class_style.zig");

pub const WPARAM = usize;
pub const LPARAM = u64;
pub const LRESULT = u64;

pub const HWND = *opaque {};
pub const HMENU = *opaque {};
pub const HINSTANCE = *opaque {};
pub const HICON = *opaque {};
pub const HCURSOR = *opaque {};
pub const HBRUSH = *opaque {};

/// https://github.com/tpn/winsdk-10/blob/master/Include/10.0.10240.0/um/WinUser.h
pub const DLGWINDOWEXTRA = 30;

/// A callback function, which you define in your application, that processes messages sent to a
/// window.
/// The return value is the result of the message processing, and depends on the message sent.
///
/// https://learn.microsoft.com/windows/win32/api/winuser/nc-winuser-wndproc
pub const WNDPROC = *const fn (
    /// A handle to the window.
    hWnd: HWND,
    /// The message.
    uMsg: u32,
    /// Additional message information.
    wParam: WPARAM,
    /// Additional message information.
    lParam: LPARAM,
) callconv(.winapi) LRESULT;

/// Contains window class information. It is used with the `RegisterClassEx` and `GetClassInfoEx`
/// functions.
///
/// https://learn.microsoft.com/windows/win32/api/winuser/ns-winuser-wndclassexw
pub const WNDCLASSEXW = extern struct {
    /// The size, in bytes, of this structure.
    cbSize: u32 = @sizeOf(WNDCLASSEXW),
    /// The class style(s).
    style: ClassStyle.Val,
    /// A pointer to the window procedure, callback function that processes messages.
    lpfnWndProc: ?WNDPROC,
    /// The number of extra bytes to allocate following the window-class structure. The system
    /// initializes the bytes to zero.
    cbClsExtra: i32 = 0,
    /// The number of extra bytes to allocate following the window instance. The system initializes
    /// the bytes to zero.
    /// If an application uses `WNDCLASSEX` to register a dialog box created by using the CLASS
    /// directive in the resource file, it must set this member to `DLGWINDOWEXTRA`.
    cbWndExtra: i32 = 0,
    /// A handle to the instance that contains the window procedure for the class.
    hInstance: ?HINSTANCE,
    /// A handle to the class icon.
    hIcon: ?HICON,
    /// A handle to the class cursor.
    hCursor: ?HCURSOR,
    /// A handle to the class background brush.
    hbrBackground: ?HBRUSH,
    /// Pointer to a null-terminated utf-16 string that specifies the resource name of the class
    /// menu, as the name appears in the resource file.
    lpszMenuName: ?[*:0]const u16,
    /// A pointer to a null-terminated utf-16 string or is an atom. As an atom, it doesn't naturally
    /// have an alignment requirement, thus it is aligned to 1 byte.
    lpszClassName: ?[*:0]align(1) const u16,
    /// A handle to a small icon that is associated with the window class.
    hIconSm: ?HICON,
};

/// https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-registerclassexw
pub extern "user32" fn RegisterClassExW(
    lpWndClass: *WNDCLASSEXW,
) callconv(.winapi) u16;

/// https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-createwindowexw
pub extern "user32" fn CreateWindowExW(
    dwExStyle: WindowStyle.Extend.Val,
    lpClassName: ?[*:0]align(1) const u16,
    lpWindowName: ?[*:0]const u16,
    dwStyle: WindowStyle.Val,
    x: i32,
    y: i32,
    nWidth: i32,
    nHeight: i32,
    hWndParent: ?HWND,
    hMenu: ?HMENU,
    hInstance: ?HINSTANCE,
    lpParam: ?*anyopaque,
) callconv(.winapi) ?HWND;
