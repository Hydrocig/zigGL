const std = @import("std");
const math = @import("std").math;
const zmath = @import("zmath");
const glfw = @import("mach-glfw");
const gl = @import("gl");
const objectLoader = @import("./graphics/objectLoader.zig");

// Window
var xAspect: f32 = 800.0;
var yAspect: f32 = 800.0;

// Mouse state
var isDragging: bool = false;
var lastMouseX: f32 = 0.0;
var lastMouseY: f32 = 0.0;
var rotationX: f32 = 0.0;
var rotationY: f32 = 0.0;

// Mouse Scroll
var scrollOffsetY: f64 = 0.0;

// Keys state
var offset: zmath.F32x4 = .{ 0.0, 0.0, 0.0, 0.0 };
const RelevantKeys = union(enum) {
    none,
    x,
    y,
    z,
    s,
};
var currentKey: RelevantKeys = .none;

// scaling
var translationMatrixScale: f32 = 1.0;

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

    // Create window
    const window: glfw.Window = glfw.Window.create(@intFromFloat(xAspect), @intFromFloat(yAspect), "Hello!", null, null, .{
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

    // Use proper allocator and ArrayList-based object loading
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var loadedObject = try objectLoader.load("objects/cube2.obj", allocator);
    defer loadedObject.deinit();

    // Use ArrayList items for triangle conversion
    const triangleIndices = try convertFacesToTriangles(loadedObject.ebo.items, loadedObject.vbo.items.len, allocator);
    defer allocator.free(triangleIndices);
    const triangleCount = triangleIndices.len;
    std.log.debug("FACES: {d}", .{triangleIndices});

    // Pass ArrayList-based object to createObject
    const objectVAO: u32 = createObject(&loadedObject, triangleIndices);

    // get shader from external file
    const vertexShaderSource: []const u8 = try std.fs.cwd().readFileAlloc(allocator, "src/graphics/shaders/vertex.shader.glsl", 1024 * 1024);
    defer allocator.free(vertexShaderSource);
    const fragmentShaderSource: []const u8 = try std.fs.cwd().readFileAlloc(allocator, "src/graphics/shaders/fragment.shader.glsl", 1024 * 1024);
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

    std.log.info("Vertex shader compiled!", .{});

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

    std.log.info("Fragment shader compiled!", .{});

    // Link shaders
    const shaderProgram: gl.uint = try linkProgram(vertexShader, fragmentShader);
    defer gl.DeleteProgram(shaderProgram);

    gl.UseProgram(shaderProgram);

    gl.Disable(gl.CULL_FACE);
    gl.Enable(gl.DEPTH_TEST);

    // Mouse events
    window.setMouseButtonCallback(mouseClickCallback);
    // Key events
    window.setKeyCallback(keyPressCallback);
    // Window events
    window.setFramebufferSizeCallback(windowSizeCallback);
    // Mouse scroll
    window.setScrollCallback(mouseScrollCallback);

    // Main Loop
    while (!window.shouldClose()) {
        gl.ClearColor(1.0, 1.0, 1.0, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        // Handle mouse movement
        if (isDragging) {
            var mouseX: f64 = 0.0;
            var mouseY: f64 = 0.0;

            var mousePosition = glfw.Window.getCursorPos(window);
            _ = &mousePosition;
            mouseX = @floatCast(mousePosition.xpos);
            mouseY = @floatCast(mousePosition.ypos);

            const deltaX = mouseX - lastMouseX;
            const deltaY = mouseY - lastMouseY;
            rotationX += @floatCast(deltaY * 0.01);
            rotationY += @floatCast(deltaX * 0.01);

            lastMouseX = @floatCast(mouseX);
            lastMouseY = @floatCast(mouseY);
        }

        // Handle keyboard input
        if (currentKey != .none) {
            var mouseX: f64 = 0.0;
            var mouseY: f64 = 0.0;

            var mousePosition = glfw.Window.getCursorPos(window);
            _ = &mousePosition;

            mouseX = mousePosition.xpos;
            mouseY = mousePosition.ypos;

            const deltaX: f64 = mouseX - lastMouseX;
            const deltaY: f64 = mouseY - lastMouseY;

            switch (currentKey) {
                .x => {
                    offset[0] = @floatCast(zmath.max(deltaX, deltaY) * 0.1);
                },
                .y => {
                    offset[1] = @floatCast(zmath.max(deltaX, deltaY) * 0.1);
                },
                .z => {
                    offset[2] = @floatCast(zmath.max(deltaX, deltaY) * 0.1);
                },
                .s => {
                    translationMatrixScale = @floatCast(zmath.max(zmath.max(deltaX, deltaY), scrollOffsetY) * 0.01);
                    if (translationMatrixScale < 0) {
                        translationMatrixScale = math.pow(f32, translationMatrixScale, 2);
                    }
                },
                else => {},
            }
        }

        // Translation scaling Matrix
        const translationMatrixScalingMatrix: [4]@Vector(4, f32) = zmath.Mat{
            zmath.F32x4{ translationMatrixScale, 0.0, 0.0, 0.0 },
            zmath.F32x4{ 0.0, translationMatrixScale, 0.0, 0.0 },
            zmath.F32x4{ 0.0, 0.0, translationMatrixScale, 0.0 },
            zmath.F32x4{ 0.0, 0.0, 0.0, 1.0 },
        };

        // Translation Matrix
        const translationMatrix: zmath.Mat = .{
            zmath.F32x4{ 1.0, 0.0, 0.0, 0.0 },
            zmath.F32x4{ 0.0, 1.0, 0.0, 0.0 },
            zmath.F32x4{ 0.0, 0.0, 1.0, 0.0 },
            zmath.F32x4{ offset[0], offset[1], offset[2], 1.0 },
        };

        // MVP Matrix
        const rotation_object_to_world_X = zmath.rotationX(rotationX);
        const rotation_object_to_world_Y = zmath.rotationY(rotationY);
        const world_to_view = zmath.lookAtRh(
            zmath.f32x4(0.0, 0.0, 3.0, 1.0), // eye position
            zmath.f32x4(0.0, 0.0, 0.0, 1.0), // focus point
            zmath.f32x4(0.0, 1.0, 0.0, 0.0), // up direction ('w' coord is zero because this is a vector not a point)
        );
        // `perspectiveFovRhGl` produces Z values in [-1.0, 1.0] range
        const view_to_clip = zmath.perspectiveFovRhGl(0.25 * math.pi, xAspect / yAspect, 0.1, 20.0);

        const rotation_object_to_world = zmath.mul(rotation_object_to_world_X, rotation_object_to_world_Y);
        const object_to_world = zmath.mul(zmath.mul(translationMatrix, translationMatrixScalingMatrix), rotation_object_to_world);
        const object_to_view = zmath.mul(object_to_world, world_to_view);
        const object_to_clip = zmath.mul(object_to_view, view_to_clip);

        // Transposition is needed because GLSL uses column-major matrices by default
        gl.UniformMatrix4fv(0, 1, gl.FALSE, &object_to_clip[0][0]);

        // Draw object
        gl.BindVertexArray(objectVAO);
        gl.DrawElements(gl.TRIANGLES, @intCast(triangleCount), gl.UNSIGNED_INT, 0);

        // MVP Matrix for axes
        const axes_to_world = zmath.Mat{
            zmath.F32x4{ 1.0, 0.0, 0.0, 0.0 },
            zmath.F32x4{ 0.0, 1.0, 0.0, 0.0 },
            zmath.F32x4{ 0.0, 0.0, 1.0, 0.0 },
            zmath.F32x4{ 0.0, 0.0, 0.0, 1.0 },
        };
        const axes_to_view = zmath.mul(axes_to_world, world_to_view);
        const axes_to_clip = zmath.mul(axes_to_view, view_to_clip);

        gl.UniformMatrix4fv(0, 1, gl.FALSE, &axes_to_clip[0][0]);

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

fn mouseClickCallback(window: glfw.Window, button: glfw.MouseButton, action: glfw.Action, mods: glfw.Mods) void {
    currentKey = .none;
    if (button == glfw.MouseButton.left and mods.shift == true) {
        if (action == glfw.Action.press) {
            isDragging = true;
            var mousePosition = glfw.Window.getCursorPos(window);
            _ = &mousePosition;
            lastMouseX = @floatCast(mousePosition.xpos);
            lastMouseY = @floatCast(mousePosition.ypos);
        } else if (action == glfw.Action.release) {
            isDragging = false;
        }
    }
}

fn keyPressCallback(window: glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) void {
    _ = &scancode;
    if (action == glfw.Action.press and (mods.shift == false and mods.control == false)) {
        var currentCursorPos = window.getCursorPos();
        _ = &currentCursorPos;

        lastMouseX = @floatCast(currentCursorPos.xpos);
        lastMouseY = @floatCast(currentCursorPos.ypos);

        switch (key) {
            glfw.Key.x => {
                currentKey = if (currentKey == .x) .none else .x;
            },
            glfw.Key.y => {
                currentKey = if (currentKey == .y) .none else .y;
            },
            glfw.Key.z => {
                currentKey = if (currentKey == .z) .none else .z;
            },
            glfw.Key.s => {
                currentKey = if (currentKey == .s) .none else .s;
            },
            else => {
                currentKey = .none;
            },
        }
    }
}

fn windowSizeCallback(window: glfw.Window, width: u32, height: u32) void {
    _ = &window;

    xAspect = @floatFromInt(width);
    yAspect = @floatFromInt(height);

    if (height == 0) return;

    gl.Viewport(0, 0, @intCast(width), @intCast(height));

    // aspect ratio calculation
    const aspect_ratio: f32 = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height));

    // Update projection matrix
    const view_to_clip = zmath.perspectiveFovRhGl(0.25 * math.pi, aspect_ratio, 0.1, 20.0);
    gl.UniformMatrix4fv(0, 1, gl.FALSE, &view_to_clip[0][0]);
}

fn mouseScrollCallback(window: glfw.Window, xoffset: f64, yoffset: f64) void {
    _ = &xoffset;
    _ = &window;

    scrollOffsetY += yoffset;

    if (currentKey == .none) {
        scrollOffsetY = 0.0;
    }
}

// Updated to use ArrayList items
pub fn createObject(object: *objectLoader.ObjectStruct, triangleIndices: []u32) u32 {
    var vao: u32 = 0;
    gl.GenVertexArrays(1, (&vao)[0..1]);
    gl.BindVertexArray(vao);

    // Create VBO using ArrayList items
    var vbo: u32 = 0;
    gl.GenBuffers(1, (&vbo)[0..1]);
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.BufferData(gl.ARRAY_BUFFER, @intCast(object.vbo.items.len * @sizeOf(objectLoader.Vertex)), object.vbo.items.ptr, gl.STATIC_DRAW);

    // Create EBO using converted indices
    var ebo: u32 = 0;
    gl.GenBuffers(1, (&ebo)[0..1]);
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(triangleIndices.len * @sizeOf(u32)), triangleIndices.ptr, gl.STATIC_DRAW);

    // Set vertex attribute pointers
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, @sizeOf(f32) * 3, 0);
    gl.EnableVertexAttribArray(0);

    return vao;
}

fn convertFacesToTriangles(faces: []const objectLoader.Face, vboLength: usize, allocator: std.mem.Allocator) ![]u32 {
    const triangleIndexCount = faces.len * 3;
    var triangleIndices = try allocator.alloc(u32, triangleIndexCount);
    var outIdx: usize = 0;

    for (faces) |face| {
        const indices = face.face;
        for (indices) |index| {
            if (index >= vboLength) return error.InvalidFaceIndex;
        }
        triangleIndices[outIdx] = @intCast(indices[0]);
        triangleIndices[outIdx + 1] = @intCast(indices[1]);
        triangleIndices[outIdx + 2] = @intCast(indices[2]);
        outIdx += 3;
    }
    return triangleIndices;
}
