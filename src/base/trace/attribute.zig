//! A key-value pair that can be attached to a trace event or span.

const std = @import("std");
const Allocator = std.mem.Allocator;

key: []const u8,
value: Value,

pub const Value = union(enum) {
    String: []const u8,
    Int: i64,
    Uint: u64,
    Float: f64,
    Bool: bool,
    Array: ArrayValue,

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        switch (self.*) {
            .Array => |*array| array.deinit(allocator),
            else => {},
        }
    }
};

/// The element of an array must be the same type, and cannot be another array.
pub const ArrayValue = union(enum) {
    String: std.ArrayList([]const u8),
    Int: std.ArrayList(i64),
    Uint: std.ArrayList(u64),
    Float: std.ArrayList(f64),
    Bool: std.ArrayList(bool),

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        switch (self.*) {
            inline else => |*list| list.deinit(allocator),
        }
    }
};
