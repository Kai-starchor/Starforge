//! A key-value pair that can be attached to a trace event or span.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;

const root = @import("../root.zig");
const String = root.string.String;

key: []const u8,
value: Value,

pub const Value = union(enum) {
    StringView: []const u8,
    String: String,
    Int: i64,
    Uint: u64,
    Float: f64,
    Bool: bool,
    Array: ArrayValue,

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        switch (self.*) {
            .String => |*str| str.deinit(allocator),
            .Array => |*array| array.deinit(allocator),
            else => {},
        }
    }

    pub fn writeTo(self: @This(), writer: *Writer) Writer.Error!void {
        switch (self) {
            .StringView => |str| try writer.writeAll(str),
            .String => |str| try writer.writeAll(str.slice()),
            .Bool => |b| try writer.writeAll(if (b) "true" else "false"),
            .Array => |array| try array.writeTo(writer),
            inline else => |val| try writer.print("{d}", .{val}),
        }
    }
};

/// The element of an array must be the same type, and cannot be another array.
pub const ArrayValue = union(enum) {
    StringView: std.ArrayList([]const u8),
    String: std.ArrayList(String),
    Int: std.ArrayList(i64),
    Uint: std.ArrayList(u64),
    Float: std.ArrayList(f64),
    Bool: std.ArrayList(bool),

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        switch (self.*) {
            .String => |*string_list| {
                for (string_list.items) |*str| str.deinit(allocator);
                string_list.deinit(allocator);
            },
            inline else => |*list| list.deinit(allocator),
        }
    }

    pub fn writeTo(self: @This(), writer: *Writer) Writer.Error!void {
        switch (self) {
            .StringView => |list| try writeList(writer, list.items, .StringView),
            .String => |list| try writeList(writer, list.items, .String),
            .Int => |list| try writeList(writer, list.items, .Int),
            .Uint => |list| try writeList(writer, list.items, .Uint),
            .Float => |list| try writeList(writer, list.items, .Float),
            .Bool => |list| try writeList(writer, list.items, .Bool),
        }
    }

    fn writeList(
        writer: *Writer,
        items: anytype,
        comptime value_tag: std.meta.FieldEnum(Value),
    ) Writer.Error!void {
        try writer.writeAll("[");
        for (items, 0..) |item, index| {
            if (index != 0) try writer.writeAll(", ");
            const value = @unionInit(Value, @tagName(value_tag), item);
            try value.writeTo(writer);
        }
        try writer.writeAll("]");
    }
};

const expectEqualStrings = std.testing.expectEqualStrings;

fn expectValueWrites(value: Value, expected: []const u8) !void {
    var output = Writer.Allocating.init(std.testing.allocator);
    defer output.deinit();

    try value.writeTo(&output.writer);
    try expectEqualStrings(expected, output.written());
}

test "value writes scalar values" {
    try expectValueWrites(.{ .StringView = "hello" }, "hello");
    try expectValueWrites(.{ .Bool = true }, "true");
    try expectValueWrites(.{ .Bool = false }, "false");
    try expectValueWrites(.{ .Int = -42 }, "-42");
    try expectValueWrites(.{ .Uint = 42 }, "42");
    try expectValueWrites(.{ .Float = 3.5 }, "3.5");
}

test "value writes an owned string" {
    var value = Value{ .String = try String.fromSlice(std.testing.allocator, "owned string") };
    defer value.deinit(std.testing.allocator);

    try expectValueWrites(value, "owned string");
}

test "value writes arrays" {
    const allocator = std.testing.allocator;

    var int_list = try std.ArrayList(i64).initCapacity(allocator, 2);
    try int_list.appendSlice(allocator, &[_]i64{ 1, -2 });
    var int_value = Value{ .Array = .{ .Int = int_list } };
    defer int_value.deinit(allocator);
    try expectValueWrites(int_value, "[1, -2]");

    var str_list = try std.ArrayList([]const u8).initCapacity(allocator, 2);
    try str_list.appendSlice(allocator, &[_][]const u8{ "first", "second" });
    var string_value = Value{ .Array = .{ .StringView = str_list } };
    defer string_value.deinit(allocator);
    try expectValueWrites(string_value, "[first, second]");
}
