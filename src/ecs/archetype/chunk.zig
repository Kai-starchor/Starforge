const Chunk = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const base = root.base;

const Type = base.Type;
const AlignedBuffer = base.mem.AlignedBuffer;
const Archetype = root.Archetype;
const Entity = root.Entity;
const Component = root.Component;

pub const Layout = @import("layout.zig");

layout: *const Layout,
buffer: AlignedBuffer,
len: usize,

pub fn init(allocator: Allocator, layout: *const Layout) Allocator.Error!@This() {
    return .{
        .layout = layout,
        .buffer = try AlignedBuffer.init(allocator, layout.buffer_size, layout.buffer_align),
        .len = 0,
    };
}

pub fn deinit(self: *@This(), allocator: Allocator) void {
    self.removeTail(self.len);
    self.buffer.deinit(allocator);
}

pub fn getEntityIdColumnUnsafe(self: @This()) []Entity.Id {
    const offset = self.layout.entity_id_offset;
    const bytes = self.buffer.aligned[offset..][0 .. self.layout.capacity * @sizeOf(Entity.Id)];
    const aligned_bytes: []align(@alignOf(Entity.Id)) u8 = @alignCast(bytes);
    return std.mem.bytesAsSlice(Entity.Id, aligned_bytes);
}

pub fn getEntityIdColumn(self: @This()) []Entity.Id {
    return self.getEntityIdColumnUnsafe()[0..self.len];
}

pub const ColumnBuffer = struct {
    comp_id: Component.Id,
    bytes: []u8,
};

pub fn getColumnUnsafe(self: @This(), col: usize) ColumnBuffer {
    const offset = self.layout.columns_offset.items[col];
    const comp_id = self.layout.meta.columns.items[col];
    const stride = comp_id.meta().type_id.meta().size;
    const col_end = stride * self.layout.capacity;
    const bytes = self.buffer.aligned[offset..][0..col_end];
    return .{ .comp_id = comp_id, .bytes = bytes };
}

pub fn getColumn(self: @This(), col: usize) ColumnBuffer {
    const column = self.getColumnUnsafe(col);
    const stride = column.comp_id.meta().type_id.meta().size;
    const col_end = stride * self.len;
    return .{ .comp_id = column.comp_id, .bytes = column.bytes[0..col_end] };
}

pub fn push(self: *@This(), eid: []Entity.Id, cols: []ColumnBuffer) usize {
    const cols_id = self.layout.meta.columns.items;
    // sanity check before operations that are hard to revert
    std.debug.assert(cols.len == cols_id.len);
    for (cols, cols_id) |col, col_id| {
        const stride = col_id.meta().type_id.meta().size;
        std.debug.assert(col.comp_id.eql(col_id));
        std.debug.assert(col.bytes.len == stride * eid.len);
    }

    const pushed = @min(eid.len, self.layout.capacity - self.len);
    if (pushed == 0) return 0;

    const eid_col = self.getEntityIdColumnUnsafe();
    @memcpy(eid_col[self.len..][0..pushed], eid[0..pushed]);

    for (cols, 0..) |col, col_idx| {
        const comp_meta = col.comp_id.meta();
        const col_dst = self.getColumnUnsafe(col_idx).bytes;
        migrateColumnData(comp_meta, col.bytes, 0, col_dst, self.len, pushed);
    }

    self.len += pushed;
    return pushed;
}

/// Move `count` entities and their components at tail from `self` to `dst`.
/// Returns the number of entities actually moved.
/// `self` and `dst` must comes from the same archetype, otherwise the behavior is undefined.
pub fn move(self: *@This(), dst: *@This(), count: usize) usize {
    std.debug.assert(self.layout.meta.id.eql(dst.layout.meta.id));

    const moved = @min(count, @min(self.len, dst.layout.capacity - dst.len));
    if (moved == 0) return 0;

    const src_start = self.len - moved;
    const dst_start = dst.len;

    const src_eid_col = self.getEntityIdColumnUnsafe();
    const dst_eid_col = dst.getEntityIdColumnUnsafe();
    @memcpy(dst_eid_col[dst_start..][0..moved], src_eid_col[src_start..][0..moved]);

    for (self.layout.meta.columns.items, 0..) |col_id, col_idx| {
        const comp_meta = col_id.meta();
        const src_col = self.getColumnUnsafe(col_idx).bytes;
        const dst_col = dst.getColumnUnsafe(col_idx).bytes;
        migrateColumnData(comp_meta, src_col, src_start, dst_col, dst_start, moved);
    }

    self.len -= moved;
    dst.len += moved;
    return moved;
}

