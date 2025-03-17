//! Validation and sanitation functions

const std = @import("std");

const errors = @import("./errors.zig");

/// Trims a string by removing whitespace and quotes
pub fn trimString(str: []const u8) []const u8 {
    // Find null terminator if present
    const actual_len = std.mem.indexOfScalar(u8, str, 0) orelse str.len;
    // Trim spaces and quotes
    return std.mem.trim(u8, str[0..actual_len], " \t\n\r\"");
}

/// Validates and cleans up a path string
pub fn cleanPath(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    // Check if path points to default objects
    if (checkPredefinedObjects(trimString(path)).len > 0) {
        return checkPredefinedObjects(trimString(path));
    }

    // Convert backslashes to forward slashes
    var buffer: [256]u8 = undefined;
    _ = std.mem.replace(u8, path, "\\", "/", buffer[0..]);

    // Use the trimString function on the buffer
    const trimmed = trimString(buffer[0..path.len]);

    // Validate Path
    if (trimmed.len >= 256) {
        errors.errorCollector.reportError(errors.ErrorCode.PathTooLong);
        std.log.err("Path too long: {d}", .{trimmed.len});
        return "";
    }
    if (trimmed.len == 0) {
        errors.errorCollector.reportError(errors.ErrorCode.EmptyPath);
        std.log.err("Path is empty: {d}", .{trimmed.len});
        return "";
    }
    if (!std.fs.path.isAbsolute(trimmed)) {
        errors.errorCollector.reportError(errors.ErrorCode.InvalidPath);
        std.log.err("Path is not absolute: {s}", .{trimmed});
        return "";
    }

    // Duplicate and return
    const stable_slice = try allocator.dupe(u8, trimmed);
    return stable_slice;
}

/// Checks if the path points to a predefined object
fn checkPredefinedObjects(path: []const u8) []const u8 {
    if (std.mem.eql(u8, path, "cube")) {
        return "objects/cube.obj";
    } else if (std.mem.eql(u8, path, "cat")) {
        return "objects/cat/cat.obj";
    }
    return "";
}

/// Checks if a file exists
pub fn fileExists(path: []const u8) bool {
    const cleanedPath = trimString(path);
    std.fs.cwd().access(cleanedPath, .{}) catch {
        return false;
    };
    return true;
}
