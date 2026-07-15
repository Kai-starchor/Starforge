//! A string type that uses small string optimization (SSO) for short strings.
//! The maximum length of a string that can be stored in SSO is `MAX_SSO_LEN`.
//! At non-SSO, the max capacity is 2^(size-8), 2^24=16MB, 2^56=72PB.

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const MAX_SSO_LEN = @sizeOf(usize) * 3 - 1;

/// SSO: |MAX_SSO_LEN bytes|len:7 bits|is_sso:1 bit|
/// Non-SSO: |ptr:usize|len:usize|capacity:u(size-8)|reserved: 7 bits|is_sso:1 bit|
_buf: [3 * @sizeOf(usize)]u8,

const SsoView = packed struct(u8) {
    sso_len: u7,
    is_sso: bool,
};

/// Check if the string is using small string optimization (SSO).
pub fn isSso(self: @This()) bool {
    const view: SsoView = @bitCast(self._buf[MAX_SSO_LEN]);
    return view.is_sso;
}

/// Get the string as a slice of bytes.
pub fn slice(self: *const @This()) []const u8 {
    if (self.isSso()) {
        return self._buf[0..self.len()];
    }
    const ptr_int = std.mem.readInt(usize, self._buf[0..@sizeOf(usize)], .little);
    const ptr: [*]const u8 = @ptrFromInt(ptr_int);
    return ptr[0..self.len()];
}

/// Get the string as a mutable slice of bytes.
pub fn sliceMut(self: *@This()) []u8 {
    if (self.isSso()) {
        return self._buf[0..self.len()];
    }
    const ptr_int = std.mem.readInt(usize, self._buf[0..@sizeOf(usize)], .little);
    const ptr: [*]u8 = @ptrFromInt(ptr_int);
    return ptr[0..self.len()];
}

pub fn len(self: @This()) usize {
    if (self.isSso()) {
        const view: SsoView = @bitCast(self._buf[MAX_SSO_LEN]);
        return @intCast(view.sso_len);
    }
    return std.mem.readInt(usize, self._buf[@sizeOf(usize)..][0..@sizeOf(usize)], .little);
}

pub fn capacity(self: @This()) usize {
    if (self.isSso()) {
        return MAX_SSO_LEN;
    }
    const CapInt = std.meta.Int(.unsigned, @bitSizeOf(usize) - 8);
    const view = self._buf[2 * @sizeOf(usize) ..][0..(@sizeOf(usize) - 1)];
    const rv = std.mem.readInt(CapInt, view, .little);
    return rv;
}

/// Create an empty string.
pub fn empty() @This() {
    var s: @This() = undefined;
    const view: SsoView = .{ .sso_len = 0, .is_sso = true };
    s._buf[MAX_SSO_LEN] = @bitCast(view);
    return s;
}

/// Check if the string is empty.
pub fn isEmpty(self: @This()) bool {
    return self.len() == 0;
}

/// Create a string from a slice of bytes.
/// If the length of the slice is LE `MAX_SSO_LEN`, the string will use SSO.
/// Otherwise, the string will allocate memory on the heap using the provided allocator.
pub fn fromSlice(allocator: Allocator, str: []const u8) Allocator.Error!@This() {
    if (str.len <= MAX_SSO_LEN) {
        var s: @This() = undefined;
        @memcpy(s._buf[0..str.len], str);
        const view: SsoView = .{ .sso_len = @intCast(str.len), .is_sso = true };
        s._buf[MAX_SSO_LEN] = @bitCast(view);
        return s;
    } else {
        var s: @This() = undefined;
        const buffer = try allocator.alloc(u8, str.len);
        @memcpy(buffer, str);
        const ptr_int = @intFromPtr(buffer.ptr);
        std.mem.writeInt(usize, s._buf[0..@sizeOf(usize)], ptr_int, .little);

        std.mem.writeInt(usize, s._buf[@sizeOf(usize)..][0..@sizeOf(usize)], str.len, .little);

        const CapInt = std.meta.Int(.unsigned, @bitSizeOf(usize) - 8);
        const cap: CapInt = @intCast(str.len);
        const cap_buf = s._buf[2 * @sizeOf(usize) ..][0..(@sizeOf(usize) - 1)];
        std.mem.writeInt(CapInt, cap_buf, cap, .little);

        const view: SsoView = .{ .sso_len = 0, .is_sso = false };
        s._buf[MAX_SSO_LEN] = @bitCast(view);
        return s;
    }
}

pub fn deinit(self: *@This(), allocator: Allocator) void {
    if (!self.isSso()) {
        const ptr_int = std.mem.readInt(usize, self._buf[0..@sizeOf(usize)], .little);
        const ptr: [*]u8 = @ptrFromInt(ptr_int);
        allocator.free(ptr[0..self.capacity()]);
    }
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

test "empty string is empty" {
    const s = @This().empty();
    try std.testing.expect(s.isEmpty());
    try std.testing.expect(s.len() == 0);
}

test "string from slice using SSO" {
    const allocator = std.testing.allocator;
    const str = "Hello, Zig!";
    var s = try @This().fromSlice(allocator, str);
    defer s.deinit(allocator);

    try expect(!s.isEmpty());
    try expectEqual(s.len(), str.len);
    try expectEqualStrings(s.slice(), str);
    try expectEqual(s.capacity(), @This().MAX_SSO_LEN);
    try expect(s.isSso());
}

test "string from slice using heap allocation" {
    const allocator = std.testing.allocator;
    const str = "This is a long string that exceeds the SSO limit.";
    var s = try @This().fromSlice(allocator, str);
    defer s.deinit(allocator);

    try expect(!s.isEmpty());
    try expectEqual(s.len(), str.len);
    try expectEqualStrings(s.slice(), str);
    try expectEqual(s.capacity(), str.len);
    try expect(!s.isSso());
}

test "edit string slice using SSO" {
    const allocator = std.testing.allocator;
    const str = "Hello, Zig!";
    var s = try @This().fromSlice(allocator, str);
    defer s.deinit(allocator);

    var mut = s.sliceMut();
    mut[0] = 'h';
    try expectEqualStrings(s.slice(), "hello, Zig!");
}

test "edit string slice using heap allocation" {
    const allocator = std.testing.allocator;
    const str = "This is a long string that exceeds the SSO limit.";
    var s = try @This().fromSlice(allocator, str);
    defer s.deinit(allocator);

    var mut = s.sliceMut();
    mut[0] = 't';
    try expectEqualStrings(s.slice(), "this is a long string that exceeds the SSO limit.");
}
