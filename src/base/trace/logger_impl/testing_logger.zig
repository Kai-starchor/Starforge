const std = @import("std");

const root = @import("../../root.zig");
const random = root.util.random;
const Attribute = root.trace.Attribute;
const Event = root.trace.Event;
const Logger = root.trace.Logger;
const Span = root.trace.Span;
const Trace = root.trace.Trace;
const Uuid = root.util.Uuid;

pub const Record = struct {
    pub const Kind = enum { span, event };

    kind: Kind,
    index: usize,
};

allocator: std.mem.Allocator,
io: std.Io,
resource: []const Attribute = &.{},
spans: std.ArrayList(Span) = .empty,
events: std.ArrayList(Event) = .empty,
records: std.ArrayList(Record) = .empty,

pub fn init() @This() {
    return .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
    };
}

pub fn deinit(self: *@This()) void {
    for (self.spans.items) |*span| span.deinit();
    for (self.events.items) |*event| event.deinit();
    self.spans.deinit(self.allocator);
    self.events.deinit(self.allocator);
    self.records.deinit(self.allocator);
}

pub fn interface(self: *@This(), scope: Logger.Scope) Logger {
    return .{
        .ptr = self,
        .vtable = &.{
            .allocTraceId = allocTraceId,
            .decideTraceFlag = decideTraceFlag,
            .allocSpanId = allocSpanId,
            .recordSpan = recordSpan,
            .recordEvent = recordEvent,
            .getResource = getResource,
        },
        .scope = scope,
    };
}

fn allocTraceId(self: *anyopaque) Trace.Id {
    const this: *@This() = @ptrCast(@alignCast(self));
    // Use insecure random for a faster debugging experience.
    return Uuid.V4.initInsecure(.{ .io = this.io }).toU128();
}

fn decideTraceFlag(_: *anyopaque, _: Trace.Id) Trace.Flag {
    return .{ .sampled = true };
}

fn allocSpanId(self: *anyopaque, _: Trace.Id) Span.Id {
    const this: *@This() = @ptrCast(@alignCast(self));
    const source = random.IoSource{ .io = this.io };
    return source.interface().int(Span.Id) | 1;
}

fn recordSpan(self: *anyopaque, span: *Span) void {
    const this: *@This() = @ptrCast(@alignCast(self));
    const index = this.spans.items.len;
    const links = span.links;
    span.links = .empty;
    const attrs = span.attrs;
    span.attrs = .empty;
    var stored_span = span.*;
    stored_span.links = links;
    stored_span.attrs = attrs;
    this.spans.append(this.allocator, stored_span) catch
        @panic("testing logger span allocation failed");
    this.records.append(this.allocator, .{ .kind = .span, .index = index }) catch
        @panic("testing logger record allocation failed");
}

fn recordEvent(self: *anyopaque, event: *Event) void {
    const this: *@This() = @ptrCast(@alignCast(self));
    const index = this.events.items.len;
    const attrs = event.attrs;
    event.attrs = .empty;
    var stored_event = event.*;
    stored_event.attrs = attrs;
    this.events.append(this.allocator, stored_event) catch
        @panic("testing logger event allocation failed");
    this.records.append(this.allocator, .{ .kind = .event, .index = index }) catch
        @panic("testing logger record allocation failed");
}

fn getResource(self: *anyopaque) []const Attribute {
    const this: *@This() = @ptrCast(@alignCast(self));
    return this.resource;
}

const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

test "testing logger preserves attributes and links after emit" {
    const allocator = std.testing.allocator;
    var testing_logger = init();
    defer testing_logger.deinit();

    const logger = testing_logger.interface(.{ .name = "test" });
    const trace = logger.startTrace();
    var span = trace.startSpan(allocator, testing_logger.io, .internal, "operation");
    try span.addAttrs(&.{.{ .key = "span.key", .value = .{ .StringView = "span.value" } }});
    var link = Span.Link{ .trace_id = 1, .span_id = 3 };
    try link.attrs.append(
        allocator,
        .{ .key = "link.key", .value = .{ .StringView = "link.value" } },
    );
    try span.addLinks(&.{link});
    var event = span.startEvent(allocator, testing_logger.io, .info, "started");
    try event.addAttrs(&.{.{ .key = "event.key", .value = .{ .StringView = "event.value" } }});
    event.emit();
    span.emit(testing_logger.io, .ok);

    const events = testing_logger.events.items;
    const spans = testing_logger.spans.items;
    const records = testing_logger.records.items;
    try expectEqual(@as(usize, 2), records.len);

    const event_0 = events[records[0].index];
    try expectEqualStrings("event.name", "started", event_0.name);
    try expectEqualStrings("event.value", event_0.attrs.items[0].value.StringView);

    const span_1 = spans[records[1].index];
    try expectEqualStrings("span.name", "operation", span_1.name);
    try expectEqualStrings("span.value", span_1.attrs.items[0].value.StringView);
    try expectEqual(@as(usize, 1), span_1.links.items.len);
    try expectEqualStrings("link.value", span_1.links.items[0].attrs.items[0].value.StringView);
}

test "testing logger filters events below the logger level" {
    const allocator = std.testing.allocator;
    var testing_logger = init();
    defer testing_logger.deinit();

    const logger = testing_logger.interface(.{ .name = "test" });
    const trace = logger.startTrace();
    var span = trace.startSpan(allocator, testing_logger.io, .internal, "operation");
    var event = span.startEvent(allocator, testing_logger.io, .verbose, "ignored");
    event.emit();
    span.emit(testing_logger.io, .ok);

    try expectEqual(@as(usize, 1), testing_logger.records.items.len);
    try expectEqual(Record.Kind.span, testing_logger.records.items[0].kind);
}
