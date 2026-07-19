pub const base = @import("base");

pub const Component = struct {
    pub const Registry = @import("component/registry.zig");
    pub const Id = @import("component/id.zig");
    pub const Meta = @import("component/meta.zig");
};

test {
    _ = Component.Meta;
    _ = Component.Id;
    _ = Component.Registry;
}
