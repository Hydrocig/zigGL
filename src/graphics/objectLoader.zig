//! Parse .obj files into the custom object struct
//!
//! Loads, parses, and processes .obj files

const fs = std.fs;
const io = std.io;
const mem = std.mem;

const std = @import("std");
const gl = @import("gl");
const zstbi = @import("zstbi");

const overlay = @import("../ui/overlay.zig");
const errors = @import("../util/errors.zig");
const result = @import("../util/result.zig");
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
/// - texCoordIndices: indices of the texture coordinates
/// - normalIndices: indices of the normals
pub const Face = struct {
    face: [3]usize,
    texCoordIndices: [3]usize,
    normalIndices: [3]usize,
};

/// Object struct
///
/// Contains:
/// - vbo: vertex buffer object
/// - ebo: element buffer object
/// - normals: normals of the object
/// - texCoords: texture coordinates of the object
/// - name: name of the object
/// - mtllib: name of the material file
/// - allocator: memory allocator
/// - materials: list of materials
/// - currentMaterialName: name of the current material
/// deinit method
pub const ObjectStruct = struct {
    vbo: std.ArrayList(Vertex), // v
    ebo: std.ArrayList(Face), // f
    normals: std.ArrayList([3]f32), // vn
    texCoords: std.ArrayList([2]f32), // vt
    name: std.ArrayList(u8), // o
    mtllib: []const u8, // mtllib
    allocator: std.mem.Allocator, // Memory allocator
    materials: std.ArrayList(Material), // List of materials
    faceMaterialIndices: std.ArrayList(usize), // Material index per face
    currentMaterialName: ?[]const u8, // Current material name

    /// Deinitialize the object (vbo, ebo, name)
    pub fn deinit(self: *ObjectStruct) void {
        self.vbo.deinit();
        self.ebo.deinit();
        self.normals.deinit();
        self.texCoords.deinit();
        self.name.deinit();
        self.materials.deinit();
        self.faceMaterialIndices.deinit();
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
    name: []const u8, // o
    ambient: [3]f32, // Ka
    diffuse: [3]f32, // Kd
    specular: [3]f32, // Ks
    texturePath: ?[]const u8, // map_Kd
    texture: ?zstbi.Image = undefined,
    textureId: gl.uint = undefined,

    pub fn deinit(self: *Material, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        if (self.texture_image) |*image| {
            image.deinit(); // Free CPU image data
        }
        if (self.texture_id != 0) {
            gl.DeleteTextures(1, &self.texture_id); // Free GPU texture
        }
    }
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
        .mtllib = "",
        .allocator = allocator,
        .materials = std.ArrayList(Material).init(allocator),
        .faceMaterialIndices = std.ArrayList(usize).init(allocator),
        .currentMaterialName = undefined,
    };

    try parseObjFile(objPath, &object);

    // Dont parse .mtl file if not present
    if (object.mtllib.len > 0) {
        try parseMtlFile(objPath, &object);
    }

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
    const mtlPath = try getMtlFilePath(object, path);

    if (!validator.fileExists(mtlPath)) {
        errors.errorCollector.reportError(errors.ErrorCode.MtlFileNotFound);
        return;
    }

    // Open the file
    const newMtlPath = validator.trimString(mtlPath);
    const file = try fs.cwd().openFile(newMtlPath, .{});
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
pub fn getMtlFilePath(object: *ObjectStruct, objPath: []const u8) ![]const u8 {
    // Get the directory of the obj file.
    objDir = std.fs.path.dirname(objPath) orelse ".";

    // Extract the filename from the objPath.
    const mtlFilename = object.mtllib;

    // Build the final path as: objDir + "/" + mtlFilename
    var parts = [_][]const u8{ objDir, "/", mtlFilename };
    const finalPath = try std.mem.concat(object.allocator, u8, &parts);

    return finalPath;
}

/// Process a single line from the .obj file
fn processObjLine(line: []const u8, obj: *ObjectStruct) !void {
    if (line.len == 0) return;

    // Parse line prefix
    const space_index = mem.indexOfScalar(u8, line, ' ') orelse line.len;
    const prefix = line[0..space_index];
    const content = if (space_index < line.len) line[space_index + 1 ..] else "";

    // Currently supported prefixes:
    if (mem.eql(u8, prefix, "usemtl")) { // Material for subsequent faces
        obj.currentMaterialName = content;
    } else if (mem.eql(u8, prefix, "o")) { // Object name
        try handleObjectName(content, obj);
    } else if (mem.eql(u8, prefix, "mtllib")) { // Mtl file name
        try handleMtlFileName(content, obj);
    } else if (mem.eql(u8, prefix, "v")) { // Vertex
        try handleVertex(content, obj);
    } else if (mem.eql(u8, prefix, "f")) { // Face
        try handleFace(content, obj);
    } else if (mem.eql(u8, prefix, "vt")) { // Texture coordinate
        try handleTextureCoordinate(content, obj);
    } else if (mem.eql(u8, prefix, "vn")) { // Normal
        try handleNormal(content, obj);
    }
}

/// Process a single line from the .mtl file
fn processMtlLine(line: []const u8, obj: *ObjectStruct) !void {
    if (line.len == 0) return;

    // Parse line prefix
    const space_index = mem.indexOfScalar(u8, line, ' ') orelse line.len;
    const prefix = line[0..space_index];
    const content = if (space_index < line.len) line[space_index + 1 ..] else "";

    // Currently supported prefixes:
    if (mem.eql(u8, prefix, "newmtl")) { // Name
        try handleName(content, obj);
    } else if (mem.eql(u8, prefix, "Ka")) { // Ambient
        try handleAmbient(content, obj);
    } else if (mem.eql(u8, prefix, "Kd")) { // Diffuse
        try handleDiffuse(content, obj);
    } else if (mem.eql(u8, prefix, "Ks")) { // Specular
        try handleSpecular(content, obj);
    } else if (mem.eql(u8, prefix, "map_Kd")) { // TexturePath
        try handleTexturePath(content, obj);
        endOfMtl = true;
    }
}

/// Handle the name of the material
fn handleName(content: []const u8, obj: *ObjectStruct) !void {
    // Create a new material with default values
    const material = Material{
        .name = try obj.allocator.dupe(u8, content),
        .ambient = [3]f32{ 0.2, 0.2, 0.2 }, // Default value
        .diffuse = [3]f32{ 0.8, 0.8, 0.8 }, // Default value
        .specular = [3]f32{ 0.0, 0.0, 0.0 }, // Default value
        .texturePath = null,
        .texture = null,
    };

    try obj.materials.append(material);
}

/// Handle the ambient color of the material
fn handleAmbient(content: []const u8, obj: *ObjectStruct) !void {
    // Ensure there's at least one material
    if (obj.materials.items.len == 0) return error.NoMaterialDefined;

    // Get the last material (current one being parsed)
    var material = &obj.materials.items[obj.materials.items.len - 1];
    const ambient = try get3CoordsFromString(content);

    material.ambient = ambient;
}

/// Handle the diffuse color of the material
fn handleDiffuse(content: []const u8, obj: *ObjectStruct) !void {
    if (obj.materials.items.len == 0) return error.NoMaterialDefined;
    var material = &obj.materials.items[obj.materials.items.len - 1];
    const diffuse = try get3CoordsFromString(content);

    material.diffuse = diffuse;
}

/// Handle the specular color of the material
fn handleSpecular(content: []const u8, obj: *ObjectStruct) !void {
    if (obj.materials.items.len == 0) return error.NoMaterialDefined;
    var material = &obj.materials.items[obj.materials.items.len - 1];
    const specular = try get3CoordsFromString(content);

    material.specular = specular;
}

/// Handle the texture path of the material
fn handleTexturePath(content: []const u8, obj: *ObjectStruct) !void {
    if (obj.materials.items.len == 0) return error.NoMaterialDefined;
    var material = &obj.materials.items[obj.materials.items.len - 1];

    // Build the final path (combine objDir and texture path)
    const texture_path = try std.fs.path.join(obj.allocator, &[_][]const u8{ objDir, content });
    defer obj.allocator.free(texture_path);

    // Convert to null-terminated string
    const texture_path_z = try obj.allocator.dupeZ(u8, texture_path);
    defer obj.allocator.free(texture_path_z);

    // Load the texture and store it in the material
    material.texture = try zstbi.Image.loadFromFile(texture_path_z, 4);

    // Generate the texture
    var textureId: gl.uint = 0;
    gl.GenTextures(1, (&textureId)[0..1]);
    gl.BindTexture(gl.TEXTURE_2D, textureId);

    // Set texture parameters
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    // Upload texture data to GPU
    var format: gl.@"enum" = undefined;
    if (material.texture.?.num_components == 3) {
        format = gl.RGB;
    } else if (material.texture.?.num_components == 4) {
        format = gl.RGBA;
    } else {
        format = gl.RGBA; // Fallback;
    }

    // Create the texture
    gl.TexImage2D(
        gl.TEXTURE_2D,
        0,
        @intCast(format),
        @intCast(material.texture.?.width),
        @intCast(material.texture.?.height),
        0,
        format,
        gl.UNSIGNED_BYTE,
        material.texture.?.data.ptr,
    );

    material.textureId = textureId; // Store the texture ID
}

/// Add the object name to the object struct
fn handleObjectName(content: []const u8, obj: *ObjectStruct) !void {
    obj.name.clearRetainingCapacity(); // Clear the name
    try obj.name.appendSlice(content); // Append the new name
}

/// Add the material file name to the object struct
fn handleMtlFileName(content: []const u8, obj: *ObjectStruct) !void {
    obj.mtllib = try obj.allocator.dupe(u8, content);
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
    var face = Face{
        .face = undefined, // Vertex indices
        .texCoordIndices = undefined, // Texture coordinate indices
        .normalIndices = undefined, // Normal indices
    };

    // Trim leading/trailing whitespace and line endings
    const trimmed_line = mem.trim(u8, content, &std.ascii.whitespace ++ "\r");
    var components = mem.split(u8, trimmed_line, " ");
    var i: usize = 0; // Explicit loop index

    while (components.next()) |component| : (i += 1) {
        if (i >= 3) break; // Only handle triangles for now

        var iter = mem.split(u8, component, "/");
        const vIdxStr = iter.next() orelse return error.InvalidFace;
        face.face[i] = (try std.fmt.parseInt(usize, vIdxStr, 10)) - 1; // 0-based

        // Parse texture coordinate index (vt)
        if (iter.next()) |vtIdxStr| {
            face.texCoordIndices[i] = (try std.fmt.parseInt(usize, vtIdxStr, 10)) - 1;
        }

        // Parse normal index (vn)
        if (iter.next()) |vnIdxStr| {
            face.normalIndices[i] = (try std.fmt.parseInt(usize, vnIdxStr, 10)) - 1;
        }
    }

    // Find material index for the current face
    const materialIndex = if (obj.currentMaterialName) |name| blk: {
        for (obj.materials.items, 0..) |mat, idx| {
            if (mem.eql(u8, mat.name, name)) break :blk idx;
        }
        break :blk 0; // Fallback to first material
    } else 0;

    try obj.ebo.append(face);
    try obj.faceMaterialIndices.append(materialIndex);
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
