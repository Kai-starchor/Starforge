const std = @import("std");

const Allocator = std.mem.Allocator;

/// A unique identifier of a zig type.
pub const TypeAddress = struct {
    pub const INVALID_ADDRESS: usize = 0;
    pub const invalid = TypeAddress{};

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

    /// Checks if the TypeAddress is valid according to the validate function.
    pub fn isValid(self: @This()) bool {
        self.validate() catch {
            return false;
        };
        return true;
    }
};

/// A registry of types, used to assign stable IDs to types and store type metadata.
/// Some custom metadata (e.g. types defined by scripts) can also be stored in the registry.
pub const TypeRegistry = struct {
    allocator: Allocator,
    /// Maps type addresses to stable type IDs.
    /// The type address is stable per type, but not guaranteed to be dense.
    /// The type ID is a dense index into the meta_list.
    addr_to_id: std.AutoHashMapUnmanaged(TypeAddress, TypeId.Val) = .empty,
    /// Metadata for each registered type, indexed by the stable type ID.
    /// The order of this list is stable since types can only be added to the registry, not removed or reordered.
    meta_list: std.ArrayList(TypeMeta) = .empty,

    pub fn init(allocator: Allocator) @This() {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *@This()) void {
        self.addr_to_id.deinit(self.allocator);
        self.meta_list.deinit(self.allocator);
    }

    /// Registers a type with the registry and returns its stable ID.
    /// If the type is already registered, returns the existing ID.
    pub fn register(self: *@This(), meta: TypeMeta) Allocator.Error!TypeId {
        std.debug.assert(meta.isValid());

        if (self.addr_to_id.get(meta.addr)) |existing_id| {
            const rv = TypeId{ .val = existing_id, .registry = self };
            std.debug.assert(rv.meta().eql(meta)); // Only Idempotent registration is allowed.
            return rv;
        }

        const rv = TypeId{ .val = self.meta_list.items.len, .registry = self };

        try self.meta_list.append(self.allocator, meta);
        errdefer _ = self.meta_list.pop();

        try self.addr_to_id.put(self.allocator, meta.addr, rv.val);
        errdefer _ = self.addr_to_id.remove(meta.addr);

        return rv;
    }

    /// Gets the stable ID of a type if it is registered, or null if it is not.
    pub fn typeToId(self: *const @This(), comptime T: type) ?TypeId {
        const addr = TypeAddress.of(T);
        return self.addrToId(addr);
    }

    /// Gets the stable ID of a type by its address if it is registered, or null if it is not.
    pub fn addrToId(self: *const @This(), addr: TypeAddress) ?TypeId {
        if (self.addr_to_id.get(addr)) |id_val| {
            return TypeId{ .val = id_val, .registry = self };
        } else {
            return null;
        }
    }
};

/// A stable identifier for a type in the `TypeRegistry`.
pub const TypeId = struct {
    pub const Val = usize;
    pub const INVALID_ID: Val = std.math.maxInt(Val);
    pub const invalid = TypeId{};

    val: Val = INVALID_ID,
    registry: *const TypeRegistry,

    /// Equality check based on both the ID value and the registry pointer.
    pub fn eql(self: @This(), other: @This()) bool {
        return self.val == other.val and self.registry == other.registry;
    }

    /// Gets the metadata for this type ID from the registry.
    pub fn meta(self: @This()) TypeMeta {
        std.debug.assert(self.val < self.registry.meta_list.items.len);
        return self.registry.meta_list.items[self.val];
    }
};

