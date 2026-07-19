const std = @import("std");
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const base = root.base;
const Span = base.trace.Span;
const Type = base.Type;
const Component = root.Component;

allocator: Allocator,
addr_to_id: std.AutoHashMapUnmanaged(Type.Address, Component.Id.Val) = .empty,
meta_list: std.ArrayList(Component.Meta) = .empty,

pub fn init(allocator: Allocator) @This() {
    return .{ .allocator = allocator };
}

pub fn deinit(self: *@This()) void {
    self.addr_to_id.deinit(self.allocator);
    self.meta_list.deinit(self.allocator);
}

pub fn register(self: *@This(), meta: Component.Meta, span: ?Span) Allocator.Error!Component.Id {
    std.debug.assert(meta.isValid());

    const type_meta = meta.type_id.meta();
    const addr = type_meta.addr;
    if (self.addr_to_id.get(addr)) |existing_id| {
        const rv = Component.Id{ .val = existing_id, .registry = self };
        std.debug.assert(rv.meta().eql(meta)); // Only Idempotent registration is allowed.
        return rv;
    }

    const rv = Component.Id{ .val = self.meta_list.items.len, .registry = self };

    try self.meta_list.append(self.allocator, meta);
    errdefer _ = self.meta_list.pop();

    try self.addr_to_id.put(self.allocator, addr, rv.val);
    errdefer _ = self.addr_to_id.remove(addr);

    // record side effect if a span is provided.
    if (span == null) {
        return rv;
    }
    var event = span.?.startEvent(.verbose, "Component.Registry.register");
    try event.addAttrs(&.{
        .{ .key = "name", .value = .{ .StringView = type_meta.name } },
        .{ .key = "addr", .value = .{ .Uint = addr.val } },
        .{ .key = "is_trivial", .value = .{ .Bool = meta.isTrivial() } },
    });
    event.emit();
    return rv;
}

pub fn typeToId(self: *@This(), comptime T: type) ?Component.Id {
    const addr = Type.Address.of(T);
    return self.addrToId(addr);
}

pub fn addrToId(self: *@This(), addr: Type.Address) ?Component.Id {
    if (self.addr_to_id.get(addr)) |existing_id| {
        return Component.Id{ .val = existing_id, .registry = self };
    }
    return null;
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "register returns stable id for same component and stores correct meta" {
    var type_registry = Type.Registry.init(std.testing.allocator);
    defer type_registry.deinit();
    const type_id = try type_registry.register(.init(u32), null);
    const component_meta = Component.Meta{ .type_id = type_id, .interface = .Trivial };

    var registry = init(std.testing.allocator);
    defer registry.deinit();
    const id1 = try registry.register(component_meta, null);
    const id2 = try registry.register(component_meta, null);

    try expect(id1.eql(id2));
    try expect(id1.registry == &registry);
    try expect(id1.meta().eql(component_meta));
    try expect(registry.typeToId(u32).?.eql(id1));
}

test "register assigns consecutive ids for new components" {
    var type_registry = Type.Registry.init(std.testing.allocator);
    defer type_registry.deinit();
    const u8_type_id = try type_registry.register(.init(u8), null);
    const i16_type_id = try type_registry.register(.init(i16), null);

    var registry = init(std.testing.allocator);
    defer registry.deinit();
    const id_a = try registry.register(.{ .type_id = u8_type_id, .interface = .Trivial }, null);
    const id_b = try registry.register(.{ .type_id = i16_type_id, .interface = .Trivial }, null);

    try expectEqual(@as(Component.Id.Val, 0), id_a.val);
    try expectEqual(@as(Component.Id.Val, 0), registry.addrToId(Type.Address.of(u8)).?.val);
    try expectEqual(@as(Component.Id.Val, 1), id_b.val);
    try expectEqual(@as(Component.Id.Val, 1), registry.addrToId(Type.Address.of(i16)).?.val);
}

test "register revokes operation when out of memory" {
    const Ctx = struct {
        fn run(allocator: Allocator) !void {
            var type_registry = Type.Registry.init(std.testing.allocator);
            defer type_registry.deinit();
            const type_id = try type_registry.register(.init(u32), null);

            var registry = init(allocator);
            defer registry.deinit();
            const component_meta = Component.Meta{ .type_id = type_id, .interface = .Trivial };
            const id = registry.register(component_meta, null) catch |err| switch (err) {
                error.OutOfMemory => {
                    try expectEqual(@as(usize, 0), registry.meta_list.items.len);
                    try expectEqual(@as(usize, 0), registry.addr_to_id.count());
                    try expect(registry.typeToId(u32) == null);
                    return err;
                },
            };

            try expectEqual(@as(Component.Id.Val, 0), id.val);
            try expectEqual(@as(usize, 1), registry.meta_list.items.len);
            try expectEqual(@as(usize, 1), registry.addr_to_id.count());
            try expect(registry.typeToId(u32).?.eql(id));
        }
    };

    try std.testing.checkAllAllocationFailures(std.testing.allocator, Ctx.run, .{});
}

test "typeToId returns null for unregistered component" {
    var registry = init(std.testing.allocator);
    defer registry.deinit();

    try expect(registry.typeToId(u64) == null);
}
