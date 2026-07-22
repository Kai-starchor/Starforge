const std = @import("std");

pub const MOD_NAME = "base";

pub fn build(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    const mod = b.addModule(MOD_NAME, .{
        .root_source_file = b.path("src/base/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    return mod;
}
