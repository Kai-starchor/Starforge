const Layout = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const base = root.base;

const Type = base.Type;
const AlignedBuffer = base.mem.AlignedBuffer;
const Archetype = root.Archetype;
const Component = root.Component;
const Entity = root.Entity;

meta: *const Archetype.Meta,
capacity: usize,
buffer_size: usize,
buffer_align: usize,
columns_offset: std.ArrayList(usize),
entity_id_offset: usize,

pub fn init(allocator: Allocator, meta: *const Archetype.Meta) Allocator.Error!@This() {
    const columns_len = meta.columns.items.len;
    var column_offsets = try std.ArrayList(usize).initCapacity(allocator, columns_len);
    errdefer column_offsets.deinit(allocator);
    try column_offsets.resize(allocator, columns_len);
    @memset(column_offsets.items, 0);

    const eid_align = @alignOf(Entity.Id);
    const buffer_align =
        if (columns_len != 0)
            @max(meta.columns.items[0].meta().type_id.meta().alignment, eid_align)
        else
            eid_align;

    return .{
        .meta = meta,
        .capacity = 0,
        .buffer_size = 0,
        .buffer_align = buffer_align,
        .columns_offset = column_offsets,
        .entity_id_offset = 0,
    };
}

pub fn deinit(self: *@This(), allocator: Allocator) void {
    self.columns_offset.deinit(allocator);
}

/// Reset the layout with the given capacity, recalculating the buffer size and offsets.
pub fn resetWithCapacity(self: *@This(), capacity: usize) void {
    self.capacity = capacity;
    const columns_offset = self.columns_offset.items;
    const columns = self.meta.columns.items;
    std.debug.assert(columns_offset.len == columns.len);

    // According to the order of columns, there is no padding between them.
    self.buffer_size = 0;
    for (columns, columns_offset) |column, *offset| {
        offset.* = self.buffer_size;
        self.buffer_size += column.meta().type_id.meta().size * capacity;
    }

    // Put Entity.Id at the end of the buffer.
    self.buffer_size = std.mem.alignForward(usize, self.buffer_size, @alignOf(Entity.Id));
    self.entity_id_offset = self.buffer_size;
    self.buffer_size += @sizeOf(Entity.Id) * capacity;
}

/// Reset the layout with the given buffer original bytes length, recalculating the capacity and
/// offsets.
pub fn resetWithBytesLen(self: *@This(), bytes_len: usize) void {
    self.buffer_size = AlignedBuffer.originalToAligned(bytes_len, self.buffer_align);
    const columns_offset = self.columns_offset.items;
    const columns = self.meta.columns.items;
    std.debug.assert(columns_offset.len == columns.len);

    const eid_size = @sizeOf(Entity.Id);
    const eid_align = @alignOf(Entity.Id);

    // Calculate the byte size that an entity actually need.
    var per_entity_size: usize = eid_size;
    for (columns) |column| {
        per_entity_size += column.meta().type_id.meta().size;
    }

    // Put EntityId at the end of buffer.
    const buffer_end = std.mem.alignBackward(usize, self.buffer_size, eid_align);
    self.capacity = buffer_end / per_entity_size;
    self.entity_id_offset = buffer_end - self.capacity * eid_size;

    // According to the order of columns, there is no padding between them.
    var offset: usize = 0;
    for (columns, columns_offset) |column, *col_offset| {
        col_offset.* = offset;
        offset += column.meta().type_id.meta().size * self.capacity;
    }
}

