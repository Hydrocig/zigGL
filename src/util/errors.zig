//! Error code catalog

pub const ErrorCode = error{
    InvalidPath, // Path is not absolute
    EmptyPath, // Path is empty
    PathTooLong, // Path is too long
};