const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const starforge_mod = b.addModule("starforge", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    buildExamples(b, target, optimize, starforge_mod);
}

fn buildExamples(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    starforge_mod: *std.Build.Module,
) void {
    inline for ([_]struct {
        name: []const u8,
        path: []const u8,
    }{
        .{ .name = "hello", .path = "examples/hello.zig" },
    }) |example_config| {
        const name = example_config.name;
        const path = example_config.path;

        const prefix_name = std.fmt.allocPrint(b.allocator, "example-{s}", .{name}) catch @panic("OOM");
        const example_mod = b.addModule(prefix_name, .{
            .root_source_file = b.path(path),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "starforge", .module = starforge_mod },
            },
        });

        const example = b.addExecutable(.{
            .name = prefix_name,
            .root_module = example_mod,
        });
        const build_example_cmd = b.addInstallArtifact(example, .{});

        // Add cmd: zig build example-{name}
        const run_step_desc = std.fmt.allocPrint(b.allocator, "Run example: {s}", .{name}) catch @panic("OOM");
        const run_step = b.step(prefix_name, run_step_desc);
        const run_example_cmd = b.addRunArtifact(example);
        run_example_cmd.step.dependOn(&build_example_cmd.step);
        run_step.dependOn(&run_example_cmd.step);
        if (b.args) |args| {
            run_example_cmd.addArgs(args);
        }
    }
}
