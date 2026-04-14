/// zig-mcp-sdk: A lightweight MCP (Model Context Protocol) server library for Zig.
/// Zero dependencies — Zig standard library only.
pub const protocol = @import("protocol.zig");
pub const server = @import("server.zig");
pub const json = @import("json_utils.zig");

// Re-export core types for convenience
pub const Server = server;
pub const ServerConfig = server.ServerConfig;
pub const ToolResult = server.ToolResult;
pub const ToolHandler = server.ToolHandler;

pub const run = server.run;
