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

allocator: Allocator,
logger: Logger,
trace_id: Trace.Id,
links: std.ArrayList(Link) = .empty,
attrs: std.ArrayList(Attribute) = .empty,

pub const Link = struct {
    trace_id: Trace.Id,
    attrs: std.ArrayList(Attribute) = .empty,
};

pub fn start(allocator: Allocator, logger: Logger) @This() {
    return .{
        .allocator = allocator,
        .logger = logger,
        .trace_id = logger.allocTraceId(),
    };
}

pub fn emit(self: *@This()) void {
    self.logger.recordTrace(self);
    self.links.deinit(self.allocator);
    self.attrs.deinit(self.allocator);
}

pub fn addLinks(self: *@This(), links: []const Link) Allocator.Error!void {
    try self.links.appendSlice(self.allocator, links);
}

pub fn addAttrs(self: *@This(), attrs: []const Attribute) Allocator.Error!void {
    try self.attrs.appendSlice(self.allocator, attrs);
}

pub fn startSpan(self: @This(), allocator: Allocator, io: std.Io, name: []const u8) Span {
    return Span.start(allocator, io, self, name);
}
