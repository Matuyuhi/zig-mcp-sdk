const std = @import("std");

const JsonValue = std.json.Value;

/// Extract a string from a JSON value
pub fn getString(val: ?JsonValue) ?[]const u8 {
    const v = val orelse return null;
    return switch (v) {
        .string => |s| s,
        else => null,
    };
}

/// Extract a number (integer or float) from a JSON value as f64
pub fn getNumber(val: ?JsonValue) ?f64 {
    const v = val orelse return null;
    return switch (v) {
        .integer => |n| @floatFromInt(n),
        .float => |f| f,
        else => null,
    };
}

/// Extract a boolean from a JSON value
pub fn getBool(val: ?JsonValue) ?bool {
    const v = val orelse return null;
    return switch (v) {
        .bool => |b| b,
        else => null,
    };
}

/// Extract an object from a JSON value
pub fn getObject(val: ?JsonValue) ?std.json.ObjectMap {
    const v = val orelse return null;
    return switch (v) {
        .object => |o| o,
        else => null,
    };
}

/// Extract an array from a JSON value
pub fn getArray(val: ?JsonValue) ?std.json.Array {
    const v = val orelse return null;
    return switch (v) {
        .array => |a| a,
        else => null,
    };
}
