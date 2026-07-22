const std = @import("std");

const base = @import("src/base/build_mod.zig");
const ecs = @import("src/ecs/build_mod.zig");
const window = @import("src/window/build_mod.zig");

const Allocator = std.mem.Allocator;

const PROJECT_NAME = "starforge";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const base_mod = base.build(b, target, optimize);
    const ecs_mod = ecs.build(b, target, optimize, &.{
        .{ .name = base.MOD_NAME, .module = base_mod },
    });
    const window_mod = window.build(b, target, optimize, &.{
        .{ .name = base.MOD_NAME, .module = base_mod },
    });

    const starforge_mod = b.addModule(PROJECT_NAME, .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = base.MOD_NAME, .module = base_mod },
            .{ .name = ecs.MOD_NAME, .module = ecs_mod },
            .{ .name = window.MOD_NAME, .module = window_mod },
        },
    });

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(buildTest(b, base.MOD_NAME, base_mod));
    test_step.dependOn(buildTest(b, ecs.MOD_NAME, ecs_mod));
    test_step.dependOn(buildTest(b, window.MOD_NAME, window_mod));

    buildExamples(b, target, optimize, starforge_mod);
}

pub fn buildTest(b: *std.Build, comptime name: []const u8, mod: *std.Build.Module) *std.Build.Step {
    const prefix = "test-" ++ name;
    const mod_tests = b.addTest(.{
        .name = prefix,
        .root_module = mod,
    });

    const test_step_desc = "Run tests of " ++ name;
    const test_step = b.step(prefix, test_step_desc);
    const test_mod_cmd = b.addRunArtifact(mod_tests);
    test_step.dependOn(&test_mod_cmd.step);
    return &test_mod_cmd.step;
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
        .{ .name = "trace", .path = "examples/trace.zig" },
    }) |example_config| {
        const name = example_config.name;
        const path = example_config.path;

        const prefix = "examples-" ++ name;
        const example_mod = b.addModule(prefix, .{
            .root_source_file = b.path(path),
            .target = target,
            .optimize = optimize,
        });
        example_mod.addImport("starforge", starforge_mod);

        const example = b.addExecutable(.{
            .name = prefix,
            .root_module = example_mod,
        });
        const build_example_cmd = b.addInstallArtifact(example, .{});

        // Add cmd: zig build example-{name}
        const run_step_desc = "Run example: " ++ name;
        const run_step = b.step(prefix, run_step_desc);
        const run_example_cmd = b.addRunArtifact(example);
        run_example_cmd.step.dependOn(&build_example_cmd.step);
        run_step.dependOn(&run_example_cmd.step);
        if (b.args) |args| {
            run_example_cmd.addArgs(args);
        }
    }
}
