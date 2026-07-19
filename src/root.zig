pub const base = struct {
    const impl = @import("base");
    pub const mem = impl.mem;
    pub const string = impl.string;
    pub const trace = impl.trace;
    pub const Type = impl.Type;
    pub const util = impl.util;
};

pub const ecs = struct {
    const impl = @import("ecs");
    pub const Archetype = impl.Archetype;
    pub const Component = impl.Component;
    pub const Entity = impl.Entity;
};
