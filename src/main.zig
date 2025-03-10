//! Main entry point for the application
//!
//! Initializes glfw, creates a window, loads a cube mesh, compiles shaders, and enters the main loop

const std = @import("std");
const gl = @import("gl");
const zmath = @import("zmath");
const math = @import("std").math;
const glfw = @import("mach-glfw");

const window = @import("./window/window.zig");
const shader = @import("./graphics/shader.zig");
const mesh = @import("./graphics/mesh.zig");

const c = @cImport({
    @cInclude("cimgui.h");
});


pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // GLFW initialization
    if (!glfw.init(.{})) {
        std.log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        return error.GLInitFailed;
    }
    defer glfw.terminate();

    // Window creation
    const win = try window.init("zigGL");
    defer win.destroy();

    // Initialize Imgui
    c.InitImgui(win.handle);

    // Set up window callbacks
    var state = window.WindowState{};
    window.setupCallbacks(win, &state);

    // Load mesh
    const cube = try mesh.load(allocator, "objects/cube2.obj");
    defer cube.deinit();

    // Compile shaders
    const program = try shader.compile(allocator,
        "src/graphics/shaders/vertex.shader.glsl",
        "src/graphics/shaders/fragment.shader.glsl");
    defer gl.DeleteProgram(program);

    gl.Enable(gl.DEPTH_TEST); // Enable depth testing
    gl.UseProgram(program); // Use the shader program

    var rotation = zmath.matFromRollPitchYaw(0, 0, 0);  // Rotation matrix
    var translation = zmath.identity();                                 // Translation matrix
    var scale = zmath.identity();                                       // Scale matrix

    var slider_value: f32 = 0.5;

    // Main loop
    while (!win.shouldClose()) {
        // Start new ImGui frame
        c.ImGuiImplOpenGL3_NewFrame();
        c.ImGuiImplGlfw_NewFrame();
        c.ImGuiNewFrame();

        // Simple UI
        if (c.Button("Test Button")) {
            std.debug.print("Button clicked!\n", .{});
        }

        _ = c.SliderFloat("Test Slider", &slider_value, 0.0, 1.0);

        gl.ClearColor(1.0, 1.0, 1.0, 1.0); // Clear the screen to white
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        // Update transformations based on input state
        updateTransforms(&rotation, &translation, &scale, &state);

        // -- Calculate MVP matrix --
        // MVP = Model * View * Projection
        //
        // Model: scale * rotation * translation
        // View: contains the camera position and orientation
        // Projection: perspective projection matrix
        const view = zmath.lookAtRh(
            zmath.f32x4(0, 0, 3, 1),
            zmath.f32x4(0, 0, 0, 1),
            zmath.f32x4(0, 1, 0, 0));
        const proj = zmath.perspectiveFovRhGl(
            0.25 * math.pi,
            state.width / state.height,
            0.1, 100);
        const mvp = zmath.mul(zmath.mul(scale, rotation), zmath.mul(translation, zmath.mul(view, proj)));

        gl.UniformMatrix4fv(0, 1, gl.FALSE, &mvp[0][0]);
        gl.BindVertexArray(cube.vao);
        gl.DrawElements(gl.TRIANGLES, @intCast(cube.index_count), gl.UNSIGNED_INT, 0);

        // Render ImGui
        c.ImGuiRender();
        c.ImGuiImplOpenGL3_RenderDrawData();

        win.swapBuffers();
        glfw.pollEvents();
    }
}

/// Update the rotation, translation, and scale matrices
/// Values come from the window state (mouse and keyboard input from callbacks)
fn updateTransforms(rotation: *zmath.Mat, translation: *zmath.Mat, scale: *zmath.Mat, state: *window.WindowState) void {
    // Handle rotation
    if (state.mouse.dragging) {
        // If the mouse was just pressed, store the initial position (prevents sudden jumps)
        if (state.mouse.justPressed) {
            state.mouse.last_x = state.mouse.x;
            state.mouse.last_y = state.mouse.y;
            state.mouse.justPressed = false;
            return;
        }

        // Delta between current and last mouse position
        const deltaX = state.mouse.x - state.mouse.last_x;
        const deltaY = state.mouse.y - state.mouse.last_y;

        // New rotation angles
        const rotX = @as(f32, @floatCast(deltaY * 0.01));
        const rotY = @as(f32, @floatCast(deltaX * 0.01));

        // Calculate new rotation matrix
        const currentRotation = rotation.*;
        const newRotX = zmath.mul(currentRotation, zmath.rotationX(rotX));
        const newRotY = zmath.mul(zmath.rotationY(rotY), newRotX);
        rotation.* = newRotY;

        state.mouse.last_x = state.mouse.x;
        state.mouse.last_y = state.mouse.y;
    }

    // Handle translation and scaling
    switch (state.keys) {
        // Move along X, Y, or Z axis
        .x, .y, .z => {
            // When object was not translated yet, store the initial position
            if (state.mouse.last_x == 0 or state.mouse.last_y == 0) {
                state.mouse.last_x = state.mouse.x;
                state.mouse.last_y = state.mouse.y;
            }

            const deltaX = state.mouse.x - state.mouse.last_x;
            const deltaY = state.mouse.y - state.mouse.last_y;
            const delta = (deltaX + deltaY) * 0.006;

            // Get the axis to move along from pressed key
            const axis: usize = switch (state.keys) {
                .x => 0,
                .y => 1,
                .z => 2,
                else => unreachable,
            };

            // Apply new translation matrix
            var newTranslation = translation.*;
            newTranslation[3][axis] += @as(f32, @floatCast(delta));
            translation.* = newTranslation;

            state.mouse.last_x = state.mouse.x;
            state.mouse.last_y = state.mouse.y;
        },
        // Scaling
        .s => {
            // When object was not translated yet, store the initial position
            if (state.mouse.last_x == 0 or state.mouse.last_y == 0) {
                state.mouse.last_x = state.mouse.x;
                state.mouse.last_y = state.mouse.y;
            }

            const deltaX = state.mouse.x - state.mouse.last_x;
            const deltaY = state.mouse.y - state.mouse.last_y;
            const mouseDelta = deltaX + deltaY;
            const scrollDelta = state.scroll;

            // Calculate total delta from mouse and scroll wheel
            var totalDelta = @as(f32, @floatCast((mouseDelta + scrollDelta) * 0.006));

            // If the total delta is negative, scale the object faster (Workaround)
            if (totalDelta < 0) {
                totalDelta = totalDelta * 1.5;
            }

            // Apply new scale matrix
            const scaleFactor = 1.0 + totalDelta;
            const scaleMatrix = zmath.scaling(scaleFactor, scaleFactor, scaleFactor);
            scale.* = zmath.mul(scale.*, scaleMatrix);

            state.scroll = 0;
            state.mouse.last_x = state.mouse.x;
            state.mouse.last_y = state.mouse.y;

        },
        // No relevant input
        .none => {},
    }
}