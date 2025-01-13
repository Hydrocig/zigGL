const std = @import("std");
const glfw = @import("mach-glfw");
const gl = @import("gl");

var gl_procs: gl.ProcTable = undefined;

/// Default GLFW error handling callback
fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("glfw: {}: {s}\n", .{ error_code, description });
}

pub fn main() !void {
    glfw.setErrorCallback(errorCallback);
    if (!glfw.init(.{})) {
        std.log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    }
    defer glfw.terminate();

    // Create our window
    const window = glfw.Window.create(640, 480, "Hello!", null, null, .{
        .context_version_major = 4,
        .context_version_minor = 5,
        .opengl_profile = .opengl_core_profile,
        .opengl_forward_compat = true,
    }) orelse {
        std.log.err("failed to create GLFW window: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    };
    defer window.destroy();

    glfw.makeContextCurrent(window);
    defer glfw.makeContextCurrent(null);

    glfw.swapInterval(1); // Vsync

    if (!gl_procs.init(glfw.getProcAddress)) {
        std.log.err("failed to initialize ProcTable: {?s}", .{glfw.getErrorString()});
        return error.GLInitFailed;
    }

    // Make the OpenGL procedure table current.
    gl.makeProcTableCurrent(&gl_procs);
    defer gl.makeProcTableCurrent(null);

    //1.1 Vertex and fragment shaders [x]
    //1.2 VAO and VBO [x]
    //1.3 gl.DrawArrays [x]
    //
    //2.1 Shader Encapsulation (utility to compile, link, and validate shaders) []
    //2.2 Mesh Abstraction (utility to create VAOs and VBOs) []
    //
    //3.1 Indexed Rendering support (gl.DrawElements) []
    //
    //4.1 .obj parser -> Ignore textures and normals for now []
    //4.2 store vertices in a struct []
    //
    //5.1 parsed data buffer -> VAO, VBO, IBO -> upload to GPU []
    //5.2 Vertex attributes -> attribute pointers (position, normal, texcoord) []
    //
    //6.1 Multiple objects -> multiple VAOs, VBOs, IBOs []
    //6.2 Render each object separately []
    //
    //7.1 Parse texture coordinates []
    //7.2 Load textures + bind textures to texture units []
    //
    //8.1 Extract and buffer normal vectors []
    //8.2 Basic lighting []
    //
    //9.1 Parse .mtl files and load material properties []
    //9.2 Normal mapping/PBR -> advanced shading techniques []

    // Vertex struct
    const Vertex = extern struct { position: [3]f32, color: [3]f32 };

    // example triangle vertices
    const triangleVertices = [_]Vertex{
        .{ .position = [_]f32{ -0.5, -0.5, 0.0 }, .color = .{ 0, 0, 1 } }, // left
        .{ .position = [_]f32{ 0.5, -0.5, 0.0 }, .color = .{ 1, 1, 1 } }, // right
        .{ .position = [_]f32{ 0.0, 0.5, 0.0 }, .color = .{ 1, 0, 1 } }, // top
    };

    // get shader from external file
    const allocator = std.heap.page_allocator;
    const vertexShaderSource: []const u8 = try std.fs.cwd().readFileAlloc(allocator, "src/vertex.shader.glsl", 1024 * 1024);
    defer allocator.free(vertexShaderSource);
    const fragmentShaderSource: []const u8 = try std.fs.cwd().readFileAlloc(allocator, "src/fragment.shader.glsl", 1024 * 1024);
    defer allocator.free(fragmentShaderSource);

    // Compile vertex shader
    const vertexShader: c_uint = gl.CreateShader(gl.VERTEX_SHADER);
    defer gl.DeleteShader(vertexShader);
    if (vertexShader == 0) return error.ShaderCreationFailed;

    gl.ShaderSource(vertexShader, 1, (&vertexShaderSource.ptr)[0..1], (&@as(c_int, @intCast(vertexShaderSource.len)))[0..1]);
    gl.CompileShader(vertexShader);

    var success: gl.int = 0;
    gl.GetShaderiv(vertexShader, gl.COMPILE_STATUS, &success);
    if (success == gl.FALSE) {
        var log: [512]u8 = undefined;
        gl.GetShaderInfoLog(vertexShader, 512, null, &log);
        std.log.err("Vertex shader compilation failed: {s}", .{log});
        return error.ShaderCompilationFailed;
    }

    std.log.debug("Vertex shader compiled!", .{});

    // Compile fragment shader
    const fragmentShader: c_uint = gl.CreateShader(gl.FRAGMENT_SHADER);
    defer gl.DeleteShader(fragmentShader);
    if (fragmentShader == 0) return error.ShaderCreationFailed;

    gl.ShaderSource(fragmentShader, 1, (&fragmentShaderSource.ptr)[0..1], (&@as(c_int, @intCast(fragmentShaderSource.len)))[0..1]);
    gl.CompileShader(fragmentShader);

    gl.GetShaderiv(fragmentShader, gl.COMPILE_STATUS, &success);
    if (success == gl.FALSE) {
        var log: [512]u8 = undefined;
        gl.GetShaderInfoLog(fragmentShader, 512, null, &log);
        std.log.err("Fragment shader compilation failed: {s}", .{log});
        return error.ShaderCompilationFailed;
    }

    std.log.debug("Fragment shader compiled!", .{});

    // Link shaders
    const shaderProgram: gl.uint = try linkProgram(vertexShader, fragmentShader);
    defer gl.DeleteProgram(shaderProgram);

    gl.UseProgram(shaderProgram);

    // VAO
    var vao: c_uint = undefined;
    gl.GenVertexArrays(1, (&vao)[0..1]);
    defer gl.DeleteVertexArrays(1, (&vao)[0..1]);
    gl.BindVertexArray(vao);
    defer gl.BindVertexArray(0);

    // VBO
    var vbo: c_uint = undefined;
    gl.GenBuffers(1, (&vbo)[0..1]);
    defer gl.DeleteBuffers(1, (&vbo)[0..1]);
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
    defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);

    // VBO upload
    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(triangleVertices)), &triangleVertices, gl.STATIC_DRAW);

    // Vertex attributes
    const stride = @sizeOf(Vertex);

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, stride, 0);
    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, stride, @sizeOf([3]f32));
    gl.EnableVertexAttribArray(1);

    // Main Loop
    while (!window.shouldClose()) {
        gl.ClearColor(1.0, 0.0, 0.0, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        gl.UseProgram(shaderProgram);
        gl.BindVertexArray(vao);
        gl.DrawArrays(gl.TRIANGLES, 0, triangleVertices.len);

        window.swapBuffers();
        glfw.pollEvents();
    }
}

