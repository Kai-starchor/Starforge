const std = @import("std");

/// Implement `std.Random` interface using `std.Io` as the source of randomness. It will use
/// `std.Io.random` by default.
///
/// See also `IoSourceSecure`.
pub const IoSource = std.Random.IoSource;

/// Implement `std.Random` interface using `std.Io` as the source of randomness. It will use
/// `std.Io.randomSecure` first and fallback to `std.Io.random` if failed.
///
/// **This implementation doesn't guarantee cryptographic security!**
///
/// Based on `std.Random.IoSource` implementation.
pub const IoSourceSecure = struct {
    io: std.Io,

    pub fn interface(self: *const @This()) std.Random {
        return .{
            .ptr = @constCast(self),
            .fillFn = fill,
        };
    }

    fn fill(ptr: *anyopaque, buffer: []u8) void {
        const self: *const @This() = @ptrCast(@alignCast(ptr));
        self.io.randomSecure(buffer) catch {
            self.io.random(buffer);
        };
    }
};

/// Implement `std.Random` interface using mocked buffer. Useful for testing purposes.
pub const MockSource = struct {
    buffers: []const []const u8,
    index: usize = 0,

    pub fn interface(self: *@This()) std.Random {
        return .{
            .ptr = self,
            .fillFn = fill,
        };
    }

    fn fill(ptr: *anyopaque, buffer: []u8) void {
        const self: *@This() = @ptrCast(@alignCast(ptr));
        @memcpy(buffer, self.buffers[self.index]);
        self.index += 1;
        self.index %= self.buffers.len;
    }
};
