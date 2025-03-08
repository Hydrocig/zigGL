//! Load cube mesh from .obj file
//!
//! Provides a function to load a mesh from a .obj file using the objectLoader.zig module
//! Function to convert faces to indices

const gl = @import("gl");
const objectLoader = @import("objectLoader.zig");
const std = @import("std");

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

    /// Deinitialize the mesh (vao, vbo, ebo)
    pub fn deinit(self: Mesh) void {
        var vaoArr: [1]gl.uint = .{self.vao};
        var vboArr: [1]gl.uint = .{self.vbo};
        var eboArr: [1]gl.uint = .{self.ebo};

        gl.DeleteVertexArrays(1, &vaoArr);
            gl.DeleteBuffers(1, &vboArr);
            gl.DeleteBuffers(1, &eboArr);
        }
};

/// Load the mesh from the .obj file using the objectLoader
pub fn load(allocator: std.mem.Allocator, path: []const u8) !Mesh {
    // Load object
    var obj = try objectLoader.load(path, allocator);
    defer obj.deinit();

    // Convert faces to indices
    const indices = try convertFaces(obj.ebo.items, allocator);
    defer allocator.free(indices);

    // Create vertex array object
    var vao: gl.uint = undefined;
    gl.GenVertexArrays(1, (&vao)[0..1]); // Generate the buffer
    gl.BindVertexArray(vao); // Bind the buffer

    // Create vertex buffer object
    var vbo: gl.uint = undefined;
    gl.GenBuffers(1, (&vbo)[0..1]); // Generate the buffer
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo); // Bind the buffer
    gl.BufferData(gl.ARRAY_BUFFER, @intCast(obj.vbo.items.len * @sizeOf(objectLoader.Vertex)), obj.vbo.items.ptr, gl.STATIC_DRAW); // Fill the buffer with data

    // Create element buffer object
    var ebo: gl.uint = undefined;
    gl.GenBuffers(1, (&ebo)[0..1]); // Generate the buffer
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo); // Bind the buffer
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(indices.len * @sizeOf(u32)), indices.ptr, gl.STATIC_DRAW); // Fill the buffer with data

    // Set vertex attributes
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, @sizeOf(f32) * 3, 0);
    gl.EnableVertexAttribArray(0); // Enables the vertex attribute (inside the vertex shader)

    return Mesh{
        .vao = vao,
        .vbo = vbo,
        .ebo = ebo,
        .index_count = indices.len,
    };
}

/// Convert faces to indices
fn convertFaces(faces: []const objectLoader.Face, allocator: std.mem.Allocator) ![]u32 {
    const indices = try allocator.alloc(u32, faces.len * 3);
    for (faces, 0..) |face, i| {
        indices[i*3] = @intCast(face.face[0]);
        indices[i*3+1] = @intCast(face.face[1]);
        indices[i*3+2] = @intCast(face.face[2]);
    }
    return indices;
}