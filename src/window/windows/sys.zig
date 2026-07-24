const std = @import("std");
const builtin = @import("builtin");

pub const kernel32 = @import("kernel32.zig");
pub const user32 = @import("user32/user32.zig");

test "linking to system libraries" {
    if (builtin.os.tag != .windows) {
        @panic("window tests require Windows");
    }

    const User32 = struct {
        extern "user32" fn GetSystemMetrics(nIndex: i32) callconv(.winapi) i32;
    };

    const process_id = kernel32.GetCurrentProcessId();
    try std.testing.expect(process_id != 0);

    const n_index = 0;
    const screen_width = User32.GetSystemMetrics(n_index);
    try std.testing.expect(screen_width > 0);
}
