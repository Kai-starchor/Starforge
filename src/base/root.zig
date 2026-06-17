pub const mem = struct {
    pub const AlignedBuffer = @import("mem/aligned_buffer.zig").AlignedBuffer;
};

test {
    _ = mem.AlignedBuffer;
}