pub fn byteLen(self: @This()) usize {
    return AlignedBuffer.alignedToOriginal(self.buffer_size, self.buffer_align);
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

const TestContext = struct {
    type_registry: Type.Registry,
    comp_registry: Component.Registry,
    meta: Archetype.Meta = undefined,
    layout: Layout = undefined,

    pub fn initRegistry(allocator: Allocator) @This() {
        return .{
            .type_registry = Type.Registry.init(allocator),
            .comp_registry = Component.Registry.init(allocator),
        };
    }

    pub fn initLayout(self: *@This(), allocator: Allocator) Allocator.Error!void {
        const cid_u8 = try self.register(u8);
        const cid_u64 = try self.register(u64);
        const cid_i32 = try self.register(i32);
        self.meta = try Archetype.Meta.init(
            allocator,
            .{ .val = 0, .generation = 0 },
            &.{ cid_u8, cid_i32, cid_u64 },
        );
        self.layout = try Layout.init(allocator, &self.meta);
    }

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        self.layout.deinit(allocator);
        self.meta.deinit(allocator);
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

test "init with empty archetype meta uses entity alignment" {
    var meta = try Archetype.Meta.init(
        std.testing.allocator,
        .{ .val = 0, .generation = 0 },
        &.{},
    );
    defer meta.deinit(std.testing.allocator);

    var layout = try init(std.testing.allocator, &meta);
    defer layout.deinit(std.testing.allocator);

    try expectEqual(0, layout.capacity);
    try expectEqual(0, layout.buffer_size);
    try expectEqual(@alignOf(Entity.Id), layout.buffer_align);
    try expectEqual(0, layout.columns_offset.items.len);
    try expectEqual(0, layout.entity_id_offset);
}

test "resetWithCapacity computes offsets and size" {
    var ctx = TestContext.initRegistry(std.testing.allocator);
    try ctx.initLayout(std.testing.allocator);
    defer ctx.deinit(std.testing.allocator);

    const capacity: usize = 3;
    ctx.layout.resetWithCapacity(capacity);

    // Sorted columns are u64 -> i32 -> u8 for this setup.
    const s0 = ctx.layout.meta.columns.items[0].meta().type_id.meta().size;
    const s1 = ctx.layout.meta.columns.items[1].meta().type_id.meta().size;
    const s2 = ctx.layout.meta.columns.items[2].meta().type_id.meta().size;

    const col0 = 0;
    const col1 = s0 * capacity;
    const col2 = (s0 + s1) * capacity;
    const before_entity = (s0 + s1 + s2) * capacity;
    const entity_offset = std.mem.alignForward(usize, before_entity, @alignOf(Entity.Id));
    const expected_buffer_size = entity_offset + @sizeOf(Entity.Id) * capacity;

    try expectEqual(capacity, ctx.layout.capacity);
    try expectEqual(entity_offset, ctx.layout.entity_id_offset);
    try expectEqual(expected_buffer_size, ctx.layout.buffer_size);
    try expectEqualSlices(usize, &.{ col0, col1, col2 }, ctx.layout.columns_offset.items);
}

test "resetWithBytesLen restores capacity and offsets from byteLen" {
    var ctx = TestContext.initRegistry(std.testing.allocator);
    try ctx.initLayout(std.testing.allocator);
    defer ctx.deinit(std.testing.allocator);

    const expected_capacity: usize = 7;
    ctx.layout.resetWithCapacity(expected_capacity);
    const expected_buffer_size = ctx.layout.buffer_size;
    const expected_entity_offset = ctx.layout.entity_id_offset;
    const expected_byte_len = ctx.layout.byteLen();

    var expected_offsets = try std.ArrayList(usize).initCapacity(
        std.testing.allocator,
        ctx.layout.columns_offset.items.len,
    );
    defer expected_offsets.deinit(std.testing.allocator);
    try expected_offsets.appendSlice(std.testing.allocator, ctx.layout.columns_offset.items);

    ctx.layout.resetWithBytesLen(expected_byte_len);

    try expectEqual(expected_capacity, ctx.layout.capacity);
    try expectEqual(expected_buffer_size, ctx.layout.buffer_size);
    try expectEqual(expected_entity_offset, ctx.layout.entity_id_offset);
    try expectEqual(expected_byte_len, ctx.layout.byteLen());
    try expectEqualSlices(usize, expected_offsets.items, ctx.layout.columns_offset.items);
}
