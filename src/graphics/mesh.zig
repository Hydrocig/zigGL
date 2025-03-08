const gl = @import("gl");
const objectLoader = @import("objectLoader.zig");
const std = @import("std");

pub const Mesh = struct {
    vao: gl.uint,
    vbo: gl.uint,
    ebo: gl.uint,
    index_count: usize,

    pub fn deinit(self: Mesh) void {
        var vaoArr: [1]gl.uint = .{self.vao};
        var vboArr: [1]gl.uint = .{self.vbo};
        var eboArr: [1]gl.uint = .{self.ebo};

        gl.DeleteVertexArrays(1, &vaoArr);
            gl.DeleteBuffers(1, &vboArr);
            gl.DeleteBuffers(1, &eboArr);
        }
};

pub fn load(allocator: std.mem.Allocator, path: []const u8) !Mesh {
    var obj = try objectLoader.load(path, allocator);
    defer obj.deinit();

    const indices = try convertFaces(obj.ebo.items, allocator);
    defer allocator.free(indices);

    var vao: gl.uint = undefined;
    gl.GenVertexArrays(1, (&vao)[0..1]);
    gl.BindVertexArray(vao);

    var vbo: gl.uint = undefined;
    gl.GenBuffers(1, (&vbo)[0..1]);
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.BufferData(gl.ARRAY_BUFFER, @intCast(obj.vbo.items.len * @sizeOf(objectLoader.Vertex)), obj.vbo.items.ptr, gl.STATIC_DRAW);

    var ebo: gl.uint = undefined;
    gl.GenBuffers(1, (&ebo)[0..1]);
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(indices.len * @sizeOf(u32)), indices.ptr, gl.STATIC_DRAW);

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, @sizeOf(f32) * 3, 0);
    gl.EnableVertexAttribArray(0);

    return Mesh{
        .vao = vao,
        .vbo = vbo,
        .ebo = ebo,
        .index_count = indices.len,
    };
}

fn convertFaces(faces: []const objectLoader.Face, allocator: std.mem.Allocator) ![]u32 {
    const indices = try allocator.alloc(u32, faces.len * 3);
    for (faces, 0..) |face, i| {
        indices[i*3] = @intCast(face.face[0]);
        indices[i*3+1] = @intCast(face.face[1]);
        indices[i*3+2] = @intCast(face.face[2]);
    }
    return indices;
}