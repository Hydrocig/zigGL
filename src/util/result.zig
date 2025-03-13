const std = @import("std");
const errors = @import("./errors.zig");

/// Generic result type that can contain either a value or an error
pub fn Result(comptime T: type) type {
    return struct {
        value: ?T = null,
        error_code: errors.ErrorCode = .None,

        /// Check if the result contains a valid value
        pub fn isValid(self: @This()) bool {
            return self.error_code == .None and self.value != null;
        }

        /// Get the error message if there's an error
        pub fn getErrorMessage(self: @This()) []const u8 {
            return self.error_code.getMessage();
        }

        /// Create a successful result with a value
        pub fn success(value: T) @This() {
            return .{ .value = value, .error_code = .None };
        }

        /// Create an error result
        pub fn failure(code: errors.ErrorCode) @This() {
            return .{ .error_code = code };
        }

        /// Safely unwrap the value, panics if there's an error
        pub fn unwrap(self: @This()) T {
            if (!self.isValid()) {
                std.debug.panic("Tried to unwrap an error result: {s}", .{self.getErrorMessage()});
            }
            return self.value.?;
        }
    };
}