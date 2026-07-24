pub const WindowStyle = @import("window_style.zig");

pub extern "user32" fn CreateWindowExW(
    dwExStyle: WindowStyle.Extend,
    lpClassName: ?[*:0]align(1) const u16,
    lpWindowName: ?[*:0]const u16,
    dwStyle: WindowStyle,
    X: i32,
    Y: i32,
    nWidth: i32,
    nHeight: i32,
    hWndParent: ?H_WND,
    hMenu: ?H_MENU,
    hInstance: ?H_INSTANCE,
    lpParam: ?*anyopaque,
) callconv(.winapi) ?H_WND;

pub const H_WND = *opaque {};
pub const H_MENU = *opaque {};
pub const H_INSTANCE = *opaque {};
