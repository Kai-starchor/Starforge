//! The types of messages found in the calling thread's message queue for `GetQueueStatus` to check.
//!
//! https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-getqueuestatus

pub const Val = u32;

/// A `WM_KEYUP`, `WM_KEYDOWN`, `WM_SYSKEYUP`, or `WM_SYSKEYDOWN` message is in the queue.
pub const QS_KEY: Val = 0x0001;

/// A `WM_MOUSEMOVE` message is in the queue.
pub const QS_MOUSEMOVE: Val = 0x0002;

/// A mouse-button message is in the queue.
pub const QS_MOUSEBUTTON: Val = 0x0004;

/// A posted message (other than the explicitly listed QS categories) is in the queue.
/// Cleared by `GetMessage`/`PeekMessage` regardless of filtering.
pub const QS_POSTMESSAGE: Val = 0x0008;

/// A `WM_TIMER` message is in the queue.
pub const QS_TIMER: Val = 0x0010;

/// A `WM_PAINT` message is in the queue.
pub const QS_PAINT: Val = 0x0020;

/// A message sent by another thread/application is in the queue.
pub const QS_SENDMESSAGE: Val = 0x0040;

/// A `WM_HOTKEY` message is in the queue.
pub const QS_HOTKEY: Val = 0x0080;

/// A posted message (other than listed categories) is in the queue. Cleared only by unfiltered
/// `GetMessage`/`PeekMessage` (`wMsgFilterMin = 0`, `wMsgFilterMax = 0`).
pub const QS_ALLPOSTMESSAGE: Val = 0x0100;

/// Windows XP and newer: A raw input message is in the queue.
pub const QS_RAWINPUT: Val = 0x0400;

/// Windows 8 and newer: A touch input message is in the queue.
pub const QS_TOUCH: Val = 0x0800;

/// Windows 8 and newer: A pointer input message is in the queue.
pub const QS_POINTER: Val = 0x1000;

/// A mouse move or mouse-button message is in the queue.
pub const QS_MOUSE = (QS_MOUSEMOVE | QS_MOUSEBUTTON);

/// Any input message is in the queue.
pub const QS_INPUT = (QS_MOUSE | QS_KEY | QS_RAWINPUT | QS_TOUCH | QS_POINTER);

/// Any input/timer/paint/hotkey/posted message is in the queue.
pub const QS_ALLEVENTS = (QS_INPUT | QS_POSTMESSAGE | QS_TIMER | QS_PAINT | QS_HOTKEY);

/// Any message is in the queue.
pub const QS_ALLINPUT =
    (QS_INPUT | QS_POSTMESSAGE | QS_TIMER | QS_PAINT | QS_HOTKEY | QS_SENDMESSAGE);
