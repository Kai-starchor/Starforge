const root = @import("../root.zig");

const base = root.base;
const Type = base.Type;

pub const Interface = struct {
    const VTable = struct {
        deinit: *const fn (self: *anyopaque, ctx: ?*anyopaque) void,
        move: *const fn (dst: *anyopaque, src: *anyopaque, ctx: ?*anyopaque) void,
    };

    vtable: *const VTable,
    ctx: ?*anyopaque = null,

    pub fn Builder(comptime T: type, comptime CtxNullable: ?type) type {
        const Ctx = if (CtxNullable) |CtxType| CtxType else anyopaque;

        const VTableTyped = struct {
            deinit: *const fn (self: *T, ctx: ?*Ctx) void = defaultDeinit,
            move: *const fn (dst: *T, src: *T, ctx: ?*Ctx) void = defaultMove,

            pub fn defaultDeinit(_: *T, _: ?*Ctx) void {}
            pub fn defaultMove(dst: *T, src: *T, _: ?*Ctx) void {
                if (T == anyopaque) {
                    @panic("Default move is not supported for opaque types.");
                }
                dst.* = src.*;
            }
        };

        return struct {
            pub fn build(comptime vtable_typed: *const VTableTyped, ctx: ?*Ctx) Interface {
                const VTableImpl = struct {
                    pub fn deinit(self: *anyopaque, ctx_: ?*anyopaque) void {
                        const typed_self: *T = @ptrCast(@alignCast(self));
                        const typed_ctx: ?*Ctx = if (ctx_) |c| @ptrCast(@alignCast(c)) else null;
                        vtable_typed.deinit(typed_self, typed_ctx);
                    }

                    pub fn move(dst: *anyopaque, src: *anyopaque, ctx_: ?*anyopaque) void {
                        const typed_dst: *T = @ptrCast(@alignCast(dst));
                        const typed_src: *T = @ptrCast(@alignCast(src));
                        const typed_ctx: ?*Ctx = if (ctx_) |c| @ptrCast(@alignCast(c)) else null;
                        vtable_typed.move(typed_dst, typed_src, typed_ctx);
                    }
                };

                return .{
                    .vtable = &.{
                        .deinit = VTableImpl.deinit,
                        .move = VTableImpl.move,
                    },
                    .ctx = if (ctx) |c| @ptrCast(c) else null,
                };
            }
        };
    }
};

type_id: Type.Id,
interface: union(enum) {
    Trivial: void,
    NonTrivial: Interface,
},

pub fn isTrivial(self: @This()) bool {
    return switch (self.interface) {
        .Trivial => true,
        .NonTrivial => false,
    };
}

pub fn eql(self: @This(), other: @This()) bool {
    if (!self.type_id.eql(other.type_id)) return false;

    if (self.isTrivial() != other.isTrivial()) return false;
    if (self.isTrivial()) return true;

    const self_interface = self.interface.NonTrivial;
    const other_interface = other.interface.NonTrivial;
    if (self_interface.vtable != other_interface.vtable) return false;
    if (self_interface.ctx != other_interface.ctx) return false;
    return true;
}

pub const ValidateError = Type.Id.ValidateError;

pub fn validate(self: @This()) ValidateError!void {
    try self.type_id.validate();
}

pub fn isValid(self: @This()) bool {
    self.validate() catch return false;
    return true;
}

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

test "Interface forwards typed component pointers and context" {
    const Context = struct {
        offset: u32,
        deinit_count: usize = 0,
    };
    const Component = struct {
        value: u32,

        fn deinit(self: *@This(), context: ?*Context) void {
            const typed_context = context orelse unreachable;
            typed_context.deinit_count += 1;
            self.value = 0;
        }

        fn move(dst: *@This(), src: *@This(), context: ?*Context) void {
            const typed_context = context orelse unreachable;
            dst.value = src.value + typed_context.offset;
        }
    };

    var context = Context{ .offset = 3 };
    const Builder = Interface.Builder(Component, Context);
    const interface = Builder.build(&.{
        .deinit = Component.deinit,
        .move = Component.move,
    }, &context);
    var src = Component{ .value = 4 };
    var dst = Component{ .value = 0 };

    interface.vtable.move(@ptrCast(&dst), @ptrCast(&src), interface.ctx);
    try expectEqual(@as(u32, 7), dst.value);

    interface.vtable.deinit(@ptrCast(&dst), interface.ctx);
    try expectEqual(@as(u32, 0), dst.value);
    try expectEqual(@as(usize, 1), context.deinit_count);
}

test "Interface supports null context with default callbacks" {
    const Component = struct {
        value: u32,
    };

    const Builder = Interface.Builder(Component, null);
    const interface = Builder.build(&.{}, null);
    var src = Component{ .value = 4 };
    var dst = Component{ .value = 0 };

    interface.vtable.move(@ptrCast(&dst), @ptrCast(&src), interface.ctx);
    try expectEqual(@as(u32, 4), dst.value);

    interface.vtable.deinit(@ptrCast(&dst), interface.ctx);
    try expectEqual(@as(u32, 4), dst.value);
}

test "eql includes type ID, interface kind, vtable, and context" {
    const Context = struct { offset: u32 };
    const Component = struct {
        value: u32,

        fn move(dst: *@This(), src: *@This(), _: ?*Context) void {
            dst.value = src.value + 1;
        }
    };
    const OtherComponent = struct { value: u32 };

    var registry = Type.Registry.init(std.testing.allocator);
    defer registry.deinit();
    const comp_type_id = try registry.register(.init(Component), null);
    const other_type_id = try registry.register(.init(OtherComponent), null);

    // eql type Id
    const trivial = @This(){
        .type_id = comp_type_id,
        .interface = .Trivial,
    };
    try expect(trivial.eql(trivial));
    try expect(!trivial.eql(.{
        .type_id = other_type_id,
        .interface = .Trivial,
    }));

    // eql interface kind
    var first_context = Context{ .offset = 1 };
    const Builder = Interface.Builder(Component, Context);
    const non_trivial = @This(){
        .type_id = comp_type_id,
        .interface = .{ .NonTrivial = Builder.build(&.{}, &first_context) },
    };
    try expect(!trivial.eql(non_trivial));
    try expect(non_trivial.eql(non_trivial));

    // eql vtable
    const different_vtable = @This(){
        .type_id = comp_type_id,
        .interface = .{ .NonTrivial = Builder.build(&.{ .move = Component.move }, &first_context) },
    };
    try expect(!non_trivial.eql(different_vtable));

    // eql context
    var second_context = Context{ .offset = 2 };
    const different_context = @This(){
        .type_id = comp_type_id,
        .interface = .{ .NonTrivial = Builder.build(&.{}, &second_context) },
    };
    try expect(!non_trivial.eql(different_context));
}

test "validate delegates to Type.Id validation" {
    var registry = Type.Registry.init(std.testing.allocator);
    defer registry.deinit();
    const type_id = try registry.register(.init(u32), null);

    const valid = @This(){
        .type_id = type_id,
        .interface = .Trivial,
    };
    try valid.validate();
    try expect(valid.isValid());

    const invalid = @This(){
        .type_id = .{ .val = Type.Id.INVALID_ID, .registry = &registry },
        .interface = .Trivial,
    };
    try expectError(ValidateError.InvalidIdVal, invalid.validate());
    try expect(!invalid.isValid());
}
