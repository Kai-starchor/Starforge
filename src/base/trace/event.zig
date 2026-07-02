/// Event is a single point in time that occurred during the execution of a Span.
/// It can be used to record significant occurrences, such as errors, warnings, or any other noteworthy events that
/// happen during the span's lifetime.
pub const Event = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const Timestamp = std.Io.Clock.Timestamp;

const root = @import("../root.zig");
const Logger = root.trace.Logger;
const Trace = root.trace.Trace;
const Span = root.trace.Span;
const Attribute = root.trace.Attribute;

allocator: Allocator,
logger: Logger,
trace_id: Trace.Id,
span_id: Span.Id,
level: Logger.Level,
name: []const u8,
module: ?[]const u8 = null,
message: ?[]const u8 = null,
real_ts: Timestamp,
attrs: std.ArrayList(Attribute) = .empty,

pub fn start(allocator: Allocator, io: std.Io, span: Span, level: Logger.Level, name: []const u8) @This() {
    const duration = span.awake_start_ts.untilNow(io);
    const real_ts = span.real_start_ts.addDuration(.{ .clock = .real, .raw = duration.raw });
    return .{
        .allocator = allocator,
        .logger = span.logger,
        .trace_id = span.trace_id,
        .span_id = span.span_id,
        .level = level,
        .name = name,
        .real_ts = real_ts,
    };
}

pub fn emit(self: *@This()) void {
    self.logger.recordEvent(self);
    self.attrs.deinit(self.allocator);
}

pub fn addAttrs(self: *@This(), attrs: []const Attribute) Allocator.Error!void {
    try self.attrs.appendSlice(self.allocator, attrs);
}
