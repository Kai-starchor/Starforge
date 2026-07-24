pub const WindowStyle = @import("window_style.zig");
pub const ClassStyle = @import("class_style.zig");

/// Contains window class information. It is used with the `RegisterClassEx` and `GetClassInfoEx`
/// functions.
///
/// https://learn.microsoft.com/windows/win32/api/winuser/ns-winuser-wndclassexw
pub const WindowClassExW = struct {
    /// The size, in bytes, of this structure.
    cb_size: u32 = @sizeOf(WindowClassExW),
    /// The class style(s).
    style: ClassStyle,
    /// A pointer to the window procedure.
    // lpfnWndProc: ?WNDPROC, // TODO
    cbClsExtra: i32,
    cbWndExtra: i32,
    hInstance: ?HINSTANCE,
    // hIcon: ?HICON,
    // hCursor: ?HCURSOR,
    // hbrBackground: ?HBRUSH,
    lpszMenuName: ?[*:0]const u16,
    lpszClassName: ?[*:0]const u16,
    // hIconSm: ?HICON,
};

/// https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-registerclassexw
pub extern "user32" fn RegisterClassExW(
    lp_wnd_class: *WindowClassExW,
) callconv(.winapi) u16;

/// https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-createwindowexw
pub extern "user32" fn CreateWindowExW(
    dw_ex_style: WindowStyle.Extend,
    lp_class_name: ?[*:0]align(1) const u16,
    lp_window_name: ?[*:0]const u16,
    dw_style: WindowStyle,
    x: i32,
    y: i32,
    n_width: i32,
    n_height: i32,
    h_wnd_parent: ?HWND,
    h_menu: ?HMENU,
    h_instance: ?HINSTANCE,
    lp_param: ?*anyopaque,
) callconv(.winapi) ?HWND;

pub const HWND = *opaque {};
pub const HMENU = *opaque {};
pub const HINSTANCE = *opaque {};
