//! Validation and sanitation functions

const std = @import("std");

const result = @import("./result.zig");
const errors = @import("./errors.zig");

/// Trims a string by removing whitespace and quotes
pub fn trimString(str: []const u8) []const u8 {
    // Find null terminator if present
    const actual_len = std.mem.indexOfScalar(u8, str, 0) orelse str.len;
    // Trim spaces and quotes
    return std.mem.trim(u8, str[0..actual_len], " \t\n\r\"");
}

/// Validates and cleans up a path string
pub fn cleanPath(allocator: std.mem.Allocator, path: []const u8) !result.Result([]const u8) {
    // Convert backslashes to forward slashes
    var buffer: [256]u8 = undefined;
    _ = std.mem.replace(u8, path, "\\", "/", buffer[0..]);

    // Use the trimString function on the buffer
    const trimmed = trimString(buffer[0..path.len]);

    // Validate Path
    if (trimmed.len >= 256) return result.Result([]const u8).failure(.PathTooLong);
    if (trimmed.len == 0) return result.Result([]const u8).failure(.EmptyPath);
    if (!std.fs.path.isAbsolute(trimmed)) return result.Result([]const u8).failure(.InvalidPath);

    // Duplicate and return
    const stable_slice = try allocator.dupe(u8, trimmed);
    return result.Result([]const u8).success(stable_slice);
}

/// Checks if a file exists
pub fn fileExists(path: []const u8) bool {
    const cleanedPath = trimString(path);
    std.fs.cwd().access(cleanedPath, .{}) catch {
        return false;
    };
    return true;
}
