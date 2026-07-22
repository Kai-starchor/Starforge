const std = @import("std");
const builtin = @import("builtin");

test "linking to system libraries" {
    if (builtin.os.tag != .windows) {
        @panic("window tests require Windows");
    }

    const Kernel32 = struct {
        extern "kernel32" fn GetCurrentProcessId() callconv(.winapi) u32;
    };
    const User32 = struct {
        extern "user32" fn GetSystemMetrics(nIndex: i32) callconv(.winapi) i32;
    };

    const process_id = Kernel32.GetCurrentProcessId();
    try std.testing.expect(process_id != 0);

    const n_index = 0;
    const screen_width = User32.GetSystemMetrics(n_index);
    try std.testing.expect(screen_width > 0);
}
