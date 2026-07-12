//! Logger defines the API for creating and recording traces.
//! It is designed to be implemented by different backends like `Allocator`.

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
/// The minimum level of events that will be recorded.
/// Events below this level will be silently discarded.
/// Can be overridden by `Trace.event_level`.
event_level: Event.Level = .info,

pub const VTable = struct {
    allocTraceId: *const fn (self: *anyopaque) Trace.Id,
    decideTraceFlag: *const fn (self: *anyopaque, trace_id: Trace.Id) Trace.Flag,
    allocSpanId: *const fn (self: *anyopaque, trace_id: Trace.Id) Span.Id,
    recordSpan: *const fn (self: *anyopaque, span: *const Span) void,
    recordEvent: *const fn (self: *anyopaque, event: *const Event) void,
    getResource: *const fn (self: *anyopaque) Resource,
};

/// Identifies the library or component that is producing log.
pub const Scope = struct {
    name: []const u8,
    version: ?[]const u8 = null,
};

/// The runtime environment of the logger. It is supposed to be implemented by the backend.
/// Once the resource is set, it cannot be changed.
/// host.name, service.name, os.type, etc.
pub const Resource = []const Attribute;

/// Allocate a new trace ID. It is used to uniquely identify a trace across the system.
/// 0 is reserved for invalid trace ID.
pub fn allocTraceId(self: @This()) Trace.Id {
    const rv = self.vtable.allocTraceId(self.ptr);
    std.debug.assert(rv != Trace.INVALID_ID);
    return rv;
}

/// Control the behavior of the trace. See `Trace.Flag` for more details.
pub fn decideTraceFlag(self: @This(), trace_id: Trace.Id) Trace.Flag {
    return self.vtable.decideTraceFlag(self.ptr, trace_id);
}

/// Allocate a new span ID. It is used to uniquely identify a span within a trace.
/// 0 is reserved for invalid span ID.
pub fn allocSpanId(self: @This(), trace_id: Trace.Id) Span.Id {
    const rv = self.vtable.allocSpanId(self.ptr, trace_id);
    std.debug.assert(rv != Span.INVALID_ID);
    return rv;
}

/// Start a new trace. It returns a `Trace` object that can be used to start spans and events.
pub fn startTrace(self: @This()) Trace {
    return Trace.start(self);
}

/// Log the span information to the backend, use pointer since `Span` is a big struct.
pub fn recordSpan(self: @This(), span: *const Span) void {
    self.vtable.recordSpan(self.ptr, span);
}

/// Log the event information to the backend, use pointer since `Event` is a big struct.
pub fn recordEvent(self: @This(), event: *const Event) void {
    const level =
        if (event.trace.event_level != self.event_level)
            event.trace.event_level
        else
            self.event_level;
    if (event.level < level) return;
    self.vtable.recordEvent(self.ptr, event);
}

/// Get the resource information of the logger.
pub fn getResource(self: @This()) Resource {
    return self.vtable.getResource(self.ptr);
}