pub const ColumnBufferNullable = struct {
    comp_id: Component.Id,
    bytes: ?[]u8,
};

pub fn pop(self: *@This(), eid: []Entity.Id, cols: []ColumnBufferNullable) usize {
    const cols_id = self.layout.meta.columns.items;
    // sanity check before operations that are hard to revert
    std.debug.assert(cols.len == cols_id.len);
    for (cols, cols_id) |col, col_id| {
        const stride = col_id.meta().type_id.meta().size;
        std.debug.assert(col.comp_id.eql(col_id));
        if (col.bytes) |bytes| std.debug.assert(bytes.len == stride * eid.len);
    }

    const popped = @min(eid.len, self.len);
    if (popped == 0) return 0;

    const pop_start = self.len - popped;
    const eid_col = self.getEntityIdColumnUnsafe();
    @memcpy(eid[0..popped], eid_col[pop_start..][0..popped]);

    for (cols, 0..) |col, col_idx| {
        const comp_meta = col.comp_id.meta();
        const col_src = self.getColumnUnsafe(col_idx).bytes;

        if (col.bytes) |dst_full| {
            migrateColumnData(comp_meta, col_src, pop_start, dst_full, 0, popped);
            continue;
        }

        deinitColumnData(comp_meta, col_src, pop_start, popped);
    }

    self.len -= popped;
    return popped;
}

pub fn removeTail(self: *@This(), count: usize) void {
    const removed = @min(count, self.len);
    if (removed == 0) return;

    const meta = self.layout.meta;
    const columns = meta.columns.items;
    for (columns, 0..) |column, col_idx| {
        const comp_meta = column.meta();
        const col_src = self.getColumnUnsafe(col_idx).bytes;
        deinitColumnData(comp_meta, col_src, self.len - removed, removed);
    }
    self.len -= removed;
}

fn migrateColumnData(
    comp_meta: Component.Meta,
    src_col: []u8,
    src_entity_start: usize,
    dst_col: []u8,
    dst_entity_start: usize,
    entity_count: usize,
) void {
    const stride = comp_meta.type_id.meta().size;
    const src_start = stride * src_entity_start;
    const dst_start = stride * dst_entity_start;
    const byte_len = stride * entity_count;

    const src_bytes = src_col[src_start..][0..byte_len];
    const dst_bytes = dst_col[dst_start..][0..byte_len];
    std.debug.assert(src_bytes.len == dst_bytes.len);

    if (comp_meta.isTrivial()) {
        @memcpy(dst_bytes, src_bytes);
        return;
    }

    if (stride == 0) {
        const interface = comp_meta.interface.NonTrivial;
        for (0..entity_count) |_| {
            const dst_component = dst_bytes[0..0];
            const src_component = src_bytes[0..0];
            interface.move(
                @ptrCast(@alignCast(dst_component)),
                @ptrCast(@alignCast(src_component)),
            );
        }
        return;
    }

    std.debug.assert(src_bytes.len == stride * entity_count);

    const interface = comp_meta.interface.NonTrivial;
    for (0..entity_count) |i| {
        const dst_component = dst_bytes[i * stride ..][0..stride];
        const src_component = src_bytes[i * stride ..][0..stride];
        interface.move(
            @ptrCast(@alignCast(dst_component)),
            @ptrCast(@alignCast(src_component)),
        );
    }
}

