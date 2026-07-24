pub const WindowStyle = @import("window_style.zig");
pub const ClassStyle = @import("class_style.zig");
pub const MessageType = @import("message_type.zig");
pub const ShowWindowCmd = @import("show_window_cmd.zig");

pub const BOOL = i32;
pub const WPARAM = usize;
pub const LPARAM = isize;
pub const LRESULT = LPARAM;

pub const HWND = *opaque {};
pub const HMENU = *opaque {};
pub const HINSTANCE = *opaque {};
pub const HICON = *opaque {};
pub const HCURSOR = *opaque {};
pub const HBRUSH = *opaque {};

/// See `WNDCLASSEXW.cbWndExtra` for more information.
///
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

/// Sent when a window is being destroyed. It is sent to the window procedure of the window being
/// destroyed after the window is removed from the screen.
///
///  https://learn.microsoft.com/en-us/windows/win32/winmsg/wm-destroy
pub const WM_DESTROY: u32 = 0x0002;

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

/// Registers a window class for subsequent use in calls to the `CreateWindowExW` function.
///
///  https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-registerclassexw
pub extern "user32" fn RegisterClassExW(lpWndClass: *WNDCLASSEXW) callconv(.winapi) u16;

/// Creates an overlapped, pop-up, or child window with an extended window style.
///
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

/// Create window use default, see the document link of `CreateWindowExW`.
pub const CW_USEDEFAULT: i32 = -2147483648;

/// Sets the specified window's show state.
///
/// https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-showwindow
pub extern "user32" fn ShowWindow(hWnd: HWND, nCmdShow: ShowWindowCmd.Val) callconv(.winapi) BOOL;

/// Updates the client area of the specified window by sending a `WM_PAINT` message to the window if
/// the window's update region is not empty.
///
/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-updatewindow
pub extern "user32" fn UpdateWindow(hWnd: HWND) callconv(.winapi) BOOL;

/// Contains message information from a thread's message queue.
///
/// https://learn.microsoft.com/windows/win32/api/winuser/ns-winuser-msg
pub const MSG = extern struct {
    /// A handle to the window whose window procedure receives the message.
    hwnd: ?HWND,
    /// The message identifier. Applications can only use the low word; the high word is reserved by
    /// the system.
    message: u32,
    /// Additional information about the message.
    wParam: WPARAM,
    /// Additional information about the message.
    lParam: LPARAM,
    /// The time at which the message was posted.
    time: u32,
    /// The cursor position, in screen coordinates, when the message was posted.
    pt: POINT,
    /// Ignored, used by the system.
    _lPrivate: u32,
};

pub const POINT = extern struct { x: i32, y: i32 };

/// Dispatches incoming non queued messages, checks the thread message queue for a posted message,
/// and retrieves the message (if any exist).
///
/// https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-peekmessagew
pub extern "user32" fn PeekMessageW(
    lpMsg: *MSG,
    hWnd: ?HWND,
    wMsgFilterMin: u32,
    wMsgFilterMax: u32,
    /// Specifies how messages are to be handled.
    wRemoveMsg: PeekMessageRemove.Val,
) callconv(.winapi) BOOL;

pub const PeekMessageRemove = struct {
    pub const Val = u32;

    /// Messages are not removed from the queue after processing by PeekMessage.
    pub const PM_NONREMOVE: Val = 0x0000;
    /// Messages are removed from the queue after processing by PeekMessage.
    pub const PM_REMOVE: Val = 0x0001;
    /// Prevents the system from releasing any thread that is waiting for the caller to go idle.
    pub const PM_NOYIELD: Val = 0x0002;

    // By default, all message types are processed. To specify that only certain message should be
    // processed, specify one or more of the following values.

    /// Process mouse and keyboard messages.
    pub const PS_QS_INPUT: Val = MessageType.QS_INPUT << 16;
    /// Process all posted messages, including timers and hotkeys.
    pub const PS_QS_POSTMESSAGE: Val =
        (MessageType.QS_POSTMESSAGE | MessageType.QS_HOTKEY | MessageType.QS_TIMER) << 16;
    /// Process paint messages.
    pub const PS_QS_PAINT: Val = MessageType.QS_PAINT << 16;
    /// Process all sent messages.
    pub const PS_QS_SENDMESSAGE: Val = MessageType.QS_SENDMESSAGE << 16;
};

/// Translates virtual-key messages into character messages.
///
/// https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-translatemessage
pub extern "user32" fn TranslateMessage(lpMsg: ?*const MSG) callconv(.winapi) BOOL;

/// Dispatches a message to a window procedure.
///
/// https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-dispatchmessagew
pub extern "user32" fn DispatchMessageW(lpMsg: ?*const MSG) callconv(.winapi) LRESULT;

/// Indicates to the system that a thread has made a request to terminate (quit).
/// It is typically used in response to a `WM_DESTROY` message.
///
/// https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-postquitmessage
pub extern "user32" fn PostQuitMessage(nExitCode: i32) callconv(.winapi) void;

/// Calls the default window procedure to provide default processing for any window messages that an
/// application does not process.
///
/// https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-defwindowprocw
pub extern "user32" fn DefWindowProcW(
    hWnd: ?HWND,
    Msg: u32,
    wParam: WPARAM,
    lParam: LPARAM,
) callconv(.winapi) LRESULT;
