//! A timestamp expressed in terms of the year, month, day, hours, minutes, and seconds.
//! This is a more human-readable representation of time compared to the raw timestamp.

const std = @import("std");
const Year = std.time.epoch.Year;
const Month = std.time.epoch.Month;

year: Year,
month: Month,
day: u5,
hours: u5,
minutes: u6,
seconds: u6,

const Timestamp = std.Io.Timestamp;

/// Initialize a new `EpochTime` from a Unix epoch timestamp in seconds.
/// The minimum value for the timestamp is 0 (1970-01-01 00:00:00).
pub fn fromUnixTimestamp(timestamp: Timestamp) @This() {
    const secs_raw: i64 = timestamp.toSeconds();
    const secs: u64 = if (secs_raw >= 0) @intCast(secs_raw) else 0;
    const epoch_secs = std.time.epoch.EpochSeconds{ .secs = secs };

    const epoch_day = epoch_secs.getEpochDay();
    const year_day = epoch_day.calculateYearDay();
    const month_day = year_day.calculateMonthDay();
    const day_secs = epoch_secs.getDaySeconds();

    return .{
        .year = year_day.year,
        .month = month_day.month,
        .day = month_day.day_index + 1,
        .hours = day_secs.getHoursIntoDay(),
        .minutes = day_secs.getMinutesIntoHour(),
        .seconds = day_secs.getSecondsIntoMinute(),
    };
}

const BufPrintError = std.fmt.BufPrintError;

/// Transfer the `EpochTime` into a human-readable string format: "YYYY-MM-DD HH:MM:SS".
/// Return a slice of the bytes printed.
///
/// **Assertion:** `buffer` **MUST** be at least 19 bytes long.
pub fn toString(self: @This(), buffer: []u8) []u8 {
    return std.fmt.bufPrint(
        buffer,
        "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}",
        .{ self.year, self.month, self.day, self.hours, self.minutes, self.seconds },
    ) catch unreachable;
}

const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectError = std.testing.expectError;

test "fromUnixTimestamp converts Unix epoch" {
    const time = fromUnixTimestamp(.zero);

    try expectEqual(@as(Year, 1970), time.year);
    try expectEqual(Month.jan, time.month);
    try expectEqual(@as(u5, 1), time.day);
    try expectEqual(@as(u5, 0), time.hours);
    try expectEqual(@as(u6, 0), time.minutes);
    try expectEqual(@as(u6, 0), time.seconds);
}

test "fromUnixTimestamp clamps negative timestamps" {
    const time = fromUnixTimestamp(Timestamp.fromNanoseconds(-1));

    try expectEqual(@as(Year, 1970), time.year);
    try expectEqual(Month.jan, time.month);
    try expectEqual(@as(u5, 1), time.day);
    try expectEqual(@as(u5, 0), time.hours);
    try expectEqual(@as(u6, 0), time.minutes);
    try expectEqual(@as(u6, 0), time.seconds);
}

test "fromUnixTimestamp converts date and time" {
    const timestamp = Timestamp.fromNanoseconds(1_704_164_645 * std.time.ns_per_s);
    const time = fromUnixTimestamp(timestamp);

    try expectEqual(@as(Year, 2024), time.year);
    try expectEqual(Month.jan, time.month);
    try expectEqual(@as(u5, 2), time.day);
    try expectEqual(@as(u5, 3), time.hours);
    try expectEqual(@as(u6, 4), time.minutes);
    try expectEqual(@as(u6, 5), time.seconds);
}

test "toString formats date and time" {
    const time = @This(){
        .year = 2024,
        .month = .jan,
        .day = 2,
        .hours = 3,
        .minutes = 4,
        .seconds = 5,
    };
    var buffer: [19]u8 = undefined;
    const printed = time.toString(&buffer);
    try expectEqualStrings("2024-01-02 03:04:05", printed);
}