fn deinitColumnData(
    comp_meta: Component.Meta,
    src_col: []u8,
    src_entity_start: usize,
    entity_count: usize,
) void {
    const stride = comp_meta.type_id.meta().size;
    const src_start = stride * src_entity_start;
    const byte_len = stride * entity_count;
    const src_bytes = src_col[src_start..][0..byte_len];

    if (comp_meta.isTrivial()) return;

    if (stride == 0) {
        const interface = comp_meta.interface.NonTrivial;
        for (0..entity_count) |_| {
            const src_component = src_bytes[0..0];
            interface.deinit(@ptrCast(@alignCast(src_component)));
        }
        return;
    }

    std.debug.assert(src_bytes.len == stride * entity_count);

    const interface = comp_meta.interface.NonTrivial;
    for (0..entity_count) |i| {
        const src_component = src_bytes[i * stride ..][0..stride];
        interface.deinit(@ptrCast(@alignCast(src_component)));
    }
}

const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

const Managed = struct {
    value: u32,

    pub fn move(dst: *@This(), src: *@This(), ctx: ?*ManagedCtx) void {
        const typed_ctx = ctx orelse unreachable;
        typed_ctx.move_count += 1;
        dst.value = src.value + typed_ctx.delta;
        src.value = 0;
    }

    pub fn deinit(self: *@This(), ctx: ?*ManagedCtx) void {
        const typed_ctx = ctx orelse unreachable;
        typed_ctx.deinit_count += 1;
        self.value = 0;
    }
};

const ManagedCtx = struct {
    delta: u32,
    move_count: usize = 0,
    deinit_count: usize = 0,
};

const TestContext = struct {
    type_registry: Type.Registry,
    comp_registry: Component.Registry,
    managed_ctx: ManagedCtx,

    meta: Archetype.Meta = undefined,
    layout: Layout = undefined,
    chunk: Chunk = undefined,

    comp_u8: Component.Id = undefined,
    comp_managed: Component.Id = undefined,

    pub fn initRegistry(allocator: Allocator) @This() {
        return .{
            .type_registry = Type.Registry.init(allocator),
            .comp_registry = Component.Registry.init(allocator),
            .managed_ctx = .{ .delta = 10 },
        };
    }

    pub fn initChunk(self: *@This(), allocator: Allocator, capacity: usize) Allocator.Error!void {
        self.comp_u8 = try self.registerTrivial(u8);
        self.comp_managed = try self.registerManaged();

        self.meta = try Archetype.Meta.init(
            allocator,
            .{ .val = 0, .generation = 0 },
            &.{ self.comp_u8, self.comp_managed },
        );
        errdefer self.meta.deinit(allocator);

        self.layout = try Layout.init(allocator, &self.meta);
        errdefer self.layout.deinit(allocator);
        self.layout.resetWithCapacity(capacity);

        self.chunk = try Chunk.init(allocator, &self.layout);
        errdefer self.chunk.deinit(allocator);
    }

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        self.chunk.deinit(allocator);
        self.layout.deinit(allocator);
        self.meta.deinit(allocator);
        self.comp_registry.deinit();
        self.type_registry.deinit();
    }

    fn registerTrivial(self: *@This(), comptime T: type) Allocator.Error!Component.Id {
        const type_id = try self.type_registry.register(.init(T), null);
        return try self.comp_registry.register(.{
            .type_id = type_id,
            .interface = .Trivial,
        }, null);
    }

    fn registerManaged(self: *@This()) Allocator.Error!Component.Id {
        const type_id = try self.type_registry.register(.init(Managed), null);
        const Builder = Component.Meta.Interface.Builder(Managed, ManagedCtx);
        return try self.comp_registry.register(.{
            .type_id = type_id,
            .interface = .{ .NonTrivial = Builder.build(&.{
                .deinit = Managed.deinit,
                .move = Managed.move,
            }, &self.managed_ctx) },
        }, null);
    }

    fn colIndex(self: @This(), comp_id: Component.Id) usize {
        return self.meta.comp_lookup.get(comp_id.val).?;
    }

    fn bindColumnIn(
        self: @This(),
        cols: *[2]ColumnBuffer,
        u8_values: []u8,
        managed_values: []Managed,
    ) void {
        cols[self.colIndex(self.comp_u8)] = .{
            .comp_id = self.comp_u8,
            .bytes = u8_values,
        };
        cols[self.colIndex(self.comp_managed)] = .{
            .comp_id = self.comp_managed,
            .bytes = std.mem.sliceAsBytes(managed_values),
        };
    }

    fn bindColumnOut(
        self: @This(),
        cols: *[2]ColumnBufferNullable,
        u8_values: ?[]u8,
        managed_values: ?[]Managed,
    ) void {
        cols[self.colIndex(self.comp_u8)] = .{
            .comp_id = self.comp_u8,
            .bytes = u8_values,
        };
        cols[self.colIndex(self.comp_managed)] = .{
            .comp_id = self.comp_managed,
            .bytes = if (managed_values) |values| std.mem.sliceAsBytes(values) else null,
        };
    }
};

