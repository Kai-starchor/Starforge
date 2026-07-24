//! Specifies the class styles for a window class.
//!
//! https://learn.microsoft.com/windows/win32/winmsg/window-class-styles

pub const Val = u32;

/// Aligns the window's client area on a byte boundary in the x direction.
/// This style affects window width and horizontal placement.
pub const CS_BYTEALIGNCLIENT: Val = 0x0000_1000;

/// Aligns the window on a byte boundary in the x direction.
/// This style affects window width and horizontal placement.
pub const CS_BYTEALIGNWINDOW: Val = 0x0000_2000;

/// Allocates one device context to be shared by all windows in the class.
/// Do not combine with `WS_EX_COMPOSITED` or `WS_EX_LAYERED`.
pub const CS_CLASSDC: Val = 0x0000_0040;

/// Sends a double-click message to the window procedure when the user double-clicks the mouse
/// while the cursor is within a window belonging to the class.
pub const CS_DBLCLKS: Val = 0x0000_0008;

/// Drops a shadow on the class's windows.
/// Supported primarily on top-level windows and where visual effects are enabled.
pub const CS_DROPSHADOW: Val = 0x0002_0000;

/// Indicates that the window class is an application global class.
pub const CS_GLOBALCLASS: Val = 0x0000_4000;

/// Redraws the entire window if a movement or size adjustment changes the client area's width.
/// This can increase repaint cost during resize.
pub const CS_HREDRAW: Val = 0x0000_0002;

/// Disables `Close` on the window menu.
pub const CS_NOCLOSE: Val = 0x0000_0200;

/// Allocates a unique device context for each window in the class.
/// Do not combine with `WS_EX_COMPOSITED` or `WS_EX_LAYERED`.
pub const CS_OWNDC: Val = 0x0000_0020;

/// Sets the clipping rectangle of child windows to the parent window's clip rectangle so the child
/// can draw on the parent.
/// Use carefully because drawing/clipping interactions become less intuitive.
/// Do not combine with `WS_EX_COMPOSITED`.
pub const CS_PARENTDC: Val = 0x0000_0080;

/// Saves, as a bitmap, the portion of the screen image obscured by a window of this class.
/// Useful for small, temporary windows, but memory cost grows with covered area.
pub const CS_SAVEBITS: Val = 0x0000_0800;

/// Redraws the entire window if a movement or size adjustment changes the client area's height.
/// This can increase repaint cost during resize.
pub const CS_VREDRAW: Val = 0x0000_0001;

/// Extra style present in winuser.h but not listed in the linked class-style page constants table.
/// Enables support for Input Method Editor (IME) windows.
pub const CS_IME: Val = 0x0001_0000;

pub fn aggregate(styles: []const Val) Val {
    var merged: Val = 0;
    for (styles) |style| merged |= style;
    return merged;
}
