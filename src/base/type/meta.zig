//! Metadata for a type in the `Type.Registry`.

const std = @import("std");

const base = @import("../root.zig");
const Type = base.Type;

/// The type address is used as a key for registration and lookup, but is not guaranteed to be
/// dense or ordered.
addr: Type.Address = .invalid,
/// The size of the type.
size: usize = 0,
/// The alignment of the type.
alignment: usize = 0,
/// The name of the type.
name: []const u8 = "",

pub fn init(comptime T: type) @This() {
    return .{
        .addr = Type.Address.of(T),
        .size = @sizeOf(T),
        .alignment = @alignOf(T),
        .name = @typeName(T),
    };
}

/// Equality check based on all fields, including the name string.
pub fn eql(self: @This(), other: @This()) bool {
    return self.addr.eql(other.addr) and
        self.size == other.size and
        self.alignment == other.alignment and
        std.mem.eql(u8, self.name, other.name);
}

pub const ValidateError =
    Type.Address.ValidateError ||
    error{
        /// If alignment is greater than 0, it must be a power of two.
        AlignNotPowerOfTwo,
        /// If alignment is greater than 0, it must divide the size evenly.
        SizeNotDivisibleByAlign,
        /// If alignment is 0, size must also be 0 (e.g. for void type).
        SizeNotZeroWithZeroAlign,
    };

/// Validates the invariants of the TypeMeta struct.
pub fn validate(self: @This()) ValidateError!void {
    // A valid TypeMeta must have a valid address,
    try self.addr.validate();
    if (self.alignment > 0) {
        if (!std.math.isPowerOfTwo(self.alignment)) {
            return ValidateError.AlignNotPowerOfTwo;
        }
        if (self.size % self.alignment != 0) {
            return ValidateError.SizeNotDivisibleByAlign;
        }
    } else {
        if (self.size > 0) {
            return ValidateError.SizeNotZeroWithZeroAlign;
        }
        // Allow zero sized type like void to be registered.
    }
}

/// Checks if the TypeMeta is valid according to the validate function.
pub fn isValid(self: @This()) bool {
    self.validate() catch return false;
    return true;
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectError = std.testing.expectError;

test "init captures type metadata" {
    const meta = init(u32);

    try expect(meta.addr.eql(Type.Address.of(u32)));
    try expectEqual(@sizeOf(u32), meta.size);
    try expectEqual(@alignOf(u32), meta.alignment);
    try expectEqualStrings(@typeName(u32), meta.name);
    try expect(meta.isValid());
}

test "equality includes every metadata field" {
    const meta = init(u32);
    try expect(meta.eql(meta));

    var ne_meta = meta;

    ne_meta.addr = Type.Address.of(i32);
    try expect(!meta.eql(ne_meta));
    ne_meta = meta;

    ne_meta.size = meta.size + 1;
    try expect(!meta.eql(ne_meta));
    ne_meta = meta;

    ne_meta.alignment = meta.alignment + 1;
    try expect(!meta.eql(ne_meta));
    ne_meta = meta;

    ne_meta.name = "different";
    try expect(!meta.eql(ne_meta));
    ne_meta = meta;
}

test "validate metadata invariants" {
    const valid_meta = init(u32);
    try valid_meta.validate();

    const invalid_address = @This(){ .size = 4, .alignment = 4, .name = "invalid" };
    try expectError(ValidateError.InvalidAddress, invalid_address.validate());
    try expect(!invalid_address.isValid());

    const align_not_2 = @This(){ .addr = Type.Address.of(u8), .size = 6, .alignment = 3 };
    try expectError(ValidateError.AlignNotPowerOfTwo, align_not_2.validate());

    const size_not_div = @This(){ .addr = Type.Address.of(u8), .size = 3, .alignment = 2 };
    try expectError(ValidateError.SizeNotDivisibleByAlign, size_not_div.validate());

    const size_not_zero = @This(){ .addr = Type.Address.of(u8), .size = 1 };
    try expectError(ValidateError.SizeNotZeroWithZeroAlign, size_not_zero.validate());

    const zero_sized_type = init(void);
    try zero_sized_type.validate();
    try expect(zero_sized_type.isValid());
}
