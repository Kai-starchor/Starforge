//! A safe wrapper for runtime-aligned buffers. Default to be unmanaged.

const std = @import("std");

const Allocator = std.mem.Allocator;

/// `Private` - Keep original buffer for deallocation.
original: []u8,
/// Provide an aligned view of the original buffer.
aligned: []u8,

/// Init an aligned buffer with the given size and alignment. The original buffer is allocated with
/// `allocator` and should be deallocated with `deinit`.
pub fn init(allocator: Allocator, size: usize, alignment: usize) Allocator.Error!@This() {
    const original = try allocator.alloc(u8, alignedToOriginal(size, alignment));

    const addr = @intFromPtr(original.ptr);
    const offset = std.mem.alignForward(usize, addr, alignment) - addr;
    const aligned = original[offset .. offset + size];

    return @This(){ .original = original, .aligned = aligned };
}

/// Deinit the aligned buffer by freeing the original buffer. After this, the aligned buffer should not be used.
pub fn deinit(self: *@This(), allocator: Allocator) void {
    allocator.free(self.original);
}

/// Convert the original buffer length to the aligned buffer length. Reverse of `alignedToOriginal`.
pub fn originalToAligned(original_len: usize, alignment: usize) usize {
    if (original_len <= alignment) {
        return 0;
    }
    return original_len - alignment + 1;
}

/// Convert the aligned buffer length to the original buffer length. Reverse of `originalToAligned`.
pub fn alignedToOriginal(aligned_len: usize, alignment: usize) usize {
    return aligned_len + alignment - 1;
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "AlignedBuffer - init returns aligned writable slice" {
    const allocator = std.testing.allocator;

    var buffer = try init(allocator, 64, 16);
    defer buffer.deinit(allocator);

    try expectEqual(@as(usize, 64), buffer.aligned.len);
    try expect(@intFromPtr(buffer.aligned.ptr) % 16 == 0);

    @memset(buffer.aligned, 0xAB);
    try expectEqual(@as(u8, 0xAB), buffer.aligned[0]);
    try expectEqual(@as(u8, 0xAB), buffer.aligned[63]);
}

test "AlignedBuffer - init supports multiple runtime alignments" {
    const allocator = std.testing.allocator;

    for ([_]usize{ 1, 2, 4, 8, 16, 32, 64 }) |alignment| {
        var buffer = try init(allocator, 17, alignment);
        defer buffer.deinit(allocator);

        try expectEqual(@as(usize, 17), buffer.aligned.len);
        try expect(@intFromPtr(buffer.aligned.ptr) % alignment == 0);
    }
}

test "AlignedBuffer - init handles zero-sized buffer" {
    const allocator = std.testing.allocator;

    var buffer = try init(allocator, 0, 8);
    defer buffer.deinit(allocator);

    try expectEqual(@as(usize, 0), buffer.aligned.len);
}

test "AlignedBuffer - originalToAligned and alignedToOriginal are consistent" {
    inline for ([_]struct {
        aligned_len: usize,
        alignment: usize,
    }{
        .{ .aligned_len = 64, .alignment = 16 },
        .{ .aligned_len = 17, .alignment = 8 },
        .{ .aligned_len = 0, .alignment = 4 },
    }) |test_case| {
        const original_len = alignedToOriginal(test_case.aligned_len, test_case.alignment);
        const aligned_len = originalToAligned(original_len, test_case.alignment);
        try expectEqual(test_case.aligned_len, aligned_len);
    }
}
