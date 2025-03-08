const gl = @import("gl");
const std = @import("std");

pub fn compile(allocator: std.mem.Allocator, vertex_path: []const u8, fragment_path: []const u8) !gl.uint {
    const vs_src = try std.fs.cwd().readFileAlloc(allocator, vertex_path, 1 << 20);
    defer allocator.free(vs_src);
    const fs_src = try std.fs.cwd().readFileAlloc(allocator, fragment_path, 1 << 20);
    defer allocator.free(fs_src);

    const vs = try compileShader(vs_src, gl.VERTEX_SHADER);
    const fs = try compileShader(fs_src, gl.FRAGMENT_SHADER);
    return try linkProgram(vs, fs);
}

fn compileShader(source: []const u8, shader_type: gl.@"enum") !gl.uint {
    const shader = gl.CreateShader(shader_type);
    gl.ShaderSource(shader, 1, (&source.ptr)[0..1], (&@as(c_int, @intCast(source.len)))[0..1]);
    gl.CompileShader(shader);

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

fn linkProgram(vs: gl.uint, fs: gl.uint) !gl.uint {
    const program = gl.CreateProgram();
    gl.AttachShader(program, vs);
    gl.AttachShader(program, fs);
    gl.LinkProgram(program);

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