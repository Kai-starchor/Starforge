const std = @import("std");

const starforge = @import("starforge");

pub fn main(init: std.process.Init) !void {
    const Logger = starforge.base.trace.Logger;

    var terminal_logger = Logger.TerminalLogger{
        .io = init.io,
        .resource = &.{
            .{ .key = "service.name", .value = .{ .StringView = "trace-example" } },
        },
    };
    const logger = terminal_logger.interface(.{ .name = "trace-example" });
    const trace = logger.startTrace();

    var span = trace.startSpan(init.gpa, init.io, .internal, "example-operation");
    try span.addAttrs(&.{
        .{ .key = "operation.kind", .value = .{ .StringView = "demo" } },
        .{ .key = "attempt", .value = .{ .Int = 1 } },
    });

    var event = span.startEvent(init.gpa, init.io, .info, "operation-started");
    try event.addAttrs(&.{
        .{ .key = "message", .value = .{ .StringView = "terminal logger is working" } },
    });
    event.emit();

    var child_span = span.startSubSpan(init.gpa, init.io, .internal, "child-operation");
    try child_span.addAttrs(&.{
        .{ .key = "completed", .value = .{ .Bool = true } },
    });
    child_span.emit(init.io, .ok);

    span.emit(init.io, .ok);
}
