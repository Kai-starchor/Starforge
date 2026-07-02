/// A key-value pair that can be attached to a trace event or span.
pub const Attribute = @This();

key: []const u8,
value: Value,

pub const Value = union(enum) {
    String: []const u8,
    Int: i64,
    Uint: u64,
    Float: f64,
    Bool: bool,
};
