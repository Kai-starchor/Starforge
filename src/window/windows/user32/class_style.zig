//! Specifies the class styles for a window class.
//!
//! https://learn.microsoft.com/windows/win32/winmsg/window-class-styles

flags: u32,

/// Aligns the window's client area on a byte boundary in the x direction.
/// This style affects window width and horizontal placement.
pub const CS_BYTEALIGNCLIENT = @This(){ .flags = 0x1000 };

/// Aligns the window on a byte boundary in the x direction.
/// This style affects window width and horizontal placement.
pub const CS_BYTEALIGNWINDOW = @This(){ .flags = 0x2000 };

/// Allocates one device context to be shared by all windows in the class.
/// Do not combine with `WS_EX_COMPOSITED` or `WS_EX_LAYERED`.
pub const CS_CLASSDC = @This(){ .flags = 0x0040 };

/// Sends a double-click message to the window procedure when the user double-clicks the mouse
/// while the cursor is within a window belonging to the class.
pub const CS_DBLCLKS = @This(){ .flags = 0x0008 };

/// Drops a shadow on the class's windows.
/// Supported primarily on top-level windows and where visual effects are enabled.
pub const CS_DROPSHADOW = @This(){ .flags = 0x0002_0000 };

/// Indicates that the window class is an application global class.
pub const CS_GLOBALCLASS = @This(){ .flags = 0x4000 };

/// Redraws the entire window if a movement or size adjustment changes the client area's width.
/// This can increase repaint cost during resize.
pub const CS_HREDRAW = @This(){ .flags = 0x0002 };

/// Disables `Close` on the window menu.
pub const CS_NOCLOSE = @This(){ .flags = 0x0200 };

/// Allocates a unique device context for each window in the class.
/// Do not combine with `WS_EX_COMPOSITED` or `WS_EX_LAYERED`.
pub const CS_OWNDC = @This(){ .flags = 0x0020 };

/// Sets the clipping rectangle of child windows to the parent window's clip rectangle so the child
/// can draw on the parent.
/// Use carefully because drawing/clipping interactions become less intuitive.
/// Do not combine with `WS_EX_COMPOSITED`.
pub const CS_PARENTDC = @This(){ .flags = 0x0080 };

/// Saves, as a bitmap, the portion of the screen image obscured by a window of this class.
/// Useful for small, temporary windows, but memory cost grows with covered area.
pub const CS_SAVEBITS = @This(){ .flags = 0x0800 };

/// Redraws the entire window if a movement or size adjustment changes the client area's height.
/// This can increase repaint cost during resize.
pub const CS_VREDRAW = @This(){ .flags = 0x0001 };

/// Extra style present in winuser.h but not listed in the linked class-style page constants table.
/// Enables support for Input Method Editor (IME) windows.
pub const CS_IME = @This(){ .flags = 0x0001_0000 };

pub fn aggregate(styles: []const @This()) @This() {
    var merged: u32 = 0;
    for (styles) |style| merged |= style.flags;
    return .{ .flags = merged };
}
