pub const mem = struct {
    pub const AlignedBuffer = @import("mem/aligned_buffer.zig");
};

pub const trace = struct {
    pub const Logger = @import("trace/logger.zig");
    pub const Trace = @import("trace/trace.zig");
    pub const Span = @import("trace/span.zig");
    pub const Event = @import("trace/event.zig");
    pub const Attribute = @import("trace/attribute.zig");
};

pub const util = struct {
    pub const random = @import("util/random.zig");
    pub const Uuid = @import("util/uuid/uuid.zig").Uuid;
};

test {
    _ = mem.AlignedBuffer;
    _ = trace.Logger;
    _ = trace.Trace;
    _ = trace.Span;
    _ = trace.Event;
    _ = trace.Attribute;
    _ = util.random;
    _ = util.Uuid;
}