/// Metadata for a type in the `TypeRegistry`.
pub const TypeMeta = struct {
    /// The type address is used as a key for registration and lookup, but is not guaranteed to be dense or ordered.
    addr: TypeAddress = .invalid,
    /// The size of the type.
    size: usize = 0,
    /// The alignment of the type.
    alignment: usize = 0,
    /// The name of the type.
    name: []const u8 = "",

    pub fn init(comptime T: type) @This() {
        return .{
            .addr = TypeAddress.of(T),
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

    const ValidateError =
        TypeAddress.ValidateError ||
        error{
            /// If alignment is greater than 0, it must be a power of two.
            AlignmentNotPowerOfTwo,
            /// If alignment is greater than 0, it must divide the size evenly.
            AlignmentNotDivisibleBySize,
            /// If alignment is 0, size must also be 0 (e.g. for void type).
            SizeNotZeroWithZeroAlignment,
        };

    /// Validates the invariants of the TypeMeta struct.
    pub fn validate(self: @This()) ValidateError!void {
        // A valid TypeMeta must have a valid address,
        try self.addr.validate();
        if (self.alignment > 0) {
            if (!std.math.isPowerOfTwo(self.alignment)) {
                return ValidateError.AlignmentNotPowerOfTwo;
            }
            if (self.size % self.alignment != 0) {
                return ValidateError.AlignmentNotDivisibleBySize;
            }
        } else {
            if (self.size > 0) {
                return ValidateError.SizeNotZeroWithZeroAlignment;
            }
            // Allow zero sized type like void to be registered.
        }
    }

    /// Checks if the TypeMeta is valid according to the validate function.
    pub fn isValid(self: @This()) bool {
        self.validate() catch {
            return false;
        };
        return true;
    }
};

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

test "TypeAddress - stable per type and distinct across different types" {
    const a1 = TypeAddress.of(u32);
    const a2 = TypeAddress.of(u32);
    const b = TypeAddress.of(i32);

    try expectEqual(a1.val, a2.val);
    try expect(a1.val != b.val);
}

test "TypeRegistry - register returns stable id for same type and stores correct meta" {
    var registry = TypeRegistry.init(std.testing.allocator);
    defer registry.deinit();

    const id1 = try registry.register(.init(u32));
    const id2 = try registry.register(.init(u32));

    try expect(id1.eql(id2));
    try expect(id1.registry == &registry);

    const meta = id1.meta();
    try expectEqual(TypeAddress.of(u32).val, meta.addr.val);
    try expectEqual(@sizeOf(u32), meta.size);
    try expectEqual(@alignOf(u32), meta.alignment);
    try expectEqualStrings(@typeName(u32), meta.name);

    const lookup = registry.typeToId(u32).?;
    try expect(lookup.eql(id1));
}

test "TypeRegistry - register assigns consecutive ids for new types" {
    var registry = TypeRegistry.init(std.testing.allocator);
    defer registry.deinit();

    const id_a = try registry.register(.init(u8));
    const id_b = try registry.register(.init(i16));

    try expectEqual(@as(TypeId.Val, 0), id_a.val);
    try expectEqual(@as(TypeId.Val, 0), registry.addrToId(TypeAddress.of(u8)).?.val);
    try expectEqual(@as(TypeId.Val, 1), id_b.val);
    try expectEqual(@as(TypeId.Val, 1), registry.addrToId(TypeAddress.of(i16)).?.val);
}

test "TypeRegistry - register revoke operation when out of memory" {
    const Ctx = struct {
        fn run(allocator: Allocator) !void {
            var registry = TypeRegistry.init(allocator);
            defer registry.deinit();

            const id = registry.register(.init(u32)) catch |err| switch (err) {
                error.OutOfMemory => {
                    // failure path: the registry should be left in a consistent state with no partial registration
                    try expectEqual(@as(usize, 0), registry.meta_list.items.len);
                    try expectEqual(@as(usize, 0), registry.addr_to_id.count());
                    try expect(registry.typeToId(u32) == null);
                    return err;
                },
            };

            // success path: the registry should contain the new type with correct metadata
            try expectEqual(@as(TypeId.Val, 0), id.val);
            try expectEqual(@as(usize, 1), registry.meta_list.items.len);
            try expectEqual(@as(usize, 1), registry.addr_to_id.count());
            try expect(registry.typeToId(u32).?.eql(id));
        }
    };

    try std.testing.checkAllAllocationFailures(std.testing.allocator, Ctx.run, .{});
}

test "TypeRegistry - typeToId returns null for unregistered type" {
    var registry = TypeRegistry.init(std.testing.allocator);
    defer registry.deinit();

    try expect(registry.typeToId(u64) == null);
}

test "TypeId - equality includes registry identity" {
    var registry_a = TypeRegistry.init(std.testing.allocator);
    defer registry_a.deinit();

    var registry_b = TypeRegistry.init(std.testing.allocator);
    defer registry_b.deinit();

    const id_a = try registry_a.register(.init(u8));
    const id_b = try registry_b.register(.init(u8));

    try expect(!id_a.eql(id_b));
}
