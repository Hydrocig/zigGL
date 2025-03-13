//! Parse .obj files into the custom object struct
//!
//! Loads, parses, and processes .obj files

const fs = std.fs;
const io = std.io;
const mem = std.mem;

const std = @import("std");
const zstbi = @import("zstbi");

const validator = @import("../util/validator.zig");

var endOfMtl: bool = false; // Flag to stop parsing .mtl file
var objDir: []const u8 = undefined; // Directory of the relevant files

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
/// - normals: normals of the object
/// - texCoords: texture coordinates of the object
/// - name: name of the object
/// - allocator: memory allocator
/// deinit method
pub const ObjectStruct = struct {
    vbo: std.ArrayList(Vertex),         // v
    ebo: std.ArrayList(Face),           // f
    normals: std.ArrayList([3]f32),     // vn
    texCoords: std.ArrayList([2]f32),   // vt
    name: std.ArrayList(u8),            // o
    allocator: std.mem.Allocator,
    material: Material,

    /// Deinitialize the object (vbo, ebo, name)
    pub fn deinit(self: *ObjectStruct) void {
        self.vbo.deinit();
        self.ebo.deinit();
        self.normals.deinit();
        self.texCoords.deinit();
        self.name.deinit();
    }
};

/// Material struct
///
/// Contains:
/// - name: name of the material
/// - ambient: ambient color
/// - diffuse: diffuse color
/// - specular: specular color
/// - texturePath: path to the texture
/// - texture: zstbi.Image struct
pub const Material = struct {
    name: []const u8,               // o
    ambient: [3]f32,                // Ka
    diffuse: [3]f32,                // Kd
    specular: [3]f32,               // Ks
    texturePath: ?[]const u8,       // map_Kd
    texture: ?zstbi.Image = undefined,
};

/// Load the .obj file
pub fn load(objPath: []const u8, allocator: std.mem.Allocator) !ObjectStruct {
    // Initialize the object struct
    var object = ObjectStruct{
        .vbo = std.ArrayList(Vertex).init(allocator),
        .ebo = std.ArrayList(Face).init(allocator),
        .normals = std.ArrayList([3]f32).init(allocator),
        .texCoords = std.ArrayList([2]f32).init(allocator),
        .name = std.ArrayList(u8).init(allocator),
        .allocator = allocator,
        .material = .{
            .name = undefined,
            .ambient = undefined,
            .diffuse = undefined,
            .specular = undefined,
            .texturePath = undefined,
        }
    };

    try parseObjFile(objPath, &object);
    try parseMtlFile(objPath, &object);
    return object;
}

/// Parse the .obj file
fn parseObjFile(path: []const u8, object: *ObjectStruct) !void {
    // Open the file
    const file = try fs.cwd().openFile(path, .{});
    defer file.close();

    // Read the file line by line
    var buf_reader = io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var line_buf: [1024]u8 = undefined;

    while (try in_stream.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        try processObjLine(line, object);
    }
}

/// Parse the .mtl file
fn parseMtlFile(path: []const u8, object: *ObjectStruct) !void {
    // Get mtl file path from obj file location
    const mtlPath = try getMtlFilePath(object.allocator, path);

    if (!validator.fileExists(mtlPath)){
        // TODO: return error
        return;
    }

    // Open the file
    const file = try fs.cwd().openFile(mtlPath, .{});
    defer file.close();

    // Read the file line by line
    var buf_reader = io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var line_buf: [1024]u8 = undefined;

    while (try in_stream.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        if (endOfMtl) return;
        try processMtlLine(line, object);
    }
}

/// Get the path to the .mtl file from the .obj file
pub fn getMtlFilePath(allocator: std.mem.Allocator, objPath: []const u8) ![]const u8 {
    // Get the directory of the obj file.
    objDir = std.fs.path.dirname(objPath) orelse ".";

    // Extract the filename from the objPath.
    // TODO: Use filename from .obj file
    var i: usize = objPath.len;
    var filename_start: usize = 0;
    while (i > 0) {
        i -= 1;
        if (objPath[i] == '/' or objPath[i] == '\\') {
            filename_start = i + 1;
            break;
        }
    }
    var filename = objPath[filename_start..];

    // Remove the ".obj" extension if present.
    if (std.mem.endsWith(u8, filename, ".obj")) {
        filename = filename[0..filename.len - 4];
    }

    // Build the final path as: objDir + "/" + filename + ".mtl"
    var parts = [_][]const u8{objDir, "/", filename, ".mtl"};
    const finalPath = try std.mem.concat(allocator, u8, &parts);

    return finalPath;
}

/// Process a single line from the .obj file
fn processObjLine(line: []const u8, obj: *ObjectStruct) !void {
    if (line.len == 0) return;

    // Parse line prefix
    const space_index = mem.indexOfScalar(u8, line, ' ') orelse line.len;
    const prefix = line[0..space_index];
    const content = if (space_index < line.len) line[space_index + 1..] else "";

    // Currently supported prefixes:
    if (mem.eql(u8, prefix, "o")) {             // Object name
        try handleObjectName(content, obj);
    } else if (mem.eql(u8, prefix, "v")) {      // Vertex
        try handleVertex(content, obj);
    } else if (mem.eql(u8, prefix, "f")) {      // Face
        try handleFace(content, obj);
    } else if (mem.eql(u8, prefix, "vt")) {     // Texture coordinate
        try handleTextureCoordinate(content, obj);
    } else if (mem.eql(u8, prefix, "vn")) {     // Normal
        try handleNormal(content, obj);
    }
}

