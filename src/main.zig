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

// -- ImGui variables initialization --
var imguiVisible: bool = false; // Overlay visibility

var objTextBuffer: [128]u8 = undefined; // Buffor for obj Text input
var MtlTextBuffer: [128]u8 = undefined; // Buffor for mtl Text input

var manualEdit: bool = false; // Manual editing possible

// Position variables
var xPosGui: f32 = 1.0;
var yPosGui: f32 = 1.0;
var zPosGui: f32 = 1.0;

// Rotation variables
var xDegGui: f32 = 0.0;
var yDegGui: f32 = 0.0;
var zDegGui: f32 = 0.0;

// Scale variable
var scaleGui: f32 = 1.0;


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

    @memset(&objTextBuffer, 0);
    @memset(&MtlTextBuffer, 0);

    // Main loop
    while (!win.shouldClose()) {
        // Start new ImGui frame
        c.ImGuiImplOpenGL3_NewFrame();
        c.ImGuiImplGlfw_NewFrame();
        c.ImGuiNewFrame();

        if(state.overlayVisible){
            handleUi();
        }

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
    if(manualEdit){
        return;
    }

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

fn handleUi() void {
    // Top group with OBJ and MTL input
    c.ImGuiBeginGroup();
    c.Text("OBJ"); c.SameLine(0, 18);
    _ = c.InputTextWithHint("##obj", "Path to .obj file", &objTextBuffer, objTextBuffer.len, 0, null, null);
    c.Text("MTL"); c.SameLine(0, 18);
    _ = c.InputTextWithHint("##mtl", "Path to .mtl file", &MtlTextBuffer, MtlTextBuffer.len, 0, null, null);
    _ = c.Button("Load");
    c.Separator();
    c.ImGuiEndGroup();

    // Transformation group
    c.ImGuiBeginGroup();
    if(c.CollapsingHeaderStatic("Transformation", 0)) {
        _ = c.Checkbox("Enable ", &manualEdit);

        if(c.CollapsingHeader("Position", &manualEdit, 0)) {
            c.Text("x:"); c.SameLine(0, 10);
            _ = c.DragFloat("##xPos", &xPosGui, 0.01, -500.0, 500.0, "%.02f", 0);
            c.Text("y:"); c.SameLine(0, 10);
            _ = c.DragFloat("##yPos", &yPosGui, 0.01, -500.0, 500.0, "%.02f", 0);
            c.Text("z:"); c.SameLine(0, 10);
            _ = c.DragFloat("##zPos", &zPosGui, 0.01, -500.0, 500.0, "%.02f", 0);
        }
        if(c.CollapsingHeader("Rotation", &manualEdit, 0)) {
            c.Text("x:"); c.SameLine(0, 10);
            _ = c.DragFloat("##xDeg", &xDegGui, 0.01, -360.0, 360.0, "%.01f °", 0);
            c.Text("y:"); c.SameLine(0, 10);
            _ = c.DragFloat("##yDeg", &yDegGui, 0.01, -360.0, 360.0, "%.01f °", 0);
            c.Text("z:"); c.SameLine(0, 10);
            _ = c.DragFloat("##zDeg", &zDegGui, 0.01, -360.0, 360.0, "%.01f °", 0);
        }
        if(c.CollapsingHeader("Scale", &manualEdit, 0)) {
            c.Text("Scale: "); c.SameLine(0, 10);
            _ = c.DragFloat("##scale", &scaleGui, 0.01, 0.0, 500.0, "%.02f", 0);
        }
    }
    c.Separator();
    c.ImGuiEndGroup();

    // Reset button
    c.ImGuiBeginGroup();
    if (c.Button("Reset")) {
        // Position variables
        xPosGui= 1.0;
        yPosGui= 1.0;
        zPosGui= 1.0;

        // Rotation variables
        xDegGui = 0.0;
        yDegGui = 0.0;
        zDegGui = 0.0;

        // Scale variable
        scaleGui = 1.0;

        manualEdit = false;
    }
    c.NewLine();
    c.ImGuiEndGroup();
}