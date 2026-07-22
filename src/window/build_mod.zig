const std = @import("std");

pub const MOD_NAME = "window";

pub fn build(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    imports: []const std.Build.Module.Import,
) *std.Build.Module {
    const mod = b.addModule(MOD_NAME, .{
        .root_source_file = b.path("src/window/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = imports,
    });

    const tag = target.result.os.tag;
    switch (tag) {
        .windows => {
            mod.linkSystemLibrary("kernel32", .{});
            mod.linkSystemLibrary("user32", .{});
        },
        else => std.debug.panic("unsupported target os: {s}", .{@tagName(tag)}),
    }

    return mod;
}
