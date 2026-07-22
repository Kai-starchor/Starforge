//! Memory Layout of an archetype. Use SOA (Structure of Arrays) layout for better cache locality.
const Meta = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const root = @import("../root.zig");
const base = root.base;

const Archetype = root.Archetype;
const Type = root.base.Type;
const Component = root.Component;

id: Archetype.Id,
signature: Archetype.Signature,
/// A sorted list of component IDs in the archetype, used to determine the memory layout.
/// Ordered by alignment descending > size descending > component_id ascending.
columns: std.ArrayList(Component.Id),
/// Component ID -> column index mapping for fast lookups.
comp_lookup: std.AutoHashMapUnmanaged(Component.Id.Val, usize),

pub fn init(
    allocator: Allocator,
    id: Archetype.Id,
    unsorted_columns: []const Component.Id,
) Allocator.Error!@This() {
    if (unsorted_columns.len == 0) {
        return .{
            .id = id,
            .signature = Archetype.Signature.init(allocator),
            .columns = .empty,
            .comp_lookup = .empty,
        };
    }

    var signature = Archetype.Signature.init(allocator);
    errdefer signature.deinit();
    try signature.addIds(unsorted_columns);

    var columns = try std.ArrayList(Component.Id).initCapacity(allocator, unsorted_columns.len);
    errdefer columns.deinit(allocator);
    try columns.appendSlice(allocator, unsorted_columns);
    std.mem.sort(Component.Id, columns.items, @as(void, {}), struct {
        pub fn lessThan(_: void, lhs: Component.Id, rhs: Component.Id) bool {
            const lhs_meta = lhs.meta().type_id.meta();
            const rhs_meta = rhs.meta().type_id.meta();
            if (lhs_meta.alignment != rhs_meta.alignment) {
                return lhs_meta.alignment > rhs_meta.alignment;
            } else if (lhs_meta.size != rhs_meta.size) {
                return lhs_meta.size > rhs_meta.size;
            } else {
                return lhs.val < rhs.val;
            }
        }
    }.lessThan);

    var comp_lookup = std.AutoHashMapUnmanaged(Component.Id.Val, usize).empty;
    errdefer comp_lookup.deinit(allocator);
    for (columns.items, 0..) |col, idx| {
        try comp_lookup.put(allocator, col.val, idx);
    }

    return .{
        .id = id,
        .signature = signature,
        .columns = columns,
        .comp_lookup = comp_lookup,
    };
}

pub fn deinit(self: *@This(), allocator: Allocator) void {
    self.signature.deinit();
    self.columns.deinit(allocator);
    self.comp_lookup.deinit(allocator);
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

const TestContext = struct {
    type_registry: Type.Registry,
    comp_registry: Component.Registry,

    pub fn init(allocator: Allocator) @This() {
        return .{
            .type_registry = Type.Registry.init(allocator),
            .comp_registry = Component.Registry.init(allocator),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.type_registry.deinit();
        self.comp_registry.deinit();
    }

    pub fn register(self: *@This(), comptime T: type) Allocator.Error!Component.Id {
        const type_id = try self.type_registry.register(.init(T), null);
        return try self.comp_registry.register(.{
            .type_id = type_id,
            .interface = .Trivial,
        }, null);
    }
};

test "init sorts columns, builds signature and lookup" {
    var ctx = TestContext.init(std.testing.allocator);
    defer ctx.deinit();

    const cid_u32 = try ctx.register(u32);
    const cid_u32_2 = try ctx.register([2]u32);
    const cid_u64 = try ctx.register(u64);
    const cid_i32 = try ctx.register(i32);

    var meta = try Meta.init(
        std.testing.allocator,
        .{ .val = 0, .generation = 0 },
        &.{ cid_i32, cid_u32, cid_u32_2, cid_u64 },
    );
    defer meta.deinit(std.testing.allocator);

    try expectEqual(4, meta.columns.items.len);
    // u64 -> [2]u32 -> u32 -> i32
    for (&[_]usize{ 2, 1, 0, 3 }, 0..) |expected, idx| {
        try expectEqual(expected, meta.columns.items[idx].val);
        try expect(meta.signature.has(expected));
        try expectEqual(idx, meta.comp_lookup.get(expected).?);
    }
}
