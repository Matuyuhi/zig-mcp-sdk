const std = @import("std");

/// Append a JSON-escaped string (with surrounding quotes) to the list
pub fn appendJsonString(list: *std.ArrayList(u8), allocator: std.mem.Allocator, s: []const u8) !void {
    try list.append(allocator, '"');
    for (s) |c| {
        switch (c) {
            '"' => try list.appendSlice(allocator, "\\\""),
            '\\' => try list.appendSlice(allocator, "\\\\"),
            '\n' => try list.appendSlice(allocator, "\\n"),
            '\r' => try list.appendSlice(allocator, "\\r"),
            '\t' => try list.appendSlice(allocator, "\\t"),
            else => {
                if (c < 0x20) {
                    var buf: [6]u8 = undefined;
                    const hex = std.fmt.bufPrint(&buf, "\\u{x:0>4}", .{@as(u16, c)}) catch continue;
                    try list.appendSlice(allocator, hex);
                } else {
                    try list.append(allocator, c);
                }
            },
        }
    }
    try list.append(allocator, '"');
}

/// Convert a JSON Value representing an id to its JSON text representation.
pub fn formatId(value: ?std.json.Value, buf: []u8) []const u8 {
    const val = value orelse return "null";
    switch (val) {
        .null => return "null",
        .integer => |n| {
            return std.fmt.bufPrint(buf, "{d}", .{n}) catch "null";
        },
        .string => |s| {
            var pos: usize = 0;
            if (pos < buf.len) {
                buf[pos] = '"';
                pos += 1;
            }
            for (s) |c| {
                if (pos >= buf.len - 1) break;
                if (c == '"' or c == '\\') {
                    if (pos < buf.len - 1) {
                        buf[pos] = '\\';
                        pos += 1;
                    }
                }
                buf[pos] = c;
                pos += 1;
            }
            if (pos < buf.len) {
                buf[pos] = '"';
                pos += 1;
            }
            return buf[0..pos];
        },
        else => return "null",
    }
}

/// Build JSON-RPC error response as an allocated string
pub fn buildJsonRpcError(allocator: std.mem.Allocator, id_json: []const u8, code: i32, message: []const u8) ![]const u8 {
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(allocator);

    try list.appendSlice(allocator, "{\"jsonrpc\":\"2.0\",\"id\":");
    try list.appendSlice(allocator, id_json);
    try list.appendSlice(allocator, ",\"error\":{\"code\":");
    var code_buf: [16]u8 = undefined;
    const code_str = std.fmt.bufPrint(&code_buf, "{d}", .{code}) catch "0";
    try list.appendSlice(allocator, code_str);
    try list.appendSlice(allocator, ",\"message\":");
    try appendJsonString(&list, allocator, message);
    try list.appendSlice(allocator, "}}\n");

    return try allocator.dupe(u8, list.items);
}

/// Build JSON-RPC success response with a raw JSON result
pub fn buildJsonRpcResult(allocator: std.mem.Allocator, id_json: []const u8, result_json: []const u8) ![]const u8 {
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(allocator);

    try list.appendSlice(allocator, "{\"jsonrpc\":\"2.0\",\"id\":");
    try list.appendSlice(allocator, id_json);
    try list.appendSlice(allocator, ",\"result\":");
    try list.appendSlice(allocator, result_json);
    try list.appendSlice(allocator, "}\n");

    return try allocator.dupe(u8, list.items);
}

/// Build MCP tool result (success or error) as an allocated string
pub fn buildToolResult(allocator: std.mem.Allocator, id_json: []const u8, text: []const u8, is_error: bool) ![]const u8 {
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(allocator);

    try list.appendSlice(allocator, "{\"jsonrpc\":\"2.0\",\"id\":");
    try list.appendSlice(allocator, id_json);
    try list.appendSlice(allocator, ",\"result\":{\"content\":[{\"type\":\"text\",\"text\":");
    try appendJsonString(&list, allocator, text);
    try list.appendSlice(allocator, "}],\"isError\":");
    if (is_error) {
        try list.appendSlice(allocator, "true");
    } else {
        try list.appendSlice(allocator, "false");
    }
    try list.appendSlice(allocator, "}}\n");

    return try allocator.dupe(u8, list.items);
}

