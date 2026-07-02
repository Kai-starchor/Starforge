/// Logger defines the API for creating and recording traces.
/// It is designed to be implemented by different backends like `Allocator`.
pub const Logger = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const Trace = root.trace.Trace;
const Span = root.trace.Span;
const Event = root.trace.Event;

/// Level defines the severity of a log message. It is used to filter log messages based on their importance.
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

ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    allocTraceId: *const fn (self: *anyopaque) Trace.Id,
    allocSpanId: *const fn (self: *anyopaque, trace_id: Trace.Id) Span.Id,
    recordTrace: *const fn (self: *anyopaque, trace: *const Trace) void,
    recordSpan: *const fn (self: *anyopaque, span: *const Span) void,
    recordEvent: *const fn (self: *anyopaque, event: *const Event) void,
};

/// Allocate a new trace ID. It is used to uniquely identify a trace across the system.
pub fn allocTraceId(self: @This()) Trace.Id {
    return self.vtable.allocTraceId(self.ptr);
}

/// Allocate a new span ID. It is used to uniquely identify a span within a trace.
pub fn allocSpanId(self: @This(), trace_id: Trace.Id) Span.Id {
    return self.vtable.allocSpanId(self.ptr, trace_id);
}

/// Start a new trace. It returns a `Trace` object that can be used to start spans and events.
pub fn startTrace(self: @This(), allocator: Allocator, io: std.Io) Trace {
    return Trace.start(allocator, io, self);
}

/// Log the trace information to the backend.
pub fn recordTrace(self: @This(), trace: *const Trace) void {
    self.vtable.recordTrace(self.ptr, trace);
}

/// Log the span information to the backend.
pub fn recordSpan(self: @This(), span: *const Span) void {
    self.vtable.recordSpan(self.ptr, span);
}

/// Log the event information to the backend.
pub fn recordEvent(self: @This(), event: *const Event) void {
    self.vtable.recordEvent(self.ptr, event);
}
