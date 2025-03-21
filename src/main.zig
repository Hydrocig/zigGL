//! Main entry point for the application
//!
//! Initializes glfw, creates a window, loads a cube mesh, compiles shaders, and enters the main loop

const std = @import("std");
const gl = @import("gl");
const zmath = @import("zmath");
const math = @import("std").math;
const zstbi = @import("zstbi");
const glfw = @import("mach-glfw");

const window = @import("./window/window.zig");
const shader = @import("./graphics/shader.zig");
const mesh = @import("./graphics/mesh.zig");
const overlay = @import("./ui/overlay.zig");

const c = @cImport({
    @cInclude("cimgui.h");
});

/// Main method
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Zstbi initialization
    zstbi.init(allocator);
    zstbi.setFlipVerticallyOnLoad(true);
    //defer zstbi.deinit();

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

    // Load default mesh (cube)
    try mesh.Mesh.init();

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

    // Main loop
    while (!win.shouldClose()) {
        overlay.beginFrame(); // Start new ImGui frame
        try overlay.draw(&state); // Draw frame

        gl.ClearColor(1.0, 1.0, 1.0, 1.0); // Clear the screen to white
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        // Handle material visibility
        handleMaterialVisibility(program, &state);

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

        // Calculate separate model matrix for lighting calculations
        const model = zmath.mul(zmath.mul(scale, rotation), translation);
        const mvp = zmath.mul(model, zmath.mul(view, proj));

        // Set matrices
        gl.UniformMatrix4fv(gl.GetUniformLocation(program, "MVP"), 1, gl.FALSE, &mvp[0][0]);
        gl.UniformMatrix4fv(gl.GetUniformLocation(program, "Model"), 1, gl.FALSE, &model[0][0]);

        // Set lighting uniforms
        const lightPos = zmath.f32x4(2.0, 2.0, 2.0, 1.0);
        gl.Uniform3f(gl.GetUniformLocation(program, "lightPos"),
            lightPos[0], lightPos[1], lightPos[2]);

        const viewPos = zmath.f32x4(0.0, 0.0, 3.0, 1.0);
        gl.Uniform3f(gl.GetUniformLocation(program, "viewPos"),
            viewPos[0], viewPos[1], viewPos[2]);

        gl.BindVertexArray(mesh.loadedObject.vao);
        gl.DrawElements(gl.TRIANGLES, @intCast(mesh.loadedObject.index_count), gl.UNSIGNED_INT, 0);

        overlay.endFrame(); // Render ImGui

        win.swapBuffers();
        glfw.pollEvents();
    }
}

