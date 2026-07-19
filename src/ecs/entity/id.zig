//! Entity ID representation for the ECS system.

const std = @import("std");

pub const INVALID_ID: usize = std.math.maxInt(usize);
pub const INVALID_GENERATION: usize = std.math.maxInt(usize);
pub const invalid: @This() = .{};

/// The index of an entity.
val: usize = INVALID_ID,
/// The generation of an entity, used to reuse the dropped entity's index.
generation: usize = INVALID_GENERATION,

/// Equality check based on both the ID value and the generation.
pub fn eql(self: @This(), other: @This()) bool {
    return self.val == other.val and self.generation == other.generation;
}

pub const ValidateError = error{
    /// The value of the Entity.Id is invalid.
    InvalidIdVal,
    /// The generation of the Entity.Id is invalid.
    InvalidGeneration,
};

pub fn validate(self: @This()) ValidateError!void {
    if (self.val == INVALID_ID) {
        return ValidateError.InvalidIdVal;
    }
    if (self.generation == INVALID_GENERATION) {
        return ValidateError.InvalidGeneration;
    }
}

pub fn isValid(self: @This()) bool {
    self.validate() catch return false;
    return true;
}

const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

test "eql compares both val and generation" {
    const a = @This(){ .val = 1, .generation = 2 };
    const b = @This(){ .val = 1, .generation = 2 };
    const c = @This(){ .val = 1, .generation = 3 };
    const d = @This(){ .val = 2, .generation = 2 };

    try expectEqual(true, a.eql(b));
    try expectEqual(false, a.eql(c));
    try expectEqual(false, a.eql(d));
}

test "validate checks for invalid val and generation" {
    const valid_id = @This(){ .val = 1, .generation = 2 };
    try expectEqual(true, valid_id.isValid());

    const invalid_val_id = @This(){ .val = INVALID_ID, .generation = 2 };
    try expectError(ValidateError.InvalidIdVal, invalid_val_id.validate());

    const invalid_gen_id = @This(){ .val = 1, .generation = INVALID_GENERATION };
    try expectError(ValidateError.InvalidGeneration, invalid_gen_id.validate());
}
