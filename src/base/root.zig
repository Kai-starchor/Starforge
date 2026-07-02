pub const mem = struct {
    pub const AlignedBuffer = @import("mem/aligned_buffer.zig").AlignedBuffer;
};

pub const trace = struct {
    pub const Logger = @import("trace/logger.zig").Logger;
    pub const Trace = @import("trace/trace.zig").Trace;
    pub const Span = @import("trace/span.zig").Span;
    pub const Event = @import("trace/event.zig").Event;
    pub const Attribute = @import("trace/attribute.zig").Attribute;
};

test {
    _ = mem.AlignedBuffer;
    _ = trace.Logger;
    _ = trace.Trace;
    _ = trace.Span;
    _ = trace.Event;
    _ = trace.Attribute;
}
