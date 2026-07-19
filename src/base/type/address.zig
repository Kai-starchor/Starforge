//! A unique identifier of a zig type.

const std = @import("std");

pub const INVALID_ADDRESS: usize = 0;
pub const invalid = @This(){};

val: usize = INVALID_ADDRESS,

/// Address of a static variable in a struct that is instantiated per type.
pub fn of(comptime T: type) @This() {
    const S = struct {
        const Type = T; // Instantiate per type to get unique address
        var dummy: u8 = 0;
    };
    return .{ .val = @intFromPtr(&S.dummy) };
}

/// Equality check based on the address value.
pub fn eql(self: @This(), other: @This()) bool {
    return self.val == other.val;
}

pub const ValidateError = error{
    /// A valid TypeAddress has a non-zero address value.
    InvalidAddress,
};

/// Validates that the TypeAddress has a non-zero address value.
pub fn validate(self: @This()) ValidateError!void {
    if (self.val == INVALID_ADDRESS) {
        return ValidateError.InvalidAddress;
    }
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

/// Checks if the TypeAddress is valid according to the validate function.
pub fn isValid(self: @This()) bool {
    self.validate() catch return false;
    return true;
}

test "stable per type and distinct across different types" {
    const a1 = of(u32);
    const a2 = of(u32);
    const b = of(i32);

    try expectEqual(a1.val, a2.val);
    try expect(a1.val != b.val);
}
