//! Parse .obj files into the custom object struct
//!
//! Loads, parses, and processes .obj files

const std = @import("std");
const fs = std.fs;
const io = std.io;
const mem = std.mem;

/// Vertex struct
///
/// Contains:
/// - position: 3D position of the vertex
pub const Vertex = extern struct { position: [3]f32 };

/// Face struct
///
/// Contains:
/// - face: indices of the vertices
pub const Face = struct { face: [3]usize };

/// Object struct
///
/// Contains:
/// - vbo: vertex buffer object
/// - ebo: element buffer object
/// - name: name of the object
/// - allocator: memory allocator
/// deinit method
pub const ObjectStruct = struct {
    vbo: std.ArrayList(Vertex),
    ebo: std.ArrayList(Face),
    name: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    /// Deinitialize the object (vbo, ebo, name)
    pub fn deinit(self: *ObjectStruct) void {
        self.vbo.deinit();
        self.ebo.deinit();
        self.name.deinit();
    }
};

/// Load the .obj file
pub fn load(objPath: []const u8, allocator: std.mem.Allocator) !ObjectStruct {
    // Initialize the object struct
    var obj = ObjectStruct{
        .vbo = std.ArrayList(Vertex).init(allocator),
        .ebo = std.ArrayList(Face).init(allocator),
        .name = std.ArrayList(u8).init(allocator),
        .allocator = allocator,
    };

    try parseObjFile(objPath, &obj);
    return obj;
}

/// Parse the .obj file
fn parseObjFile(path: []const u8, obj: *ObjectStruct) !void {
    // Open the file
    const file = try fs.cwd().openFile(path, .{});
    defer file.close();

    // Read the file line by line
    var buf_reader = io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var line_buf: [1024]u8 = undefined;

    while (try in_stream.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        try processLine(line, obj);
    }
}

/// Process a single line from the .obj file
fn processLine(line: []const u8, obj: *ObjectStruct) !void {
    if (line.len == 0) return;

    const prefix = line[0..2]; // Find the prefix (type) of the line
    const content = if (line.len > 1) line[2..] else ""; // Get the content of the line

    // Currently supported prefixes:
    if (mem.eql(u8, prefix, "o ")) {            // Object name
        try handleObjectName(content, obj);
    } else if (mem.eql(u8, prefix, "v ")) {     // Vertex
        try handleVertex(content, obj);
    } else if (mem.eql(u8, prefix, "f ")) {     // Face
        try handleFace(content, obj);
    }
}

/// Add the object name to the object struct
fn handleObjectName(content: []const u8, obj: *ObjectStruct) !void {
    obj.name.clearRetainingCapacity(); // Clear the name
    try obj.name.appendSlice(content); // Append the new name
}

/// Add a vertex to the object struct
fn handleVertex(content: []const u8, obj: *ObjectStruct) !void {
    var components = mem.split(u8, content, " "); // Split the content into its components

    // Parse the components into the vertex struct components (x, y, z)
    const x_str = components.next() orelse return error.InvalidVertex;
    const y_str = components.next() orelse return error.InvalidVertex;
    const z_str = components.next() orelse return error.InvalidVertex;

    // Add the parsed components to the vertex struct
    const vertex = Vertex{ .position = .{
        try std.fmt.parseFloat(f32, x_str),
        try std.fmt.parseFloat(f32, y_str),
        try std.fmt.parseFloat(f32, z_str),
    } };

    try obj.vbo.append(vertex);
}

/// Add a face to the object struct
fn handleFace(content: []const u8, obj: *ObjectStruct) !void {
    var indices: [3]usize = undefined;
    var components = mem.split(u8, content, " ");

    // Parse the components into the face struct components (indices)
    for (&indices) |*index| {
        const component = components.next() orelse return error.InvalidFace;
        var iter = mem.split(u8, component, "/");

        const idx_str = iter.next() orelse return error.InvalidFace;
        index.* = (try std.fmt.parseInt(usize, idx_str, 10)) - 1; // 0-based

        // Skip texture and normal indices
    }

    try obj.ebo.append(Face{ .face = indices });
}
