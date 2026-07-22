const std = @import("std");

pub const MOD_NAME = "ecs";

pub fn build(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    imports: []const std.Build.Module.Import,
) *std.Build.Module {
    const mod = b.addModule(MOD_NAME, .{
        .root_source_file = b.path("src/ecs/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = imports,
    });

    return mod;
}
