pub const base = @import("base");

pub const Archetype = @import("archetype/archetype.zig");

pub const Component = struct {
    pub const Registry = @import("component/registry.zig");
    pub const Id = @import("component/id.zig");
    pub const Meta = @import("component/meta.zig");
};

pub const Entity = struct {
    pub const Id = @import("entity/id.zig");
    pub const Signature = @import("entity/signature.zig");
};

test {
    _ = Archetype;
    _ = Component.Meta;
    _ = Component.Id;
    _ = Component.Registry;
    _ = Entity.Id;
    _ = Entity.Signature;
}
