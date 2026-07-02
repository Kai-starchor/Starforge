/// Span represents a single unit of work within a trace. It contains information about the operation being
/// performed, such as its name, start time, end time, any associated attributes, etc.
pub const Span = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const Timestamp = std.Io.Clock.Timestamp;

const root = @import("../root.zig");
const Logger = root.trace.Logger;
const Trace = root.trace.Trace;
const Event = root.trace.Event;
const Attribute = root.trace.Attribute;

pub const Id = u64;

allocator: Allocator,
logger: Logger,
trace_id: Trace.Id,
span_id: Span.Id,
parent_span_id: ?Id = null,
status: Status = .unset,
name: []const u8,
module: ?[]const u8 = null,
message: ?[]const u8 = null,
real_start_ts: Timestamp,
awake_start_ts: Timestamp,
awake_end_ts: ?Timestamp = null,
links: std.ArrayList(Link) = .empty,
attrs: std.ArrayList(Attribute) = .empty,

pub const Status = enum(i8) {
    unset = 0,
    ok = 1,
    err = -1,

    pub fn toString(self: @This()) []const u8 {
        return switch (self) {
            .unset => "UNSET",
            .ok => "OK",
            .err => "ERROR",
        };
    }
};

pub const Link = struct {
    trace_id: Trace.Id,
    span_id: Span.Id,
    attrs: std.ArrayList(Attribute) = .empty,
};

pub fn start(allocator: Allocator, io: std.Io, trace: Trace, name: []const u8) @This() {
    return .{
        .allocator = allocator,
        .logger = trace.logger,
        .trace_id = trace.trace_id,
        .span_id = trace.logger.allocSpanId(trace.trace_id),
        .name = name,
        .real_start_ts = std.Io.Clock.real.now(io),
        .awake_start_ts = std.Io.Clock.awake.now(io),
    };
}

pub fn startSubSpan(self: @This(), allocator: Allocator, io: std.Io, name: []const u8) @This() {
    return .{
        .allocator = allocator,
        .logger = self.logger,
        .trace_id = self.trace_id,
        .span_id = self.logger.allocSpanId(self.trace_id),
        .parent_span_id = self.span_id,
        .name = name,
        .module = self.module,
        .real_start_ts = std.Io.Clock.real.now(io),
        .awake_start_ts = std.Io.Clock.awake.now(io),
    };
}

pub fn emit(self: *@This(), io: std.Io) void {
    self.awake_end_ts = std.Io.Clock.awake.now(io);
    self.logger.recordSpan(self);
    self.links.deinit(self.allocator);
    self.attrs.deinit(self.allocator);
}

pub fn addLinks(self: *@This(), links: []const Link) Allocator.Error!void {
    try self.links.appendSlice(self.allocator, links);
}

pub fn addAttrs(self: *@This(), attrs: []const Attribute) Allocator.Error!void {
    try self.attrs.appendSlice(self.allocator, attrs);
}

pub fn startEvent(self: @This(), allocator: Allocator, io: std.Io, level: Logger.Level, name: []const u8) Event {
    return Event.start(allocator, io, self, level, name);
}
