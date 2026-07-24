//! Show state command values for `ShowWindow`.
//!
//! https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-showwindow

pub const Val = i32;

/// Hides the window and activates another window.
pub const SW_HIDE: Val = 0;

/// Activates and displays a window.
/// If minimized/maximized/arranged, it is restored to original size and position.
pub const SW_SHOWNORMAL: Val = 1;

/// Alias of `SW_SHOWNORMAL`.
pub const SW_NORMAL: Val = SW_SHOWNORMAL;

/// Activates the window and displays it as a minimized window.
pub const SW_SHOWMINIMIZED: Val = 2;

/// Activates the window and displays it as a maximized window.
pub const SW_SHOWMAXIMIZED: Val = 3;

/// Alias of `SW_SHOWMAXIMIZED`.
pub const SW_MAXIMIZE: Val = SW_SHOWMAXIMIZED;

/// Displays a window in its most recent size and position without activating it.
pub const SW_SHOWNOACTIVATE: Val = 4;

/// Activates the window and displays it in its current size and position.
pub const SW_SHOW: Val = 5;

/// Minimizes the specified window and activates the next top-level window in Z order.
pub const SW_MINIMIZE: Val = 6;

/// Displays the window as minimized without activating it.
pub const SW_SHOWMINNOACTIVE: Val = 7;

/// Displays the window in its current size and position without activating it.
pub const SW_SHOWNA: Val = 8;

/// Activates and displays the window.
/// If minimized/maximized/arranged, it is restored to original size and position.
pub const SW_RESTORE: Val = 9;

/// Uses the show state from the launcher-provided `STARTUPINFO`.
pub const SW_SHOWDEFAULT: Val = 10;

/// Minimizes a window even if the owning thread is not responding.
/// This should be used only when minimizing windows from a different thread.
pub const SW_FORCEMINIMIZE: Val = 11;
