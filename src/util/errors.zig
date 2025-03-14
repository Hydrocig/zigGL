//! Error code catalog

pub const ErrorCollector = struct {
    lastError: ?ErrorCode = null,

    pub fn reportError(self: *ErrorCollector, code: ErrorCode) void {
        self.lastError = code;
    }

    pub fn getLastError(self: *const ErrorCollector) ?ErrorCode {
        return self.lastError;
    }

    pub fn getLastErrorMessage(self: *const ErrorCollector) ?[]const u8 {
        return if (self.lastError) |code|
            ErrorCode.getMessage(code)
        else
            null;
    }

    pub fn clearError(self: *ErrorCollector) void {
        self.lastError = null;
    }
};

pub var errorCollector: ErrorCollector = .{};

/// Error codes that are NOT zig errors but rather application-specific
pub const ErrorCode = enum {
    None,
    InvalidPath,
    EmptyPath,
    PathTooLong,
    MtlFileNotFound,

    pub fn getMessage(self: ErrorCode) []const u8 {
        return switch (self) {
            .None => "",
            .InvalidPath => "Path must be absolute",
            .EmptyPath => "Path cannot be empty",
            .PathTooLong => "Path is too long (max 255 characters)",
            .MtlFileNotFound => "Material file not found",
        };
    }
};

// Global instance
var lastError: ?ErrorCode = null;
