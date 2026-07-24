//! The following are the extended window styles, these can be used along with the `CreateWindowExW`
//! functions.
//!
//! https://learn.microsoft.com/windows/win32/winmsg/extended-window-styles

flags: u32,

/// The window accepts drag-drop files.
pub const WS_EX_ACCEPTFILES = @This(){ .flags = 0x0000_0010 };

/// Forces a top-level window onto the taskbar when the window is visible.
pub const WS_EX_APPWINDOW = @This(){ .flags = 0x0004_0000 };

/// The window has a border with a sunken edge.
pub const WS_EX_CLIENTEDGE = @This(){ .flags = 0x0000_0200 };

/// Paints all descendants bottom-to-top using double-buffering.
/// Cannot be used with class styles `CS_OWNDC`, `CS_CLASSDC`, or `CS_PARENTDC`.
pub const WS_EX_COMPOSITED = @This(){ .flags = 0x0200_0000 };

/// Includes a question mark in the title bar.
/// Cannot be combined with `WS_MAXIMIZEBOX` or `WS_MINIMIZEBOX`.
pub const WS_EX_CONTEXTHELP = @This(){ .flags = 0x0000_0400 };

/// The window itself contains child windows that should take part in dialog navigation.
/// The system recursively searches child windows for the next tab-stop.
pub const WS_EX_CONTROLPARENT = @This(){ .flags = 0x0001_0000 };

/// The window has a double border; can be combined with `WS_CAPTION` for a title bar.
pub const WS_EX_DLGMODALFRAME = @This(){ .flags = 0x0000_0001 };

/// The window is layered.
/// Before Windows 8, this style is supported only for top-level windows.
pub const WS_EX_LAYERED = @This(){ .flags = 0x0008_0000 };

/// If the shell language supports it, the horizontal origin is on the right edge.
pub const WS_EX_LAYOUTRTL = @This(){ .flags = 0x0040_0000 };

/// The window has generic left-aligned properties. This is the default.
pub const WS_EX_LEFT = @This(){ .flags = 0x0000_0000 };

/// If the shell language supports it, the vertical scroll bar is left of the client area.
pub const WS_EX_LEFTSCROLLBAR = @This(){ .flags = 0x0000_4000 };

/// Window text is displayed using left-to-right reading order. This is the default.
pub const WS_EX_LTRREADING = @This(){ .flags = 0x0000_0000 };

/// The window is an MDI child window.
pub const WS_EX_MDICHILD = @This(){ .flags = 0x0000_0040 };

/// A top-level window created with this style does not become the foreground window when clicked.
/// It does not appear on the taskbar by default; use `WS_EX_APPWINDOW` to force taskbar presence.
pub const WS_EX_NOACTIVATE = @This(){ .flags = 0x0800_0000 };

/// Child windows do not inherit this window's layout.
pub const WS_EX_NOINHERITLAYOUT = @This(){ .flags = 0x0010_0000 };

/// The child window does not send `WM_PARENTNOTIFY` messages to its parent on creation/destruction.
pub const WS_EX_NOPARENTNOTIFY = @This(){ .flags = 0x0000_0004 };

/// The window does not render to a redirection surface.
/// Use for windows with no visible content to avoid unnecessary redirection bitmap allocation.
pub const WS_EX_NOREDIRECTIONBITMAP = @This(){ .flags = 0x0020_0000 };

/// A combined style of `WS_EX_WINDOWEDGE` and `WS_EX_CLIENTEDGE`.
pub const WS_EX_OVERLAPPEDWINDOW = aggregate(&.{
    WS_EX_WINDOWEDGE,
    WS_EX_CLIENTEDGE,
});

/// A combined style of `WS_EX_WINDOWEDGE`, `WS_EX_TOOLWINDOW`, and `WS_EX_TOPMOST`.
pub const WS_EX_PALETTEWINDOW = aggregate(&.{
    WS_EX_WINDOWEDGE,
    WS_EX_TOOLWINDOW,
    WS_EX_TOPMOST,
});

/// The window has generic right-aligned properties.
/// This style has effect only when shell language supports bidirectional reading order.
pub const WS_EX_RIGHT = @This(){ .flags = 0x0000_1000 };

/// The vertical scroll bar is to the right of the client area. This is the default.
pub const WS_EX_RIGHTSCROLLBAR = @This(){ .flags = 0x0000_0000 };

/// Window text is displayed using right-to-left reading order.
/// This style has effect only when shell language supports bidirectional reading order.
pub const WS_EX_RTLREADING = @This(){ .flags = 0x0000_2000 };

/// The window has a three-dimensional border style intended for non-interactive items.
pub const WS_EX_STATICEDGE = @This(){ .flags = 0x0002_0000 };

/// The window is intended to be used as a floating toolbar.
/// It has a shorter title bar and does not appear in the taskbar or Alt-Tab by default.
pub const WS_EX_TOOLWINDOW = @This(){ .flags = 0x0000_0080 };

/// The window should be placed above all non-topmost windows and stay above them.
pub const WS_EX_TOPMOST = @This(){ .flags = 0x0000_0008 };

/// The window appears transparent because siblings beneath it are painted first.
/// This behavior applies to sibling windows created by the same thread.
pub const WS_EX_TRANSPARENT = @This(){ .flags = 0x0000_0020 };

/// The window has a raised edge border.
pub const WS_EX_WINDOWEDGE = @This(){ .flags = 0x0000_0100 };

pub fn aggregate(styles: []const @This()) @This() {
    var merged: u32 = 0;
    for (styles) |style| merged |= style.flags;
    return .{ .flags = merged };
}