test "push writes columns and uses move for non-trivial components" {
    var ctx = TestContext.initRegistry(std.testing.allocator);
    try ctx.initChunk(std.testing.allocator, 4);
    defer ctx.deinit(std.testing.allocator);

    var entities = [_]Entity.Id{
        .{ .val = 1, .generation = 7 },
        .{ .val = 2, .generation = 7 },
    };
    var u8_values = [_]u8{ 5, 9 };
    var managed_values = [_]Managed{ .{ .value = 1 }, .{ .value = 2 } };

    var cols: [2]ColumnBuffer = undefined;
    ctx.bindColumnIn(&cols, u8_values[0..], managed_values[0..]);

    const pushed = ctx.chunk.push(entities[0..], cols[0..]);
    try expectEqual(2, pushed);
    try expectEqual(2, ctx.chunk.len);
    try expectEqual(2, ctx.managed_ctx.move_count);
    try expectEqual(0, managed_values[0].value);
    try expectEqual(0, managed_values[1].value);
    try expectEqualSlices(Entity.Id, entities[0..], ctx.chunk.getEntityIdColumn());

    const u8_col = ctx.chunk.getColumn(ctx.colIndex(ctx.comp_u8));
    try expectEqualSlices(u8, u8_values[0..], u8_col.bytes);

    const managed_col = ctx.chunk.getColumn(ctx.colIndex(ctx.comp_managed));
    const managed_bytes: []align(@alignOf(Managed)) u8 = @alignCast(managed_col.bytes);
    const managed_out = std.mem.bytesAsSlice(Managed, managed_bytes);
    try expectEqual(11, managed_out[0].value);
    try expectEqual(12, managed_out[1].value);
}

test "pop moves to outputs and shrinks from tail" {
    var ctx = TestContext.initRegistry(std.testing.allocator);
    try ctx.initChunk(std.testing.allocator, 4);
    defer ctx.deinit(std.testing.allocator);

    var entities = [_]Entity.Id{
        .{ .val = 1, .generation = 1 },
        .{ .val = 2, .generation = 1 },
    };
    var u8_values = [_]u8{ 3, 4 };
    var managed_values = [_]Managed{ .{ .value = 7 }, .{ .value = 9 } };
    var cols_in: [2]ColumnBuffer = undefined;
    ctx.bindColumnIn(&cols_in, u8_values[0..], managed_values[0..]);
    _ = ctx.chunk.push(entities[0..], cols_in[0..]);

    var pop_entities = [_]Entity.Id{.invalid};
    var pop_u8 = [_]u8{0};
    var pop_managed = [_]Managed{.{ .value = 0 }};
    var cols_out: [2]ColumnBufferNullable = undefined;
    ctx.bindColumnOut(&cols_out, pop_u8[0..], pop_managed[0..]);

    const popped = ctx.chunk.pop(pop_entities[0..], cols_out[0..]);
    try expectEqual(1, popped);
    try expectEqual(1, ctx.chunk.len);
    try expectEqual(3, ctx.managed_ctx.move_count);
    try expectEqual(0, ctx.managed_ctx.deinit_count);

    try expectEqual(2, pop_entities[0].val);
    try expectEqual(1, pop_entities[0].generation);
    try expectEqual(4, pop_u8[0]);
    try expectEqual(29, pop_managed[0].value);
}

