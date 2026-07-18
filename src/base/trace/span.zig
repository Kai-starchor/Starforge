//! Span represents a single unit of work within a trace. It contains information about the
//! operation being performed, such as its name, start time, end time, attributes, etc.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Timestamp = std.Io.Timestamp;

const root = @import("../root.zig");
const Logger = root.trace.Logger;
const Trace = root.trace.Trace;
const Event = root.trace.Event;
const Attribute = root.trace.Attribute;

pub const Id = u64;
pub const INVALID_ID: Id = 0;

trace: Trace,
id: Id,
parent_span_id: ?Id = null,
status: Status = .unset,
kind: Kind,
name: []const u8,
/// Locate the span in a timeline.
real_start_ts: Timestamp,
/// Measure durations.
awake_start_ts: Timestamp,
real_end_ts: ?Timestamp = null,
awake_end_ts: ?Timestamp = null,
/// Relationship between two spans across different traces or services.
links: std.ArrayList(Link) = .empty,
attrs: std.ArrayList(Attribute) = .empty,

/// Status defines the outcome of a span, indicating whether it completed successfully or
/// encountered an error.
pub const Status = enum(i8) {
    /// The span has not yet been completed, and its status is not yet determined.
    unset = 0,
    /// The span completed successfully without any errors.
    ok = 1,
    /// The span encountered an error during its execution.
    err = -1,

    pub fn toString(self: @This()) []const u8 {
        return switch (self) {
            .unset => "UNSET",
            .ok => "OK",
            .err => "ERROR",
        };
    }
};

/// Describes the role of a span in a trace.
/// It helps to categorize spans based on their function in the system.
pub const Kind = enum(u8) {
    /// Internal operation within system, not involving any cross-network/process communication.
    internal = 0,
    /// Server-side handling of a synchronous request, HTTP Server, gRPC server, etc. Usually paired
    /// with a client span in another service.
    /// This span should be created when a request is received and should be closed when the
    /// response is sent.
    server = 1,
    /// Client-side request to a server, HTTP Client, gRPC client, etc. Usually paired with a server
    /// span in another service.
    /// This span should be created when a request is sent and should be closed when the response is
    /// received.
    client = 2,
    /// Producer of an asynchronous message, Kafka, SQS, etc. Usually paired with a consumer span in
    /// another service.
    /// This span won't wait for a response, the message might not be consumed when the span is
    /// closed.
    producer = 3,
    /// Consumer of an asynchronous message, Kafka, SQS, etc. Usually paired with a producer span in
    /// another service.
    /// This span might be created way after the message was produced.
    consumer = 4,

    pub fn toString(self: @This()) []const u8 {
        return switch (self) {
            .internal => "INTERNAL",
            .server => "SERVER",
            .client => "CLIENT",
            .producer => "PRODUCER",
            .consumer => "CONSUMER",
        };
    }
};

/// Link represents a relationship between two spans, allowing for the representation of complex
/// trace structures that are not strictly hierarchical. It can be used to represent relationships
/// such as "follows from" or "caused by", and can be used to correlate spans across different
/// traces or services.
pub const Link = struct {
    /// The trace ID of the linked span.
    trace_id: Trace.Id,
    /// The span ID of the linked span.
    span_id: Id,
    /// The attributes associated with the link, providing additional context or metadata about the
    /// relationship.
    attrs: std.ArrayList(Attribute) = .empty,
};

pub fn start(trace: Trace, kind: Kind, name: []const u8) @This() {
    const io = trace.logger.getIo();
    return .{
        .trace = trace,
        .id = trace.logger.allocSpanId(trace.id),
        .kind = kind,
        .name = name,
        .real_start_ts = std.Io.Clock.real.now(io),
        .awake_start_ts = std.Io.Clock.awake.now(io),
    };
}

pub fn startSubSpan(self: @This(), kind: Kind, name: []const u8) @This() {
    const io = self.trace.logger.getIo();
    return .{
        .trace = self.trace,
        .id = self.trace.logger.allocSpanId(self.trace.id),
        .kind = kind,
        .parent_span_id = self.id,
        .name = name,
        .real_start_ts = std.Io.Clock.real.now(io),
        .awake_start_ts = std.Io.Clock.awake.now(io),
    };
}

/// Emit the span to the logger and deinit it.
pub fn emit(self: *@This(), status: Status) void {
    const io = self.trace.logger.getIo();
    self.real_end_ts = std.Io.Clock.real.now(io);
    self.awake_end_ts = std.Io.Clock.awake.now(io);
    self.status = status;
    self.trace.logger.recordSpan(self);
    self.deinit();
}

pub fn deinit(self: *@This()) void {
    const allocator = self.trace.logger.getAllocator();
    for (self.links.items) |*link| {
        for (link.attrs.items) |*attr| attr.value.deinit(allocator);
        link.attrs.deinit(allocator);
    }
    self.links.deinit(allocator);
    for (self.attrs.items) |*attr| attr.value.deinit(allocator);
    self.attrs.deinit(allocator);
}

pub fn addLinks(self: *@This(), links: []const Link) Allocator.Error!void {
    try self.links.appendSlice(self.trace.logger.getAllocator(), links);
}

pub fn addAttrs(self: *@This(), attrs: []const Attribute) Allocator.Error!void {
    try self.attrs.appendSlice(self.trace.logger.getAllocator(), attrs);
}

pub fn startEvent(self: @This(), level: Event.Level, name: []const u8) Event {
    return Event.start(self, level, name);
}
