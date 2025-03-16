//! Load cube mesh from .obj file
//!
//! Provides a function to load a mesh from a .obj file using the objectLoader.zig module
//! Function to convert faces to indices

const gl = @import("gl");
const objectLoader = @import("objectLoader.zig");
const std = @import("std");

const errors = @import("../util/errors.zig");

/// Mesh struct
///
/// Contains:
/// - vao: vertex array object
/// - vbo: vertex buffer object
/// - ebo: element buffer object
/// - index_count: number of indices
/// deinit method
pub const Mesh = struct {
    vao: gl.uint,
    vbo: gl.uint,
    ebo: gl.uint,
    index_count: usize,
    object: *objectLoader.ObjectStruct,

    pub fn init() !void {
        try load("objects/cube.obj"); // Load default cube
    }

    /// Deinitialize the mesh (vao, vbo, ebo)
    pub fn deinit(self: Mesh) void {
        var vaoArr: [1]gl.uint = .{self.vao};
        var vboArr: [1]gl.uint = .{self.vbo};
        var eboArr: [1]gl.uint = .{self.ebo};

        gl.DeleteVertexArrays(1, &vaoArr);
        gl.DeleteBuffers(1, &vboArr);
        gl.DeleteBuffers(1, &eboArr);
        self.object.deinit(); // Object struct
    }
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub var loadedObject: Mesh = undefined;

/// Load the mesh from the .obj file using the objectLoader
pub fn load(path: []const u8) !void {
    // Load object;
    const obj = try allocator.create(objectLoader.ObjectStruct);
    obj.* = try objectLoader.load(path, allocator);

    // Convert faces to indices
    const interleaved  = try convertFaces(obj, allocator);
    defer allocator.free(interleaved .indices);
    defer allocator.free(interleaved .vertices);

    // Create vertex array object
    var vao: gl.uint = undefined;
    gl.GenVertexArrays(1, (&vao)[0..1]); // Generate the buffer
    gl.BindVertexArray(vao); // Bind the buffer

    // Create vertex buffer object
    var vbo: gl.uint = undefined;
    gl.GenBuffers(1, (&vbo)[0..1]); // Generate the buffer
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo); // Bind the buffer
    gl.BufferData(gl.ARRAY_BUFFER, @intCast(interleaved.vertices.len * @sizeOf(f32)), interleaved.vertices.ptr, gl.STATIC_DRAW); // Fill the buffer with data

    // Create element buffer object
    var ebo: gl.uint = undefined;
    gl.GenBuffers(1, (&ebo)[0..1]); // Generate the buffer
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo); // Bind the buffer
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(interleaved.indices.len * @sizeOf(u32)), interleaved.indices.ptr, gl.STATIC_DRAW); // Fill the buffer with data

    // Position (location = 0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 0);                  // Position
    gl.EnableVertexAttribArray(0);

    // UVs (location = 1)
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 3 * @sizeOf(f32));   // UVs
    gl.EnableVertexAttribArray(1);

    // Normals (location = 2)
    gl.VertexAttribPointer(2, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 5 * @sizeOf(f32));   // Normals
    gl.EnableVertexAttribArray(2);

    // Set the currently loaded object
    loadedObject = Mesh{
        .vao = vao,
        .vbo = vbo,
        .ebo = ebo,
        .index_count = interleaved.indices.len,
        .object = obj,
    };
}

/// Deinitialize/unload the mesh
pub fn deinit() void {
    Mesh.deinit(loadedObject);
}

/// Convert faces to indices and generate interleaved vertex data
fn convertFaces(obj: *objectLoader.ObjectStruct, faceAllocator: std.mem.Allocator) !struct { vertices: []f32, indices: []u32 } {
    const face_count = obj.ebo.items.len;
    const vert_count = face_count * 3; // 3 vertices per face
    const vertices = try faceAllocator.alloc(f32, vert_count * 8); // 3 positions + 2 UVs + 3 normals = 8 floats per vertex
    const indices = try faceAllocator.alloc(u32, vert_count);

    // Check if the object has the necessary data
    if(obj.vbo.items.len == 0 or obj.ebo.items.len == 0 or obj.texCoords.items.len == 0 or obj.normals.items.len == 0) {
        errors.errorCollector.reportError(errors.ErrorCode.ObjFileMalformed);
        return .{ .vertices = vertices, .indices = indices };
    }

    // Iterate over faces and fill the vertices and indices arrays
    for (obj.ebo.items, 0..) |face, i| {
        for (0..3) |j| {
            const v_idx = face.face[j];
            const vt_idx = face.texCoordIndices[j];
            const vn_idx = face.normalIndices[j];

            // Positions
            vertices[i*24 + j*8 + 0] = obj.vbo.items[v_idx].position[0];
            vertices[i*24 + j*8 + 1] = obj.vbo.items[v_idx].position[1];
            vertices[i*24 + j*8 + 2] = obj.vbo.items[v_idx].position[2];

            // UVs
            vertices[i*24 + j*8 + 3] = obj.texCoords.items[vt_idx][0];
            vertices[i*24 + j*8 + 4] = obj.texCoords.items[vt_idx][1];

            // Normals
            vertices[i*24 + j*8 + 5] = obj.normals.items[vn_idx][0];
            vertices[i*24 + j*8 + 6] = obj.normals.items[vn_idx][1];
            vertices[i*24 + j*8 + 7] = obj.normals.items[vn_idx][2];

            indices[i*3 + j] = @intCast(i*3 + j);
        }
    }

    return .{ .vertices = vertices, .indices = indices };
}