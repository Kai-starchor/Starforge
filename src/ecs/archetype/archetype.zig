const std = @import("std");

const root = @import("../root.zig");
const base = root.base;
pub const Component = root.Component;
pub const Signature = root.Entity.Signature;
pub const Allocator = std.mem.Allocator;

pub const Id = @import("id.zig");
pub const Meta = @import("meta.zig");
pub const Chunk = @import("chunk.zig");
pub const Registry = @import("registry.zig");

allocator: Allocator,
meta: *Meta,
layout: *Chunk.Layout,
chunks: std.ArrayList(Chunk),
len: usize,

pub fn init(
    allocator: Allocator,
    id: Id,
    unsorted_columns: []const Component.Id,
) Allocator.Error!@This() {
    const meta = try allocator.create(Meta);
    errdefer allocator.destroy(meta);
    meta.* = try Meta.init(allocator, id, unsorted_columns);
    errdefer meta.deinit(allocator);

    const layout = try allocator.create(Chunk.Layout);
    errdefer allocator.destroy(layout);
    layout.* = try Chunk.Layout.init(allocator, meta);
    errdefer layout.deinit(allocator);

    return .{
        .allocator = allocator,
        .meta = meta,
        .layout = layout,
        .chunks = .empty,
        .len = 0,
    };
}

pub fn deinit(self: *@This()) void {
    for (self.chunks.items) |chunk| {
        chunk.deinit(self.allocator);
    }

    self.layout.deinit(self.allocator);
    self.allocator.destroy(self.layout);

    self.meta.deinit(self.allocator);
    self.allocator.destroy(self.meta);
}

test {
    _ = Id;
    _ = Meta;
    _ = Chunk;
    _ = Chunk.Layout;
    _ = Registry;
}