fn handleMaterialVisibility(program: c_uint, state: *window.WindowState) void {
    const useTexture = mesh.loadedObject.object.materials.items.len > 0;
    gl.Uniform1i(gl.GetUniformLocation(program, "useTexture"), @intFromBool(useTexture));

    // Bind the shader program with texture
    if (useTexture) {
        const material = mesh.loadedObject.object.materials.items[0];
        // Diffuse texture
        if (material.textureId != 0 and state.overlayState.diffuseVisible) {
            gl.ActiveTexture(gl.TEXTURE0);
            gl.BindTexture(gl.TEXTURE_2D, material.textureId);
            gl.Uniform1i(gl.GetUniformLocation(program, "textureDiffuse"), 0);
            gl.Uniform1i(gl.GetUniformLocation(program, "useTexture"), 1);
        } else {
            // Default when diffuse texture is disabled or not available
            gl.ActiveTexture(gl.TEXTURE0);
            gl.BindTexture(gl.TEXTURE_2D, 0);
            gl.Uniform1i(gl.GetUniformLocation(program, "useTexture"), 0);
            gl.Uniform4f(gl.GetUniformLocation(program, "defaultColor"), 0.4, 0.4, 0.4, 1.0);
        }

        // Normal texture
        if (material.normalMapId != 0 and state.overlayState.normalVisible) {
            gl.ActiveTexture(gl.TEXTURE1);
            gl.BindTexture(gl.TEXTURE_2D, material.normalMapId);
            gl.Uniform1i(gl.GetUniformLocation(program, "textureNormal"), 1);
            gl.Uniform1i(gl.GetUniformLocation(program, "useNormalMap"), 1);
        } else {
            gl.ActiveTexture(gl.TEXTURE1);
            gl.BindTexture(gl.TEXTURE_2D, 0);
            gl.Uniform1i(gl.GetUniformLocation(program, "useNormalMap"), 0);
        }

        // Roughness texture
        gl.Uniform3f(gl.GetUniformLocation(program, "materialSpecular"),
            material.specular[0], material.specular[1], material.specular[2]);
        gl.Uniform1f(gl.GetUniformLocation(program, "roughness"), 0.5); // Default roughness
        if (material.roughnessMapId != 0 and state.overlayState.roughnessVisible) {
            gl.ActiveTexture(gl.TEXTURE2);
            gl.BindTexture(gl.TEXTURE_2D, material.roughnessMapId);
            gl.Uniform1i(gl.GetUniformLocation(program, "textureRoughness"), 2);
            gl.Uniform1i(gl.GetUniformLocation(program, "useRoughnessMap"), 1);
        } else {
            gl.ActiveTexture(gl.TEXTURE2);
            gl.BindTexture(gl.TEXTURE_2D, 0);
            gl.Uniform1i(gl.GetUniformLocation(program, "useRoughnessMap"), 0);
        }

        // Metallic texture
        gl.Uniform1f(gl.GetUniformLocation(program, "metallic"), 0.0); // Default metallic
        if (material.metallicMapId != 0 and state.overlayState.metallicVisible) {
            gl.ActiveTexture(gl.TEXTURE3);
            gl.BindTexture(gl.TEXTURE_2D, material.metallicMapId);
            gl.Uniform1i(gl.GetUniformLocation(program, "textureMetallic"), 3);
            gl.Uniform1i(gl.GetUniformLocation(program, "useMetallicMap"), 1);
        } else {
            gl.ActiveTexture(gl.TEXTURE3);
            gl.BindTexture(gl.TEXTURE_2D, 0);
            gl.Uniform1i(gl.GetUniformLocation(program, "useMetallicMap"), 0);
        }

    } else {
        // Default shader
        gl.ActiveTexture(gl.TEXTURE0);
        gl.BindTexture(gl.TEXTURE_2D, 0);
        gl.ActiveTexture(gl.TEXTURE1);
        gl.BindTexture(gl.TEXTURE_2D, 0);
        gl.Uniform1i(gl.GetUniformLocation(program, "useTexture"), 0);
        gl.Uniform1i(gl.GetUniformLocation(program, "useNormalMap"), 0);
        gl.Uniform4f(gl.GetUniformLocation(program, "defaultColor"), 0.4, 0.4, 0.4, 1.0); // Default shader
    }
}

/// Update the rotation, translation, and scale matrices
/// Values come from the window state (mouse and keyboard input from callbacks)
fn updateTransforms(rotation: *zmath.Mat, translation: *zmath.Mat, scale: *zmath.Mat, state: *window.WindowState) void {
    if(state.overlayState.manualEdit) {
        // Disable accidental input in background
        state.keys = .none;
        state.mouse.justPressed = true;

        updateTransformsOverlay(rotation, translation, scale, state);
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

/// Update the rotation, translation, and scale matrices based on the overlay state
fn updateTransformsOverlay(rotation: *zmath.Mat, translation: *zmath.Mat, scale: *zmath.Mat, state: *window.WindowState) void {
    // Position
    var newTranslation = translation.*;
    newTranslation[3][0] = @as(f32, state.overlayState.position[0]);
    newTranslation[3][1] = @as(f32, state.overlayState.position[1]);
    newTranslation[3][2] = @as(f32, state.overlayState.position[2]);
    translation.* = newTranslation;

    // Scale
    scale.* = zmath.scaling(state.overlayState.scale, state.overlayState.scale, state.overlayState.scale);

    // Rotation
    // Degrees to radians
    const xRad = state.overlayState.rotation[0] * (math.pi / 180.0);
    const yRad = state.overlayState.rotation[1] * (math.pi / 180.0);
    const zRad = state.overlayState.rotation[2] * (math.pi / 180.0);

    // New rotations
    const rotX = zmath.rotationX(xRad);
    const rotY = zmath.rotationY(yRad);
    const rotZ = zmath.rotationZ(zRad);
    rotation.* = zmath.mul(zmath.mul(rotZ, rotY), rotX);
}
