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

/// 16KB, which is the default chunk size in Unity ECS.
/// This is the maximum size of a chunk in bytes.
/// If a chunk exceeds this size, it will be split into multiple chunks.
pub const MAX_CHUNK_BYTE_LEN = 16 * 1024;

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

fn ensureNotFull(self: *@This()) Allocator.Error!void {
    if (self.chunks.items.len == 0) {
        self.layout.resetWithCapacity(1);
        var chunk = try Chunk.init(self.allocator, self.layout);
        errdefer chunk.deinit(self.allocator);
        try self.chunks.append(self.allocator, chunk);
        return;
    }

    if (self.chunks.getLast().len < self.layout.capacity) return;

    // try to extend the chunk until `MAX_CHUNK_BYTE_LEN` if it's the only one
    if (self.chunks.items.len == 1) {
        const new_layout = try Chunk.Layout.init(self.allocator, self.meta);
        errdefer new_layout.deinit(self.allocator);
        if (self.layout.byteLen() * 2 <= MAX_CHUNK_BYTE_LEN) {
            // extend the layout
            new_layout.resetWithCapacity(self.layout.capacity * 2);
        } else {
            // extend the chunk to max, but still need to check whether it's full
            new_layout.resetWithBytesLen(MAX_CHUNK_BYTE_LEN);
        }

        if (new_layout.capacity == self.layout.capacity) {
            new_layout.deinit(self.allocator);
        } else {
            const old_chunk = &self.chunks.items[0];
            var new_chunk = try Chunk.init(self.allocator, &new_layout);
            errdefer new_chunk.deinit(self.allocator);

            // migrate the data from the old chunk to the new chunk
            _ = old_chunk.move(&new_chunk, old_chunk.len);
            old_chunk.deinit(self.allocator);

            self.layout.deinit(self.allocator);
            self.layout.* = new_layout;
            new_chunk.layout = self.layout;

            old_chunk.* = new_chunk;
            return;
        }
    }

    // create a new chunk if the last chunk is full
    var chunk = try Chunk.init(self.allocator, self.layout);
    errdefer chunk.deinit(self.allocator);
    try self.chunks.append(self.allocator, chunk);
}

test {
    _ = Id;
    _ = Meta;
    _ = Chunk;
    _ = Chunk.Layout;
    _ = Registry;
}
