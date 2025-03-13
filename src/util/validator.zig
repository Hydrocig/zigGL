//! Validation and sanitation functions

const std = @import("std");

const result = @import("./result.zig");
const errors = @import("./errors.zig");

/// Validates and cleans up a path string
pub fn cleanPath(path: []const u8) result.Result([]const u8) {
    // Convert backslashes to forward slashes
    var buffer: [256]u8 = undefined;
    _ = std.mem.replace(u8, path, "\\", "/", &buffer);
    const trimmed: [256]u8 = buffer;

    // Find null terminator and create slice
    const actual_len = std.mem.indexOfScalar(u8, &trimmed, 0) orelse path.len;
    const trimmed2 = std.mem.trim(u8, trimmed[0..actual_len], " \t\n\r\""); // Trim spaces and quotes

    // Validate Path
    if (trimmed2.len >= 256) return result.Result([]const u8).failure(.PathTooLong);
    if (trimmed2.len == 0) return result.Result([]const u8).failure(.EmptyPath);
    if (!std.fs.path.isAbsolute(trimmed2)) return result.Result([]const u8).failure(.InvalidPath);

    return result.Result([]const u8).success(trimmed2);
}
