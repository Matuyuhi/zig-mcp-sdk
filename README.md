# zig-mcp-sdk

A lightweight [Model Context Protocol](https://modelcontextprotocol.io/) (MCP) server library for Zig.

- Zero external dependencies (Zig standard library only)
- Zig 0.15.x compatible (new IO API)
- stdin/stdout JSON-RPC 2.0 transport (newline-delimited)
- MCP protocol version: `2024-11-05`

## Installation

Add the dependency via `zig fetch`:

```bash
zig fetch --save git+https://github.com/Matuyuhi/zig-mcp-sdk.git
```

Then in your `build.zig`, import the module:

```zig
const mcp_dep = b.dependency("zig_mcp_sdk", .{
    .target = target,
    .optimize = optimize,
});

const exe = b.addExecutable(.{
    .name = "my-mcp-server",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zig-mcp-sdk", .module = mcp_dep.module("zig-mcp-sdk") },
        },
    }),
});
```

## Quick Start

```zig
const std = @import("std");
const mcp = @import("zig-mcp-sdk");

// Define your tools as a JSON string (MCP tools/list response body)
const tools_json =
    \\{"tools":[{"name":"hello","description":"Say hello","inputSchema":{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}}]}
;

// Implement the tool handler
fn handleTool(allocator: std.mem.Allocator, name: []const u8, args: std.json.ObjectMap) anyerror!mcp.ToolResult {
    if (std.mem.eql(u8, name, "hello")) {
        const who = mcp.json.getString(args.get("name")) orelse "world";
        const text = try std.fmt.allocPrint(allocator, "Hello, {s}!", .{who});
        return .{ .text = text, .is_error = false };
    }
    const err_text = try std.fmt.allocPrint(allocator, "Unknown tool: {s}", .{name});
    return .{ .text = err_text, .is_error = true };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    try mcp.run(gpa.allocator(), .{
        .name = "my-mcp-server",
        .version = "1.0.0",
        .tools_list_json = tools_json,
        .tool_handler = &handleTool,
    });
}
```

## API Reference

### `mcp.run(allocator, config)`

Starts the MCP server loop, reading JSON-RPC from stdin and writing responses to stdout.

### `mcp.ServerConfig`

| Field | Type | Description |
|---|---|---|
| `name` | `[]const u8` | Server name (returned in `initialize`) |
| `version` | `[]const u8` | Server version |
| `tools_list_json` | `[]const u8` | Raw JSON for `tools/list` response body |
| `tool_handler` | `ToolHandler` | Function pointer for `tools/call` dispatch |

### `mcp.ToolResult`

| Field | Type | Description |
|---|---|---|
| `text` | `[]const u8` | Result text (allocated by the handler) |
| `is_error` | `bool` | `true` if the result represents an error |

### `mcp.ToolHandler`

```zig
*const fn (std.mem.Allocator, []const u8, std.json.ObjectMap) anyerror!ToolResult
```

### `mcp.json` helpers

Convenience functions for extracting values from `std.json.Value`:

| Function | Return type |
|---|---|
| `json.getString(val)` | `?[]const u8` |
| `json.getNumber(val)` | `?f64` |
| `json.getBool(val)` | `?bool` |
| `json.getObject(val)` | `?std.json.ObjectMap` |
| `json.getArray(val)` | `?std.json.Array` |

### `mcp.protocol`

Low-level JSON-RPC response builders (used internally, also available for advanced usage):

- `buildJsonRpcError(allocator, id_json, code, message)` - Error response
- `buildJsonRpcResult(allocator, id_json, result_json)` - Success response
- `buildToolResult(allocator, id_json, text, is_error)` - MCP tool result
- `buildInitializeResult(allocator, id_json, name, version)` - Initialize response
- `formatId(value, buf)` - Format JSON-RPC id
- `appendJsonString(list, allocator, s)` - JSON string escaping

## MCP Protocol Support

| Method | Status |
|---|---|
| `initialize` | Supported |
| `notifications/*` | Acknowledged (no response) |
| `tools/list` | Supported |
| `tools/call` | Supported |

## Testing

```bash
zig build test
```

## Used By

- [16bits-audio-mcp](https://github.com/Matuyuhi/16bits-audio-mcp) - Game audio (BGM/SE/Jingle) generation MCP server

## License

MIT
