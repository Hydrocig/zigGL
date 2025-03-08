//! Shader compilation utilities.
//!
//! Provides functions to compile vertex and fragment shaders and link them

const gl = @import("gl");
const std = @import("std");

/// Compiles a vertex and fragment shader and links them into a program
/// Reads the shader source from a file
pub fn compile(allocator: std.mem.Allocator, vertex_path: []const u8, fragment_path: []const u8) !gl.uint {
    // Read shader sources from files
    const vs_src = try std.fs.cwd().readFileAlloc(allocator, vertex_path, 1 << 20);
    defer allocator.free(vs_src);
    const fs_src = try std.fs.cwd().readFileAlloc(allocator, fragment_path, 1 << 20);
    defer allocator.free(fs_src);

    // Compile and link shaders
    const vs = try compileShader(vs_src, gl.VERTEX_SHADER);
    const fs = try compileShader(fs_src, gl.FRAGMENT_SHADER);
    return try linkProgram(vs, fs);
}

/// Compiles a given shader source as a given shader type
fn compileShader(source: []const u8, shader_type: gl.@"enum") !gl.uint {
    // Create shader in OpenGL
    const shader = gl.CreateShader(shader_type);
    gl.ShaderSource(shader, 1, (&source.ptr)[0..1], (&@as(c_int, @intCast(source.len)))[0..1]);
    gl.CompileShader(shader);

    // Error handling
    var success: gl.int = 0;
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success);
    if (success == gl.FALSE) {
        var log: [512]u8 = undefined;
        gl.GetShaderInfoLog(shader, 512, null, &log);
        std.log.err("Shader compile error: {s}", .{log});
        return error.ShaderCompileFailed;
    }
    return shader;
}

/// Links a vertex and fragment shader into a program
fn linkProgram(vs: gl.uint, fs: gl.uint) !gl.uint {
    // Create program in OpenGL and attach shaders
    const program = gl.CreateProgram();
    gl.AttachShader(program, vs);
    gl.AttachShader(program, fs);
    gl.LinkProgram(program);

    // Error handling
    var success: gl.int = 0;
    gl.GetProgramiv(program, gl.LINK_STATUS, &success);
    if (success == gl.FALSE) {
        var log: [512]u8 = undefined;
        gl.GetProgramInfoLog(program, 512, null, &log);
        std.log.err("Program link error: {s}", .{log});
        return error.ProgramLinkFailed;
    }
    return program;
}