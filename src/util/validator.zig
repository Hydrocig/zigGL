const std = @import("std");

const errors = @import("./errors.zig");

/// Validates and cleans up a path string
pub fn cleanPath(path: []const u8) ![]const u8 {
    // Convert backslashes to forward slashes
    var buffer: [256]u8 = undefined;
    _ = std.mem.replace(u8, path, "\\", "/", &buffer);
    const trimmed:[256]u8 = buffer;

    // Find null terminator and create slice
    const actual_len = std.mem.indexOfScalar(u8, &trimmed, 0) orelse path.len;
    const trimmed2 = std.mem.trim(u8, trimmed[0..actual_len], " \t\n\r\""); // Trim spaces and quotes

    // Validate Path
    if (trimmed2.len >= 256) return errors.ErrorCode.PathTooLong;
    if (trimmed2.len == 0) return errors.ErrorCode.EmptyPath;
    if (!std.fs.path.isAbsolute(trimmed2)) return errors.ErrorCode.InvalidPath;

    return trimmed2;
}