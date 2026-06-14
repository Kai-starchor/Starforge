pub const component = struct {
    const type_registry = @import("component/type_registry.zig");
    pub const TypeAddress = type_registry.TypeAddress;
};

test {
    _ = component.type_registry;
}
