/// Trace represents the entire lifecycle of an operation. It collects a group of related spans, which share the
/// same trace_id.
pub const Trace = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const Timestamp = std.Io.Clock.Timestamp;

const root = @import("../root.zig");
const Logger = root.trace.Logger;
const Span = root.trace.Span;
const Attribute = root.trace.Attribute;

pub const Id = u128;

logger: Logger,
trace_id: Trace.Id,

pub fn start(logger: Logger) @This() {
    return .{
        .logger = logger,
        .trace_id = logger.allocTraceId(),
    };
}

pub fn startSpan(self: @This(), allocator: Allocator, io: std.Io, kind: Span.Kind, name: []const u8) Span {
    return Span.start(allocator, io, self, kind, name);
}
