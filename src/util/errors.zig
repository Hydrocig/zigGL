//! Error code catalog

/// Error codes that are NOT zig errors but rather application-specific
pub const ErrorCode = enum {
    None,
    InvalidPath,
    EmptyPath,
    PathTooLong,

    pub fn getMessage(self: ErrorCode) []const u8 {
        return switch (self) {
            .None => "",
            .InvalidPath => "Path must be absolute",
            .EmptyPath => "Path cannot be empty",
            .PathTooLong => "Path is too long (max 255 characters)",
        };
    }
};
