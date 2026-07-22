const builtin = @import("builtin");

pub const windows = if (builtin.os.tag == .windows) @import("windows/sys.zig") else struct {};

test {
    _ = windows;
}
