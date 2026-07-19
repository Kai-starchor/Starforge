//! A stable identifier for a type in the `Type.Registry`.

const std = @import("std");

const base = @import("../root.zig");
const Type = base.Type;

pub const Val = usize;
pub const INVALID_ID: Val = std.math.maxInt(Val);

val: Val = INVALID_ID,
registry: *const Type.Registry,

/// Equality check based on both the ID value and the registry pointer.
pub fn eql(self: @This(), other: @This()) bool {
    return self.val == other.val and self.registry == other.registry;
}

/// Gets the metadata for this type ID from the registry.
pub fn meta(self: @This()) Type.Meta {
    std.debug.assert(self.val < self.registry.meta_list.items.len);
    return self.registry.meta_list.items[self.val];
}

pub const ValidateError = error{
    /// The value of the Type.Id is out of bounds.
    InvalidIdVal,
};

pub fn validate(self: @This()) ValidateError!void {
    if (self.val >= self.registry.meta_list.items.len) {
        return ValidateError.InvalidIdVal;
    }
}

pub fn isValid(self: @This()) bool {
    self.validate() catch return false;
    return true;
}

const expect = std.testing.expect;

test "equality includes registry identity" {
    var registry_a = Type.Registry.init(std.testing.allocator);
    defer registry_a.deinit();

    var registry_b = Type.Registry.init(std.testing.allocator);
    defer registry_b.deinit();

    const id_a = try registry_a.register(.init(u8), null);
    const id_b = try registry_b.register(.init(u8), null);

    try expect(!id_a.eql(id_b));
}

test "validate type id" {
    var registry = Type.Registry.init(std.testing.allocator);
    defer registry.deinit();

    const id = try registry.register(.init(u32), null);
    try expect(id.isValid());

    const invalid_id = Type.Id{ .val = INVALID_ID, .registry = &registry };
    try expect(!invalid_id.isValid());
}
