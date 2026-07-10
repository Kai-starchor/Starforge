/// Logger defines the API for creating and recording traces.
/// It is designed to be implemented by different backends like `Allocator`.
pub const Logger = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const Attribute = root.trace.Attribute;
const Trace = root.trace.Trace;
const Span = root.trace.Span;
const Event = root.trace.Event;

ptr: *anyopaque,
vtable: *const VTable,
scope: Scope,

pub const VTable = struct {
    allocTraceId: *const fn (self: *anyopaque) Trace.Id,
    allocSpanId: *const fn (self: *anyopaque, trace_id: Trace.Id) Span.Id,
    recordSpan: *const fn (self: *anyopaque, span: *const Span) void,
    recordEvent: *const fn (self: *anyopaque, event: *const Event) void,
    getResource: *const fn (self: *anyopaque) Resource,
};

/// Identifies the library or component that is producing telemetry.
/// Passed when obtaining a Logger from the provider.
pub const Scope = struct {
    name: []const u8,
    version: ?[]const u8 = null,
};

/// The runtime environment of the logger. It is supposed to be implemented by the backend.
/// Once the resource is set, it cannot be changed.
/// host.name, service.name, os.type, etc.
pub const Resource = []const Attribute;

/// Allocate a new trace ID. It is used to uniquely identify a trace across the system.
pub fn allocTraceId(self: @This()) Trace.Id {
    return self.vtable.allocTraceId(self.ptr);
}

/// Allocate a new span ID. It is used to uniquely identify a span within a trace.
pub fn allocSpanId(self: @This(), trace_id: Trace.Id) Span.Id {
    return self.vtable.allocSpanId(self.ptr, trace_id);
}

/// Start a new trace. It returns a `Trace` object that can be used to start spans and events.
pub fn startTrace(self: @This(), flag: Trace.Flag) Trace {
    return Trace.start(self, flag);
}

/// Log the span information to the backend.
pub fn recordSpan(self: @This(), span: *const Span) void {
    self.vtable.recordSpan(self.ptr, span);
}

/// Log the event information to the backend.
pub fn recordEvent(self: @This(), event: *const Event) void {
    self.vtable.recordEvent(self.ptr, event);
}

/// Get the resource information of the logger.
pub fn getResource(self: @This()) Resource {
    return self.vtable.getResource(self.ptr);
}