fn linkProgram(vertexShader: gl.uint, fragmentShader: gl.uint) !c_uint {
    const program: c_uint = gl.CreateProgram();
    if (program == 0) return error.ProgramCreationFailed;

    // vertex shader
    gl.AttachShader(program, vertexShader);
    var error_code = gl.GetError();
    if (error_code != gl.NO_ERROR) {
        std.log.err("Vertex shader attachment error: 0x{X}", .{error_code});
    }

    // fragment shader
    gl.AttachShader(program, fragmentShader);
    error_code = gl.GetError();
    if (error_code != gl.NO_ERROR) {
        std.log.err("Fragment shader attachment error: 0x{X}", .{error_code});
    }

    gl.LinkProgram(program);
    error_code = gl.GetError();
    if (error_code != gl.NO_ERROR) {
        std.log.err("Link Program error: 0x{X}", .{error_code});
    }

    var success: gl.int = 0;
    gl.GetProgramiv(program, gl.LINK_STATUS, &success);
    if (success == gl.FALSE) {
        const log = try std.heap.page_allocator.alloc(u8, 512);
        std.log.err("Program linking failed: {s}", .{log});

        // Clean up
        gl.DeleteProgram(program);
        return error.ProgramLinkingFailed;
    }

    std.log.info("Shaders linked successfully", .{});
    return program;
}
