pub const mem = struct {
    const aligned_buffer = @import("mem/aligned_buffer.zig");
    pub const AlignedBuffer = aligned_buffer.AlignedBuffer;
};

test {
    _ = mem.aligned_buffer;
}
