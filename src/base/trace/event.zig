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
level: Level,
name: []const u8,
real_ts: Timestamp,
attrs: std.ArrayList(Attribute) = .empty,

/// Level defines the severity of an event. It is used to filter events based on their importance.
pub const Level = enum(u8) {
    /// Detailed information, typically of interest only when diagnosing problems.
    verbose = 0,
    /// Confirmation that things are working as expected.
    info = 1,
    /// An indication that something unexpected happened, or indicative of some problem in the near future
    /// (e.g. 'disk space low'). The program is still working as expected.
    warn = 2,
    /// Due to a more serious problem, the program has not been able to work as expected.
    err = 3,
    /// A serious error, indicating that the program may not be able to continue.
    /// This level is used for unrecoverable errors that require immediate attention and may lead to termination.
    fatal = 4,

    pub fn toString(self: @This()) []const u8 {
        return switch (self) {
            .verbose => "VERBOSE",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
            .fatal => "FATAL",
        };
    }
};

pub fn start(allocator: Allocator, io: std.Io, span: Span, level: Level, name: []const u8) @This() {
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