test "pop deinit non-trivial components when output is null" {
    var ctx = TestContext.initRegistry(std.testing.allocator);
    try ctx.initChunk(std.testing.allocator, 4);
    defer ctx.deinit(std.testing.allocator);

    var entities = [_]Entity.Id{
        .{ .val = 10, .generation = 2 },
        .{ .val = 11, .generation = 2 },
        .{ .val = 12, .generation = 2 },
    };
    var u8_values = [_]u8{ 1, 2, 3 };
    var managed_values = [_]Managed{ .{ .value = 1 }, .{ .value = 2 }, .{ .value = 3 } };
    var cols_in: [2]ColumnBuffer = undefined;
    ctx.bindColumnIn(&cols_in, u8_values[0..], managed_values[0..]);
    _ = ctx.chunk.push(entities[0..], cols_in[0..]);

    var pop_entities = [_]Entity.Id{ .invalid, .invalid };
    var cols_out: [2]ColumnBufferNullable = undefined;
    ctx.bindColumnOut(&cols_out, null, null);

    const popped = ctx.chunk.pop(pop_entities[0..], cols_out[0..]);
    try expectEqual(2, popped);
    try expectEqual(1, ctx.chunk.len);
    try expectEqual(3, ctx.managed_ctx.move_count);
    try expectEqual(2, ctx.managed_ctx.deinit_count);
    try expectEqual(11, pop_entities[0].val);
    try expectEqual(12, pop_entities[1].val);
}

test "removeTail deinit non-trivial components and supports count overflow" {
    var ctx = TestContext.initRegistry(std.testing.allocator);
    try ctx.initChunk(std.testing.allocator, 3);
    defer ctx.deinit(std.testing.allocator);

    var entities = [_]Entity.Id{
        .{ .val = 1, .generation = 0 },
        .{ .val = 2, .generation = 0 },
    };
    var u8_values = [_]u8{ 8, 9 };
    var managed_values = [_]Managed{ .{ .value = 5 }, .{ .value = 6 } };
    var cols_in: [2]ColumnBuffer = undefined;
    ctx.bindColumnIn(&cols_in, u8_values[0..], managed_values[0..]);
    _ = ctx.chunk.push(entities[0..], cols_in[0..]);

    ctx.chunk.removeTail(9);
    try expectEqual(0, ctx.chunk.len);
    try expectEqual(2, ctx.managed_ctx.deinit_count);
}

test "push and pop are clipped by capacity and length" {
    var ctx = TestContext.initRegistry(std.testing.allocator);
    try ctx.initChunk(std.testing.allocator, 2);
    defer ctx.deinit(std.testing.allocator);

    var entities = [_]Entity.Id{
        .{ .val = 1, .generation = 3 },
        .{ .val = 2, .generation = 3 },
        .{ .val = 3, .generation = 3 },
    };
    var u8_values = [_]u8{ 1, 2, 3 };
    var managed_values = [_]Managed{ .{ .value = 1 }, .{ .value = 2 }, .{ .value = 3 } };
    var cols_in: [2]ColumnBuffer = undefined;
    ctx.bindColumnIn(&cols_in, u8_values[0..], managed_values[0..]);

    const pushed = ctx.chunk.push(entities[0..], cols_in[0..]);
    try expectEqual(2, pushed);
    try expectEqual(2, ctx.chunk.len);

    var pop_entities = [_]Entity.Id{ .invalid, .invalid, .invalid };
    var pop_u8 = [_]u8{ 0, 0, 0 };
    var pop_managed = [_]Managed{ .{ .value = 0 }, .{ .value = 0 }, .{ .value = 0 } };
    var cols_out: [2]ColumnBufferNullable = undefined;
    ctx.bindColumnOut(&cols_out, pop_u8[0..], pop_managed[0..]);

    const popped = ctx.chunk.pop(pop_entities[0..], cols_out[0..]);
    try expectEqual(2, popped);
    try expectEqual(0, ctx.chunk.len);
}

