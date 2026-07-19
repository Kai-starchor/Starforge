const Signature = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const BitSet = std.DynamicBitSet;

const root = @import("../root.zig");
const Component = root.Component;

mask: BitSet,
hash: u64 = 0,

pub fn init(allocator: Allocator) @This() {
    return @This(){
        // Impossible to fail since we start with empty bitset.
        .mask = std.DynamicBitSet.initEmpty(allocator, 0) catch unreachable,
    };
}

pub fn deinit(self: *@This()) void {
    self.mask.deinit();
    self.hash = 0;
}

pub fn clone(self: *const @This(), allocator: Allocator) Allocator.Error!@This() {
    return @This(){
        .mask = try self.mask.clone(allocator),
        .hash = self.hash,
    };
}

fn rehash(self: *@This()) void {
    const last_bit = self.mask.unmanaged.findLastSet() orelse 0;
    const last_mask = last_bit / @sizeOf(std.DynamicBitSetUnmanaged.MaskInt);
    self.hash = std.hash.Wyhash.hash(0, std.mem.sliceAsBytes(self.mask.unmanaged.masks[0 .. last_mask + 1]));
}

pub fn eql(self: @This(), other: @This()) bool {
    return self.hash == other.hash and self.mask.eql(other.mask);
}

pub fn add(self: *@This(), ids: []const Component.Id.Val) Allocator.Error!void {
    var check_max_id: ?usize = null;
    for (ids) |id| {
        if (check_max_id == null or id > check_max_id.?) {
            check_max_id = id;
        }
    }
    if (check_max_id) |max_id| {
        if (max_id >= self.mask.capacity()) {
            try self.mask.resize(max_id + 1, false);
        }
    }
    for (ids) |id| {
        self.mask.set(id);
    }
    self.rehash();
}

/// Always shrink to fit after removing components.
pub fn remove(self: *@This(), ids: []const Component.Id.Val) Allocator.Error!void {
    for (ids) |id| {
        if (id < self.mask.capacity()) {
            self.mask.unset(id);
        }
    }

    // shrink to fit
    if (self.mask.findLastSet()) |last_index| {
        try self.mask.resize(last_index + 1, false);
    } else {
        try self.mask.resize(0, false);
    }

    self.rehash();
}

pub fn has(self: *const @This(), id: Component.Id.Val) bool {
    return id < self.mask.capacity() and self.mask.isSet(id);
}

pub fn contains(self: *const @This(), other: *const @This()) bool {
    var it = other.mask.iterator(.{});
    while (it.next()) |bit_index| {
        if (bit_index >= self.mask.capacity() or !self.mask.isSet(bit_index)) {
            return false;
        }
    }
    return true;
}

pub fn intersects(self: *const @This(), other: *const @This()) bool {
    var it = self.mask.iterator(.{});
    while (it.next()) |bit_index| {
        if (bit_index < other.mask.capacity() and other.mask.isSet(bit_index)) {
            return true;
        }
    }
    return false;
}

pub fn Lookup(comptime T: type) type {
    return std.HashMap(@This(), T, struct {
        pub fn hash(_: @This(), key: Signature) u64 {
            return key.hash;
        }

        pub fn eql(_: @This(), lhs: Signature, rhs: Signature) bool {
            return lhs.eql(rhs);
        }
    }, std.hash_map.default_max_load_percentage);
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "has after added" {
    var sig = init(std.testing.allocator);
    defer sig.deinit();

    try sig.add(&.{ 1, 4, 7 });

    try expect(sig.has(1));
    try expect(sig.has(4));
    try expect(sig.has(7));
    try expect(!sig.has(2));
    try expect(!sig.has(8));
}

test "remove bits and shrink capacity" {
    var sig = init(std.testing.allocator);
    defer sig.deinit();

    try sig.add(&.{ 1, 4, 7 });
    try expectEqual(8, sig.mask.capacity());

    try sig.remove(&.{7});
    try expect(!sig.has(7));
    try expectEqual(5, sig.mask.capacity());

    try sig.remove(&.{ 1, 4 });
    try expectEqual(0, sig.mask.capacity());
}

test "contains checks subset relation" {
    var a = init(std.testing.allocator);
    defer a.deinit();
    var b = init(std.testing.allocator);
    defer b.deinit();

    try a.add(&.{ 1, 3, 5 });
    try b.add(&.{ 1, 5 });

    try expect(a.contains(&b));
    try expect(!b.contains(&a));

    try b.add(&.{9});
    try expect(!a.contains(&b));
}

test "intersects detects overlap" {
    var a = init(std.testing.allocator);
    defer a.deinit();
    var b = init(std.testing.allocator);
    defer b.deinit();

    try a.add(&.{ 2, 4 });
    try b.add(&.{6});
    try expect(!a.intersects(&b));

    try b.add(&.{4});
    try expect(a.intersects(&b));
}

test "clone independent copy" {
    var sig = init(std.testing.allocator);
    defer sig.deinit();
    try sig.add(&.{ 1, 8 });

    var cloned = try sig.clone(std.testing.allocator);
    defer cloned.deinit();

    try expect(cloned.has(1));
    try expect(cloned.has(8));

    try sig.remove(&.{8});
    try expect(!sig.has(8));
    try expect(cloned.has(8));
}

test "hash matches for equal signatures" {
    var a = init(std.testing.allocator);
    defer a.deinit();
    var b = init(std.testing.allocator);
    defer b.deinit();

    try a.add(&.{ 1, 4, 7, 12 });
    try b.add(&.{ 12, 1 });
    try b.add(&.{ 7, 4 });

    try expectEqual(a.hash, b.hash);
    try expect(a.eql(b));
}

test "hash updates after mutation" {
    var sig = init(std.testing.allocator);
    defer sig.deinit();

    try sig.add(&.{ 1, 4 });
    const base_hash = sig.hash;

    try sig.add(&.{9});
    try expect(sig.hash != base_hash);

    try sig.remove(&.{9});
    try expectEqual(base_hash, sig.hash);
}

test "Lookup retrieves value with equivalent signature" {
    var stored = init(std.testing.allocator);
    defer stored.deinit();
    try stored.add(&.{ 1, 4, 7 });

    var equivalent = init(std.testing.allocator);
    defer equivalent.deinit();
    try equivalent.add(&.{ 7, 1, 4 });

    var different = init(std.testing.allocator);
    defer different.deinit();
    try different.add(&.{ 1, 4 });

    var lookup = Lookup(u32).init(std.testing.allocator);
    defer lookup.deinit();
    try lookup.put(stored, 42);

    try expectEqual(42, lookup.get(equivalent));
    try expectEqual(null, lookup.get(different));
}
