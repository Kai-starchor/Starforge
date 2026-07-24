//! A list of the various styles that can be applied to a window (after the window has been created,
//! these styles cannot be modified, except as noted).
//!
//! https://learn.microsoft.com/windows/win32/winmsg/window-styles

pub const Extend = @import("window_style_extend.zig");

pub const Val = u32;

/// The window has a thin-line border.
pub const WS_BORDER: Val = 0x0080_0000;

/// The window has a title bar (includes the WS_BORDER style).
pub const WS_CAPTION: Val = 0x00C0_0000;

/// The window is a child window. A window with this style cannot have a menu bar.
/// This style cannot be used with the WS_POPUP style.
/// Child windows should use a valid parent handle and are typically clipped to the parent area.
pub const WS_CHILD: Val = 0x4000_0000;

/// Same as `WS_CHILD`.
pub const WS_CHILDWINDOW = WS_CHILD;

/// Excludes the area occupied by child windows when drawing occurs within the parent window.
/// Use this on parent windows to reduce overdraw/flicker when repainting around child controls.
pub const WS_CLIPCHILDREN: Val = 0x0200_0000;

/// Clips child windows relative to each other.
/// Commonly used when sibling child windows overlap to avoid drawing into each other's client area.
pub const WS_CLIPSIBLINGS: Val = 0x0400_0000;

/// The window is initially disabled.
pub const WS_DISABLED: Val = 0x0800_0000;

/// The window has a border of a style typically used with dialog boxes.
/// A window with this style cannot have a title bar.
pub const WS_DLGFRAME: Val = 0x0040_0000;

/// The first control of a group of controls.
/// A group starts at this control and continues until the next control with WS_GROUP.
pub const WS_GROUP: Val = 0x0002_0000;

/// The window has a horizontal scroll bar.
pub const WS_HSCROLL: Val = 0x0010_0000;

/// The window is initially minimized. Same as WS_MINIMIZE.
pub const WS_ICONIC: Val = 0x2000_0000;

/// The window is initially maximized.
/// Applies to top-level windows; child windows do not participate in standard maximize behavior.
pub const WS_MAXIMIZE: Val = 0x0100_0000;

/// The window has a maximize button. Cannot be combined with the `WS_EX_CONTEXTHELP` style.
/// The `WS_SYSMENU` style must also be specified.
pub const WS_MAXIMIZEBOX: Val = 0x0001_0000;

/// The window is initially minimized. Same as WS_ICONIC.
pub const WS_MINIMIZE: Val = 0x2000_0000;

/// The window has a minimize button. The `WS_SYSMENU` style must also be specified.
/// Cannot be combined with the `WS_EX_CONTEXTHELP` style.
pub const WS_MINIMIZEBOX: Val = 0x0002_0000;

/// The window is an overlapped window.
pub const WS_OVERLAPPED: Val = 0x0000_0000;

/// A standard overlapped window.
pub const WS_OVERLAPPEDWINDOW =
    (WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX);

/// The window is a popup window.
/// Cannot be used with `WS_CHILD`; commonly combined with `WS_POPUPWINDOW` for top-level popup UI.
pub const WS_POPUP: Val = 0x8000_0000;

/// A popup window with border and system menu.
pub const WS_POPUPWINDOW = (WS_POPUP | WS_BORDER | WS_SYSMENU);

/// The window has a sizing border. Same as `WS_THICKFRAME`.
pub const WS_SIZEBOX = WS_THICKFRAME;

/// The window has a window menu on its title bar.
/// Required when using `WS_MINIMIZEBOX` or `WS_MAXIMIZEBOX`.
pub const WS_SYSMENU: Val = 0x0008_0000;

/// The window can receive the keyboard focus when the user presses the TAB key.
/// In dialog navigation, pair with `WS_GROUP` to control tab-stop scope.
pub const WS_TABSTOP: Val = 0x0001_0000;

/// The window has a sizing border.
pub const WS_THICKFRAME: Val = 0x0004_0000;

/// The window is an overlapped window. Same as `WS_OVERLAPPED`.
pub const WS_TILED = WS_OVERLAPPED;

/// The window is initially visible.
/// This is an initial state at creation; visibility can still be changed later via `ShowWindow` or
/// `SetWindowPos`.
pub const WS_VISIBLE: Val = 0x1000_0000;

/// The window has a vertical scroll bar.
pub const WS_VSCROLL: Val = 0x0020_0000;

/// Same as `WS_OVERLAPPEDWINDOW`.
pub const WS_TILEDWINDOW = WS_OVERLAPPEDWINDOW;
