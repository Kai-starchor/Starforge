const std = @import("std");

/// UUID generator implementing RFC 9562 (obsoletes RFC 4122)
///
/// RFC 9562: https://www.rfc-editor.org/rfc/rfc9562
pub const Uuid = packed struct {
    sec_a: u48,
    ver: Version,
    sec_b: u12,
    variant: u2 = VARIANT,
    sec_c: u62,

    // TODO Implement other versions of UUID when needed.

    /// The variant field determines the layout of the UUID.
    /// https://www.rfc-editor.org/info/rfc9562/#variant_field
    pub const VARIANT: u2 = 0b10;

    pub const Version = enum(u4) {
        v4 = 0b0100,
        v7 = 0b0111,
    };

    pub const V4 = @import("uuid_v4.zig").V4;
    pub const V7 = @import("uuid_v7.zig").V7;

    pub fn toU128(self: @This()) u128 {
        return @bitCast(self);
    }

    pub fn toBytes(self: @This()) [16]u8 {
        return @bitCast(self);
    }
};

test {
    _ = Uuid.V4;
    _ = Uuid.V7;
}