test "move transfers tail entities and columns" {
    var ctx = TestContext.initRegistry(std.testing.allocator);
    try ctx.initChunk(std.testing.allocator, 5);
    defer ctx.deinit(std.testing.allocator);

    var dst_chunk = try Chunk.init(std.testing.allocator, &ctx.layout);
    defer dst_chunk.deinit(std.testing.allocator);

    var entities = [_]Entity.Id{
        .{ .val = 1, .generation = 9 },
        .{ .val = 2, .generation = 9 },
        .{ .val = 3, .generation = 9 },
    };
    var u8_values = [_]u8{ 10, 20, 30 };
    var managed_values = [_]Managed{ .{ .value = 1 }, .{ .value = 2 }, .{ .value = 3 } };
    var cols_in: [2]ColumnBuffer = undefined;
    ctx.bindColumnIn(&cols_in, u8_values[0..], managed_values[0..]);
    _ = ctx.chunk.push(entities[0..], cols_in[0..]);

    const moved = ctx.chunk.move(&dst_chunk, 2);
    try expectEqual(2, moved);
    try expectEqual(1, ctx.chunk.len);
    try expectEqual(2, dst_chunk.len);
    try expectEqual(5, ctx.managed_ctx.move_count);

    try expectEqual(2, dst_chunk.getEntityIdColumn()[0].val);
    try expectEqual(3, dst_chunk.getEntityIdColumn()[1].val);

    const u8_col = dst_chunk.getColumn(ctx.colIndex(ctx.comp_u8));
    try expectEqualSlices(u8, &.{ 20, 30 }, u8_col.bytes);

    const managed_col = dst_chunk.getColumn(ctx.colIndex(ctx.comp_managed));
    const managed_bytes: []align(@alignOf(Managed)) u8 = @alignCast(managed_col.bytes);
    const managed_out = std.mem.bytesAsSlice(Managed, managed_bytes);
    try expectEqual(22, managed_out[0].value);
    try expectEqual(23, managed_out[1].value);
}

test "move is clipped by source length and destination capacity" {
    var ctx = TestContext.initRegistry(std.testing.allocator);
    try ctx.initChunk(std.testing.allocator, 2);
    defer ctx.deinit(std.testing.allocator);

    var src_entities = [_]Entity.Id{
        .{ .val = 1, .generation = 4 },
        .{ .val = 2, .generation = 4 },
    };
    var src_u8_values = [_]u8{ 7, 8 };
    var src_managed_values = [_]Managed{ .{ .value = 1 }, .{ .value = 2 } };
    var src_cols_in: [2]ColumnBuffer = undefined;
    ctx.bindColumnIn(&src_cols_in, src_u8_values[0..], src_managed_values[0..]);
    _ = ctx.chunk.push(src_entities[0..], src_cols_in[0..]);

    var dst_chunk = try Chunk.init(std.testing.allocator, &ctx.layout);
    defer dst_chunk.deinit(std.testing.allocator);

    var dst_entities = [_]Entity.Id{.{ .val = 99, .generation = 4 }};
    var dst_u8_values = [_]u8{5};
    var dst_managed_values = [_]Managed{.{ .value = 9 }};
    var dst_cols_in: [2]ColumnBuffer = undefined;
    ctx.bindColumnIn(&dst_cols_in, dst_u8_values[0..], dst_managed_values[0..]);
    _ = dst_chunk.push(dst_entities[0..], dst_cols_in[0..]);

    const moved = ctx.chunk.move(&dst_chunk, 10);
    try expectEqual(1, moved);
    try expectEqual(1, ctx.chunk.len);
    try expectEqual(2, dst_chunk.len);

    const dst_eid = dst_chunk.getEntityIdColumn();
    try expectEqual(99, dst_eid[0].val);
    try expectEqual(2, dst_eid[1].val);
}

