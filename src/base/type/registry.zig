//! A registry of types, used to assign stable IDs to types and store type metadata.
//! Some custom metadata (e.g. types defined by scripts) can also be stored in the registry.

const std = @import("std");
const Allocator = std.mem.Allocator;

const base = @import("../root.zig");
const Type = base.Type;
const Span = base.trace.Span;

allocator: Allocator,
/// Maps type addresses to stable type IDs.
/// The type address is stable per type, but not guaranteed to be dense.
/// The type ID is a dense index into the meta_list.
addr_to_id: std.AutoHashMapUnmanaged(Type.Address, Type.Id.Val) = .empty,
/// Metadata for each registered type, indexed by the stable type ID.
/// The order of this list is stable since types can only be added to the registry, not removed
/// or reordered.
meta_list: std.ArrayList(Type.Meta) = .empty,

pub fn init(allocator: Allocator) @This() {
    return .{ .allocator = allocator };
}

pub fn deinit(self: *@This()) void {
    self.addr_to_id.deinit(self.allocator);
    self.meta_list.deinit(self.allocator);
}

/// Registers a type with the registry and returns its stable ID.
/// If the type is already registered, returns the existing ID.
pub fn register(self: *@This(), meta: Type.Meta, span: ?Span) Allocator.Error!Type.Id {
    std.debug.assert(meta.isValid());

    if (self.addr_to_id.get(meta.addr)) |existing_id| {
        const rv = Type.Id{ .val = existing_id, .registry = self };
        std.debug.assert(rv.meta().eql(meta)); // Only Idempotent registration is allowed.
        return rv;
    }

    const rv = Type.Id{ .val = self.meta_list.items.len, .registry = self };

    try self.meta_list.append(self.allocator, meta);
    errdefer _ = self.meta_list.pop();

    try self.addr_to_id.put(self.allocator, meta.addr, rv.val);
    errdefer _ = self.addr_to_id.remove(meta.addr);

    // record side effect if a span is provided.
    if (span == null) {
        return rv;
    }
    var event = span.?.startEvent(.verbose, "Type.Registry.register");
    try event.addAttrs(&.{
        .{ .key = "name", .value = .{ .StringView = meta.name } },
        .{ .key = "addr", .value = .{ .Uint = meta.addr.val } },
        .{ .key = "size", .value = .{ .Uint = meta.size } },
        .{ .key = "align", .value = .{ .Uint = meta.alignment } },
    });
    event.emit();
    return rv;
}

/// Gets the stable ID of a type if it is registered, or null if it is not.
pub fn typeToId(self: *const @This(), comptime T: type) ?Type.Id {
    const addr = Type.Address.of(T);
    return self.addrToId(addr);
}

/// Gets the stable ID of a type by its address if it is registered, or null if it is not.
pub fn addrToId(self: *const @This(), addr: Type.Address) ?Type.Id {
    if (self.addr_to_id.get(addr)) |id_val| {
        return Type.Id{ .val = id_val, .registry = self };
    }
    return null;
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

test "register returns stable id for same type and stores correct meta" {
    var registry = init(std.testing.allocator);
    defer registry.deinit();
    const id1 = try registry.register(.init(u32), null);
    const id2 = try registry.register(.init(u32), null);

    try expect(id1.eql(id2));
    try expect(id1.registry == &registry);

    const meta = id1.meta();
    try expectEqual(Type.Address.of(u32).val, meta.addr.val);
    try expectEqual(@sizeOf(u32), meta.size);
    try expectEqual(@alignOf(u32), meta.alignment);
    try expectEqualStrings(@typeName(u32), meta.name);

    const lookup = registry.typeToId(u32).?;
    try expect(lookup.eql(id1));
}

test "register assigns consecutive ids for new types" {
    var registry = init(std.testing.allocator);
    defer registry.deinit();

    const id_a = try registry.register(.init(u8), null);
    const id_b = try registry.register(.init(i16), null);

    try expectEqual(@as(Type.Id.Val, 0), id_a.val);
    try expectEqual(@as(Type.Id.Val, 0), registry.addrToId(Type.Address.of(u8)).?.val);
    try expectEqual(@as(Type.Id.Val, 1), id_b.val);
    try expectEqual(@as(Type.Id.Val, 1), registry.addrToId(Type.Address.of(i16)).?.val);
}

test "register revoke operation when out of memory" {
    const Ctx = struct {
        fn run(allocator: Allocator) !void {
            var registry = init(allocator);
            defer registry.deinit();

            const id = registry.register(.init(u32), null) catch |err| switch (err) {
                // the registry should be left in a consistent state with no partial registration
                error.OutOfMemory => {
                    try expectEqual(@as(usize, 0), registry.meta_list.items.len);
                    try expectEqual(@as(usize, 0), registry.addr_to_id.count());
                    try expect(registry.typeToId(u32) == null);
                    return err;
                },
            };

            // the registry should contain the new type with correct metadata
            try expectEqual(@as(Type.Id.Val, 0), id.val);
            try expectEqual(@as(usize, 1), registry.meta_list.items.len);
            try expectEqual(@as(usize, 1), registry.addr_to_id.count());
            try expect(registry.typeToId(u32).?.eql(id));
        }
    };

    try std.testing.checkAllAllocationFailures(std.testing.allocator, Ctx.run, .{});
}

test "typeToId returns null for unregistered type" {
    var registry = init(std.testing.allocator);
    defer registry.deinit();

    try expect(registry.typeToId(u64) == null);
}
