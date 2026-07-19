pub const mem = struct {
    pub const AlignedBuffer = @import("mem/aligned_buffer.zig");
};

pub const string = struct {
    pub const String = @import("string/string.zig");
};

pub const trace = struct {
    pub const Logger = @import("trace/logger.zig");
    pub const Trace = @import("trace/trace.zig");
    pub const Span = @import("trace/span.zig");
    pub const Event = @import("trace/event.zig");
    pub const Attribute = @import("trace/attribute.zig");
};

pub const Type = struct {
    pub const Address = @import("type/address.zig");
    pub const Registry = @import("type/registry.zig");
    pub const Id = @import("type/id.zig");
    pub const Meta = @import("type/meta.zig");
};

pub const util = struct {
    pub const random = @import("util/random.zig");
    pub const EpochTime = @import("util/epoch_time.zig");
    pub const Uuid = @import("util/uuid/uuid.zig").Uuid;
};

test {
    _ = mem.AlignedBuffer;
    _ = string.String;
    _ = trace.Logger;
    _ = trace.Logger.TestingLogger;
    _ = trace.Trace;
    _ = trace.Span;
    _ = trace.Event;
    _ = trace.Attribute;
    _ = Type.Address;
    _ = Type.Registry;
    _ = Type.Id;
    _ = Type.Meta;
    _ = util.random;
    _ = util.EpochTime;
    _ = util.Uuid;
}
