//! Trace save a context of the entire lifecycle of an operation.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Timestamp = std.Io.Clock.Timestamp;

const root = @import("../root.zig");
const Logger = root.trace.Logger;
const Span = root.trace.Span;
const Event = root.trace.Event;
const Attribute = root.trace.Attribute;

pub const Id = u128;
pub const INVALID_ID: Id = 0;

logger: Logger,
id: Id,
flag: Flag,
/// The minimum level of events that will be recorded.
/// Events below this level will be silently discarded.
/// Set this to override `Logger.event_level` if you want to specify this trace.
event_level: Event.Level,

/// Control the behavior of the trace.
pub const Flag = packed struct(u8) {
    /// Indicates whether the trace is sampled or not.
    sampled: bool, // bit 0
    /// Reserved bits for future use. Should be set to 0.
    _reserved: u7 = 0, // bits 1-7

    pub fn fromByte(byte: u8) @This() {
        return @bitCast(byte);
    }

    pub fn toByte(self: @This()) u8 {
        return @bitCast(self);
    }
};

/// Start a new trace with the given logger and flag.
/// Use `Logger.startTrace` to call this function unless this trace succeed from other service.
pub fn start(logger: Logger) @This() {
    const id = logger.allocTraceId();
    const flag = logger.decideTraceFlag(id);
    return .{ .logger = logger, .id = id, .flag = flag, .event_level = logger.event_level };
}

/// Start a new span within this trace.
pub fn startSpan(
    self: @This(),
    kind: Span.Kind,
    name: []const u8,
) Span {
    return Span.start(self, kind, name);
}
