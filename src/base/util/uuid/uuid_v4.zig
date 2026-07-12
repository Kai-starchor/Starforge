const std = @import("std");

const root = @import("../../root.zig");
const random = root.util.random;
const Uuid = root.util.Uuid;

/// UUIDv4 is meant for generating UUIDs from truly random or pseudorandom numbers.
/// Generate 128 bits of random data that is used to fill out the UUID fields, version and variant
/// then replace the respective bits.
///
/// https://www.rfc-editor.org/info/rfc9562/#section-5.4
pub const V4 = packed struct {
    rand_a: u48,
    ver: Uuid.Version = .v4,
    rand_b: u12,
    variant: u2 = Uuid.VARIANT,
    rand_c: u62,

    /// `rand_src` will use `std.Io.randomSecure` if possible.
    ///
    /// Implementations SHOULD utilize a cryptographically secure pseudorandom number generator to
    /// provide values that are both difficult to predict ("unguessable") and have a low likelihood
    /// of collision ("unique").
    ///
    /// https://www.rfc-editor.org/info/rfc9562/#name-unguessability
    pub fn init(rand_src: random.IoSourceSecure) @This() {
        const rand = rand_src.interface();
        return initImpl(rand);
    }

    /// Faster than `init` but less secure. Use only if you have a good reason to do so.
    pub fn initInsecure(rand_src: random.IoSource) @This() {
        const rand = rand_src.interface();
        return initImpl(rand);
    }

    pub fn initImpl(rand: std.Random) @This() {
        const val = rand.int(u128);
        var rv: @This() = @bitCast(val);
        rv.ver = Uuid.Version.v4;
        rv.variant = Uuid.VARIANT;
        return rv;
    }

    pub fn toUuid(self: @This()) root.util.Uuid {
        return .{
            .sec_a = self.rand_a,
            .ver = self.ver,
            .sec_b = self.rand_b,
            .variant = self.variant,
            .sec_c = self.rand_c,
        };
    }

    pub fn toU128(self: @This()) u128 {
        return @bitCast(self);
    }

    pub fn toString(self: @This()) [16]u8 {
        return @bitCast(self);
    }
};

const expectEqual = std.testing.expectEqual;

test "call init with Io" {
    const io = std.testing.io;
    _ = V4.init(.{ .io = io });
    _ = V4.initInsecure(.{ .io = io });
}

test "type transfer consistency" {
    const raw: u128 = 0xDEADBEEF_CAFEBABE_01234567_89ABCDEF;
    const raw_bytes: [16]u8 = @bitCast(raw);

    var raw_uuid: V4 = @bitCast(raw);
    raw_uuid.ver = Uuid.Version.v4;
    raw_uuid.variant = Uuid.VARIANT;

    var mock = random.MockSource{
        .buffers = &.{&raw_bytes},
    };
    const uuid = V4.initImpl(mock.interface());

    const uuid_as_layout = uuid.toUuid();
    const uuid_as_u128 = uuid.toU128();
    const uuid_as_str = uuid.toString();

    const uuid_from_layout: V4 = @bitCast(uuid_as_layout);
    const uuid_from_u128: V4 = @bitCast(uuid_as_u128);
    const uuid_from_bytes: V4 = @bitCast(uuid_as_str);

    try expectEqual(uuid, raw_uuid);
    try expectEqual(uuid, uuid_from_layout);
    try expectEqual(uuid, uuid_from_u128);
    try expectEqual(uuid, uuid_from_bytes);
}