test "zero-sized non-trivial components work across push move pop and removeTail" {
    const ZstManagedCtx = struct {
        move_count: usize = 0,
        deinit_count: usize = 0,
    };
    const ZstManaged = struct {
        pub fn move(_: *@This(), _: *@This(), ctx: ?*ZstManagedCtx) void {
            const typed_ctx = ctx orelse unreachable;
            typed_ctx.move_count += 1;
        }

        pub fn deinit(_: *@This(), ctx: ?*ZstManagedCtx) void {
            const typed_ctx = ctx orelse unreachable;
            typed_ctx.deinit_count += 1;
        }
    };

    var type_registry = Type.Registry.init(std.testing.allocator);
    defer type_registry.deinit();
    var comp_registry = Component.Registry.init(std.testing.allocator);
    defer comp_registry.deinit();

    const comp_u8_type = try type_registry.register(.init(u8), null);
    const comp_u8 = try comp_registry.register(.{
        .type_id = comp_u8_type,
        .interface = .Trivial,
    }, null);

    var zst_ctx = ZstManagedCtx{};
    const comp_zst_type = try type_registry.register(.init(ZstManaged), null);
    const Builder = Component.Meta.Interface.Builder(ZstManaged, ZstManagedCtx);
    const comp_zst = try comp_registry.register(.{
        .type_id = comp_zst_type,
        .interface = .{ .NonTrivial = Builder.build(&.{
            .deinit = ZstManaged.deinit,
            .move = ZstManaged.move,
        }, &zst_ctx) },
    }, null);

    var meta = try Archetype.Meta.init(
        std.testing.allocator,
        .{ .val = 0, .generation = 0 },
        &.{ comp_u8, comp_zst },
    );
    defer meta.deinit(std.testing.allocator);

    var layout = try Layout.init(std.testing.allocator, &meta);
    defer layout.deinit(std.testing.allocator);
    layout.resetWithCapacity(4);

    var src = try Chunk.init(std.testing.allocator, &layout);
    defer src.deinit(std.testing.allocator);
    var dst = try Chunk.init(std.testing.allocator, &layout);
    defer dst.deinit(std.testing.allocator);

    const idx_u8 = meta.comp_lookup.get(comp_u8.val).?;
    const idx_zst = meta.comp_lookup.get(comp_zst.val).?;

    var entities = [_]Entity.Id{
        .{ .val = 1, .generation = 1 },
        .{ .val = 2, .generation = 1 },
        .{ .val = 3, .generation = 1 },
    };
    var u8_values = [_]u8{ 4, 5, 6 };
    var zst_values: [0]u8 = .{};
    var cols_in: [2]ColumnBuffer = undefined;
    cols_in[idx_u8] = .{ .comp_id = comp_u8, .bytes = u8_values[0..] };
    cols_in[idx_zst] = .{ .comp_id = comp_zst, .bytes = zst_values[0..] };

    const pushed = src.push(entities[0..], cols_in[0..]);
    try expectEqual(3, pushed);
    try expectEqual(3, zst_ctx.move_count);

    const moved = src.move(&dst, 2);
    try expectEqual(2, moved);
    try expectEqual(5, zst_ctx.move_count);

    var pop_eid = [_]Entity.Id{.invalid};
    var pop_u8 = [_]u8{0};
    var pop_zst: [0]u8 = .{};
    var cols_out_move: [2]ColumnBufferNullable = undefined;
    cols_out_move[idx_u8] = .{ .comp_id = comp_u8, .bytes = pop_u8[0..] };
    cols_out_move[idx_zst] = .{ .comp_id = comp_zst, .bytes = pop_zst[0..] };

    const popped_with_move = dst.pop(pop_eid[0..], cols_out_move[0..]);
    try expectEqual(1, popped_with_move);
    try expectEqual(6, zst_ctx.move_count);

    var pop_eid_null = [_]Entity.Id{.invalid};
    var cols_out_deinit: [2]ColumnBufferNullable = undefined;
    cols_out_deinit[idx_u8] = .{ .comp_id = comp_u8, .bytes = null };
    cols_out_deinit[idx_zst] = .{ .comp_id = comp_zst, .bytes = null };

    const popped_with_deinit = dst.pop(pop_eid_null[0..], cols_out_deinit[0..]);
    try expectEqual(1, popped_with_deinit);
    try expectEqual(1, zst_ctx.deinit_count);

    src.removeTail(1);
    try expectEqual(2, zst_ctx.deinit_count);
}