/// Build the initialize response.
pub fn buildInitializeResult(allocator: std.mem.Allocator, id_json: []const u8, server_name: []const u8, server_version: []const u8) ![]const u8 {
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(allocator);

    try list.appendSlice(allocator, "{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{}},\"serverInfo\":{\"name\":");
    try appendJsonString(&list, allocator, server_name);
    try list.appendSlice(allocator, ",\"version\":");
    try appendJsonString(&list, allocator, server_version);
    try list.appendSlice(allocator, "}}");

    const result_json = try allocator.dupe(u8, list.items);
    defer allocator.free(result_json);

    return try buildJsonRpcResult(allocator, id_json, result_json);
}

// --- Tests ---

const testing = std.testing;

test "formatId with integer" {
    var buf: [256]u8 = undefined;
    const result = formatId(.{ .integer = 42 }, &buf);
    try testing.expectEqualStrings("42", result);
}

test "formatId with string" {
    var buf: [256]u8 = undefined;
    const result = formatId(.{ .string = "abc" }, &buf);
    try testing.expectEqualStrings("\"abc\"", result);
}

test "formatId with null" {
    var buf: [256]u8 = undefined;
    try testing.expectEqualStrings("null", formatId(null, &buf));
    try testing.expectEqualStrings("null", formatId(.null, &buf));
}

test "buildJsonRpcError" {
    const allocator = testing.allocator;
    const result = try buildJsonRpcError(allocator, "1", -32600, "Invalid Request");
    defer allocator.free(result);
    // Verify it contains the expected structure
    try testing.expect(std.mem.indexOf(u8, result, "\"jsonrpc\":\"2.0\"") != null);
    try testing.expect(std.mem.indexOf(u8, result, "\"id\":1") != null);
    try testing.expect(std.mem.indexOf(u8, result, "\"code\":-32600") != null);
    try testing.expect(std.mem.indexOf(u8, result, "\"message\":\"Invalid Request\"") != null);
}

test "buildJsonRpcResult" {
    const allocator = testing.allocator;
    const result = try buildJsonRpcResult(allocator, "5", "{\"ok\":true}");
    defer allocator.free(result);
    try testing.expect(std.mem.indexOf(u8, result, "\"id\":5") != null);
    try testing.expect(std.mem.indexOf(u8, result, "\"result\":{\"ok\":true}") != null);
}

test "buildToolResult success" {
    const allocator = testing.allocator;
    const result = try buildToolResult(allocator, "3", "done", false);
    defer allocator.free(result);
    try testing.expect(std.mem.indexOf(u8, result, "\"isError\":false") != null);
    try testing.expect(std.mem.indexOf(u8, result, "\"text\":\"done\"") != null);
}

test "buildToolResult error" {
    const allocator = testing.allocator;
    const result = try buildToolResult(allocator, "3", "fail", true);
    defer allocator.free(result);
    try testing.expect(std.mem.indexOf(u8, result, "\"isError\":true") != null);
    try testing.expect(std.mem.indexOf(u8, result, "\"text\":\"fail\"") != null);
}

test "buildInitializeResult" {
    const allocator = testing.allocator;
    const result = try buildInitializeResult(allocator, "1", "test-server", "0.1.0");
    defer allocator.free(result);
    try testing.expect(std.mem.indexOf(u8, result, "\"protocolVersion\":\"2024-11-05\"") != null);
    try testing.expect(std.mem.indexOf(u8, result, "\"name\":\"test-server\"") != null);
    try testing.expect(std.mem.indexOf(u8, result, "\"version\":\"0.1.0\"") != null);
}

test "appendJsonString escapes special characters" {
    const allocator = testing.allocator;
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(allocator);
    try appendJsonString(&list, allocator, "hello\n\"world\"\\");
    try testing.expectEqualStrings("\"hello\\n\\\"world\\\"\\\\\"", list.items);
}
