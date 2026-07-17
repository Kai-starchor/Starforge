//! Event is a single point in time that occurred during the execution of a Span.
//! It can be used to record significant occurrences, such as errors, warnings, or any other
//! noteworthy events that happen during the span's lifetime.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Timestamp = std.Io.Timestamp;

const root = @import("../root.zig");
const Logger = root.trace.Logger;
const Trace = root.trace.Trace;
const Span = root.trace.Span;
const Attribute = root.trace.Attribute;

allocator: Allocator,
trace: Trace,
span_id: Span.Id,
level: Level,
name: []const u8,
real_ts: Timestamp,
attrs: std.ArrayList(Attribute) = .empty,

/// Level defines the severity of an event. It is used to filter events based on their importance.
pub const Level = enum(u8) {
    /// Detailed information for diagnosing problems.
    verbose = 0,
    /// Debug information for development.
    debug = 1,
    /// Confirmation that things are working as expected.
    info = 2,
    /// An indication that something unexpected happened, or indicative of some problem in the near
    /// future (e.g. 'disk space low'). The program is still working as expected.
    warn = 3,
    /// Due to a more serious problem, the program has not been able to work as expected.
    err = 4,
    /// A serious error, indicating that the program may not be able to continue.
    /// This level is used for unrecoverable errors that require immediate attention and may lead to
    /// termination.
    fatal = 5,

    pub fn toString(self: @This()) []const u8 {
        return switch (self) {
            .verbose => "VERBOSE",
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
            .fatal => "FATAL",
        };
    }
};

pub fn start(allocator: Allocator, io: std.Io, span: Span, level: Level, name: []const u8) @This() {
    const duration = span.awake_start_ts.untilNow(io, .awake);
    const real_ts = span.real_start_ts.addDuration(duration);
    return .{
        .allocator = allocator,
        .trace = span.trace,
        .span_id = span.id,
        .level = level,
        .name = name,
        .real_ts = real_ts,
    };
}

pub fn emit(self: *@This()) void {
    self.trace.logger.recordEvent(self);
    for (self.attrs.items) |*attr| attr.value.deinit(self.allocator);
    self.attrs.deinit(self.allocator);
}

pub fn addAttrs(self: *@This(), attrs: []const Attribute) Allocator.Error!void {
    try self.attrs.appendSlice(self.allocator, attrs);
}
