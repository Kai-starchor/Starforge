//! A stable identifier for a component in the `Component.Registry`.

const std = @import("std");

const root = @import("../root.zig");
const Component = root.Component;

pub const Val = usize;
pub const INVALID_ID: Val = std.math.maxInt(Val);

val: Val = INVALID_ID,
registry: *const Component.Registry,

/// Equality check based on both the ID value and the registry pointer.
pub fn eql(self: @This(), other: @This()) bool {
    return self.val == other.val and self.registry == other.registry;
}

/// Gets the metadata for this component ID from the registry.
pub fn meta(self: @This()) Component.Meta {
    std.debug.assert(self.val < self.registry.meta_list.items.len);
    return self.registry.meta_list.items[self.val];
}

const ValidateError = error{
    /// The value of the TypeId is out of bounds.
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
    var type_registry = root.base.Type.Registry.init(std.testing.allocator);
    defer type_registry.deinit();
    const type_id = try type_registry.register(.init(u8), null);
    const component_meta = Component.Meta{ .type_id = type_id, .interface = .Trivial };

    var registry_a = Component.Registry.init(std.testing.allocator);
    defer registry_a.deinit();
    var registry_b = Component.Registry.init(std.testing.allocator);
    defer registry_b.deinit();

    const id_a = try registry_a.register(component_meta, null);
    const id_b = try registry_b.register(component_meta, null);

    try expect(!id_a.eql(id_b));
}

test "validate component id" {
    var type_registry = root.base.Type.Registry.init(std.testing.allocator);
    defer type_registry.deinit();
    const type_id = try type_registry.register(.init(u32), null);

    var registry = Component.Registry.init(std.testing.allocator);
    defer registry.deinit();
    const id = try registry.register(.{ .type_id = type_id, .interface = .Trivial }, null);
    try expect(id.isValid());

    const invalid_id = Component.Id{ .val = INVALID_ID, .registry = &registry };
    try expect(!invalid_id.isValid());
}