/// Process a single line from the .mtl file
fn processMtlLine(line: []const u8, obj: *ObjectStruct) !void {
    if (line.len == 0) return;

    // Parse line prefix
    const space_index = mem.indexOfScalar(u8, line, ' ') orelse line.len;
    const prefix = line[0..space_index];
    const content = if (space_index < line.len) line[space_index + 1..] else "";

    // Currently supported prefixes:
    if (mem.eql(u8, prefix, "newmtl")) {        // Name
        try handleName(content, obj);
    }else if (mem.eql(u8, prefix, "Ka")) {      // Ambient
        try handleAmbient(content, obj);
    } else if (mem.eql(u8, prefix, "Kd")) {     // Diffuse
        try handleDiffuse(content, obj);
    } else if (mem.eql(u8, prefix, "Ks")) {     // Specular
        try handleSpecular(content, obj);
    } else if (mem.eql(u8, prefix, "map_Kd")) { // TexturePath
        try handleTexturePath(content, obj);
        endOfMtl = true;
    }
}

/// Handle the name of the material
fn handleName(content: []const u8, obj: *ObjectStruct) !void {
    obj.material.name = content;
}

/// Handle the ambient color of the material
fn handleAmbient(content: []const u8, obj: *ObjectStruct) !void {
    const ambient = try get3CoordsFromString(content);

    // Add the parsed components to the material struct
    obj.material.ambient[0] = ambient[0];
    obj.material.ambient[1] = ambient[1];
    obj.material.ambient[2] = ambient[2];
}

/// Handle the diffuse color of the material
fn handleDiffuse(content: []const u8, obj: *ObjectStruct) !void {
    const diffuse = try get3CoordsFromString(content);

    // Add the parsed components to the material struct
    obj.material.diffuse[0] = diffuse[0];
    obj.material.diffuse[1] = diffuse[1];
    obj.material.diffuse[2] = diffuse[2];
}

/// Handle the specular color of the material
fn handleSpecular(content: []const u8, obj: *ObjectStruct) !void {
    const specular = try get3CoordsFromString(content);

    // Add the parsed components to the material struct
    obj.material.specular[0] = specular[0];
    obj.material.specular[1] = specular[1];
    obj.material.specular[2] = specular[2];
}

/// Handle the texture path of the material
fn handleTexturePath(content: []const u8, obj: *ObjectStruct) !void {
    obj.material.texturePath = content;

    // Build the final path
    var parts = [_][]const u8{objDir, "/", content};
    const filePath = try std.mem.concat(obj.allocator, u8, &parts);

    // Convert to null-terminated string
    const texture_path_z = try obj.allocator.dupeZ(u8, filePath);

    // Load the texture from the file with given path and 4 channels (RGBA)
    obj.material.texture = try zstbi.Image.loadFromFile(texture_path_z, 4);
}

/// Add the object name to the object struct
fn handleObjectName(content: []const u8, obj: *ObjectStruct) !void {
    obj.name.clearRetainingCapacity(); // Clear the name
    try obj.name.appendSlice(content); // Append the new name
}

/// Add a vertex to the object struct
fn handleVertex(content: []const u8, obj: *ObjectStruct) !void {
    const vertices = try get3CoordsFromString(content);

    const vertex = Vertex{ .position = .{
        vertices[0],
        vertices[1],
        vertices[2],
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

/// Handle the texture coordinate of the face
fn handleTextureCoordinate(content: []const u8, obj: *ObjectStruct) !void {
    const texCoords = try get2CoordsFromString(content);

    try obj.texCoords.append(texCoords);
}

/// Handle the normal of the face
fn handleNormal(content: []const u8, obj: *ObjectStruct) !void {
    const normals = try get3CoordsFromString(content);

    try obj.normals.append(normals);
}

/// Get 3 coordinates from a string
fn get3CoordsFromString(content: []const u8) ![3]f32 {
    var components = mem.tokenize(u8, content, " \t\r"); // Tokenize to skip multiple delimiters

    // Parse the components into the vertex struct components
    const x_str = components.next() orelse return error.InvalidVertex;
    const y_str = components.next() orelse return error.InvalidVertex;
    const z_str = components.next() orelse return error.InvalidVertex;

    // Trim any potential whitespace from the strings before parsing
    const x_trimmed = mem.trim(u8, x_str, &std.ascii.whitespace);
    const y_trimmed = mem.trim(u8, y_str, &std.ascii.whitespace);
    const z_trimmed = mem.trim(u8, z_str, &std.ascii.whitespace);

    return .{
        try std.fmt.parseFloat(f32, x_trimmed),
        try std.fmt.parseFloat(f32, y_trimmed),
        try std.fmt.parseFloat(f32, z_trimmed),
    };
}

/// Get the 2 coordinates from a string
fn get2CoordsFromString(content: []const u8) ![2]f32 {
    var components = mem.tokenize(u8, content, " \t\r"); // Tokenize to skip multiple delimiters

    // Parse the components into the vertex struct components
    const x_str = components.next() orelse return error.InvalidVertex;
    const y_str = components.next() orelse return error.InvalidVertex;

    // Trim any potential whitespace from the strings before parsing
    const x_trimmed = mem.trim(u8, x_str, &std.ascii.whitespace);
    const y_trimmed = mem.trim(u8, y_str, &std.ascii.whitespace);

    return .{
        try std.fmt.parseFloat(f32, x_trimmed),
        try std.fmt.parseFloat(f32, y_trimmed),
    };
}
