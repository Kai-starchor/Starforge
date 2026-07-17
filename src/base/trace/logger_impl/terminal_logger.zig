//! A simple logger implementation that prints all traces into stderr, useful for debugging or fast
//! prototyping.
//! All traces are sampled.

const std = @import("std");
const Timestamp = std.Io.Timestamp;
const Writer = std.Io.Writer;

const root = @import("../../root.zig");
const random = root.util.random;
const Logger = root.trace.Logger;
const Trace = root.trace.Trace;
const Uuid = root.util.Uuid;
const Span = root.trace.Span;
const Attribute = root.trace.Attribute;
const EpochTime = root.util.EpochTime;

io: std.Io,
resource: []const Attribute,

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
    const rand_src = random.IoSourceSecure{ .io = this.io };
    const rand = rand_src.interface();
    return rand.int(Span.Id) | 1; // Force the least bit to 1 to avoid zero span ID.
}

fn recordSpan(self: *anyopaque, span: *Span) void {
    const this: *@This() = @ptrCast(@alignCast(self));

    // prepare stderr writer
    var buffer: [64]u8 = undefined;
    const stderr = this.io.lockStderr(&buffer, null) catch return;
    defer this.io.unlockStderr();
    const terminal = stderr.terminal();

    // trace_id-span_id scope_name scope_version start_ts ~ end_ts duration_ms

    writeId(terminal.writer, span.trace.id, span.id);

    const scope = span.trace.logger.scope;
    if (scope.name.len > 0) {
        terminal.writer.print(" {s}", .{scope.name}) catch {};
    }
    if (scope.version) |version| {
        terminal.writer.print(" {s}", .{version}) catch {};
    }
    terminal.writer.writeAll(" ") catch {};

    writeTimestamp(terminal.writer, span.real_start_ts);
    terminal.writer.writeAll(" ~ ") catch {};
    std.debug.assert(span.real_end_ts != null);
    writeTimestamp(terminal.writer, span.real_end_ts.?);

    std.debug.assert(span.awake_end_ts != null);
    const duration = span.awake_start_ts.durationTo(span.awake_end_ts.?).toMilliseconds();
    terminal.writer.print(" {d}ms\n +-- ", .{duration}) catch {};

    // +--status kind name
    terminal.setColor(.bold) catch {};
    terminal.setColor(switch (span.status) {
        .unset => .dim,
        .ok => .green,
        .err => .red,
    }) catch {};
    terminal.writer.print("{s}", .{span.status.toString()}) catch {};
    terminal.setColor(.reset) catch {};
    terminal.writer.print(" {s} {s}\n +-- ", .{ span.kind.toString(), span.name }) catch {};

    // +--attributes
    terminal.setColor(.dim) catch {};
    writeAttributes(terminal.writer, span.attrs.items);
    terminal.setColor(.reset) catch {};
    terminal.writer.writeAll("\n") catch {};

    // +--links
    for (span.links.items) |link| {
        terminal.writer.writeAll(" +-- ") catch {};
        writeId(terminal.writer, link.trace_id, link.span_id);
        terminal.writer.writeAll(" ") catch {};
        terminal.setColor(.dim) catch {};
        writeAttributes(terminal.writer, link.attrs.items);
        terminal.setColor(.reset) catch {};
        terminal.writer.writeAll("\n") catch {};
    }
}

fn recordEvent(self: *anyopaque, event: *root.trace.Event) void {
    const this: *@This() = @ptrCast(@alignCast(self));
    // prepare stderr writer
    var buffer: [64]u8 = undefined;
    const stderr = this.io.lockStderr(&buffer, null) catch return;
    const terminal = stderr.terminal();
    defer this.io.unlockStderr();

    // prefix: trace_id-span_id scope_name scope_version epoch_time
    if (@intFromEnum(event.level) < @intFromEnum(root.trace.Event.Level.info)) {
        terminal.setColor(.dim) catch {};
    }
    writeId(terminal.writer, event.trace.id, event.span_id);

    const scope = event.trace.logger.scope;
    if (scope.name.len > 0) {
        terminal.writer.print(" {s}", .{scope.name}) catch {};
    }
    if (scope.version) |version| {
        terminal.writer.print(" {s}", .{version}) catch {};
    }
    terminal.writer.writeAll(" ") catch {};

    terminal.writer.writeAll(" ") catch {};
    writeTimestamp(terminal.writer, event.real_ts);
    terminal.writer.writeAll("\n +-- ") catch {};

    // +-- log_level event_name
    terminal.setColor(switch (event.level) {
        .verbose => .dim,
        .debug => .reset,
        .info => .green,
        .warn => .yellow,
        .err => .red,
        .fatal => .bright_red,
    }) catch {};
    terminal.setColor(.bold) catch {};
    const level_str = event.level.toString();
    terminal.writer.writeAll(level_str) catch {};
    terminal.setColor(.reset) catch {};

    // event details
    if (@intFromEnum(event.level) < @intFromEnum(root.trace.Event.Level.info)) {
        terminal.setColor(.dim) catch {};
    }
    terminal.writer.print(" {s}\n", .{event.name}) catch {};
    // +-- attributes
    terminal.writer.writeAll(" +-- ") catch {};
    terminal.setColor(.dim) catch {};
    writeAttributes(terminal.writer, event.attrs.items);

    // reset
    terminal.setColor(.reset) catch {};
    terminal.writer.writeAll("\n") catch {};
}

fn getResource(self: *anyopaque) []const Attribute {
    const this: *@This() = @ptrCast(@alignCast(self));
    return this.resource;
}

fn writeId(writer: *Writer, trace_id: u128, span_id: u64) void {
    writer.print("{x:0>32}-{x:0>16}", .{ trace_id, span_id }) catch {};
}

fn writeTimestamp(writer: *Writer, ts: Timestamp) void {
    const epoch_time = EpochTime.fromUnixTimestamp(ts);
    var epoch_time_buf: [19]u8 = undefined;
    const epoch_time_str = epoch_time.toString(&epoch_time_buf);
    writer.writeAll(epoch_time_str) catch {};
}

fn writeAttributes(writer: *Writer, attrs: []const Attribute) void {
    writer.writeAll("{ ") catch {};
    for (attrs, 0..) |attr, i| {
        if (i != 0) writer.writeAll(", ") catch {};
        writer.writeAll(attr.key) catch {};
        writer.writeAll(": ") catch {};
        attr.value.writeTo(writer) catch {};
    }
    writer.writeAll(" }") catch {};
}
