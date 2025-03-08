const std = @import("std");
const gl = @import("gl");
const zmath = @import("zmath");
const math = @import("std").math;
const window = @import("./window/window.zig");
const shader = @import("./graphics/shader.zig");
const glfw = @import("mach-glfw");
const mesh = @import("./graphics/mesh.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    if (!glfw.init(.{})) {
        std.log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        return error.GLInitFailed;
    }
    defer glfw.terminate();

    const win = try window.init("zigGL");
    defer win.destroy();

    var state = window.WindowState{};
    window.setupCallbacks(win, &state);

    const cube = try mesh.load(allocator, "objects/cube2.obj");
    defer cube.deinit();

    const program = try shader.compile(allocator,
        "src/graphics/shaders/vertex.shader.glsl",
        "src/graphics/shaders/fragment.shader.glsl");
    defer gl.DeleteProgram(program);

    gl.Enable(gl.DEPTH_TEST);
    gl.UseProgram(program);

    var rotation = zmath.matFromRollPitchYaw(0, 0, 0);
    var translation = zmath.identity();
    var scale = zmath.identity();

    while (!win.shouldClose()) {
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        // Update transformations based on input state
        updateTransforms(&rotation, &translation, &scale, &state);

        // Calculate MVP matrix
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

        win.swapBuffers();
        glfw.pollEvents();
    }
}

fn updateTransforms(rotation: *zmath.Mat, translation: *zmath.Mat, scale: *zmath.Mat, state: *window.WindowState) void {
    // Handle rotation
    if (state.mouse.dragging) {
        const deltaX = state.mouse.x - state.mouse.last_x;
        const deltaY = state.mouse.y - state.mouse.last_y;

        const rotX = @as(f32, @floatCast(deltaY * 0.01));
        const rotY = @as(f32, @floatCast(deltaX * 0.01));

        const currentRotation = rotation.*;
        const newRotX = zmath.mul(currentRotation, zmath.rotationX(rotX));
        const newRotY = zmath.mul(zmath.rotationY(rotY), newRotX);
        rotation.* = newRotY;

        state.mouse.last_x = state.mouse.x;
        state.mouse.last_y = state.mouse.y;
    }

    // Handle translation and scaling
    switch (state.keys) {
        .x, .y, .z => {
            if (state.mouse.last_x == 0 or state.mouse.last_y == 0) {
                state.mouse.last_x = state.mouse.x;
                state.mouse.last_y = state.mouse.y;
            }

            const deltaX = state.mouse.x - state.mouse.last_x;
            const deltaY = state.mouse.y - state.mouse.last_y;
            const delta = (deltaX + deltaY) * 0.006;

            const axis: usize = switch (state.keys) {
                .x => 0,
                .y => 1,
                .z => 2,
                else => unreachable,
            };

            var newTranslation = translation.*;
            newTranslation[3][axis] += @as(f32, @floatCast(delta));
            translation.* = newTranslation;

            state.mouse.last_x = state.mouse.x;
            state.mouse.last_y = state.mouse.y;
        },
        .s => {
            if (state.mouse.last_x == 0 or state.mouse.last_y == 0) {
                state.mouse.last_x = state.mouse.x;
                state.mouse.last_y = state.mouse.y;
            }

            const deltaX = state.mouse.x - state.mouse.last_x;
            const deltaY = state.mouse.y - state.mouse.last_y;
            const mouseDelta = deltaX + deltaY;
            const scrollDelta = state.scroll;

            var totalDelta = @as(f32, @floatCast((mouseDelta + scrollDelta) * 0.006));

            if (totalDelta < 0) {
                totalDelta = totalDelta * 1.5;
            }

            const scaleFactor = 1.0 + totalDelta;
            const scaleMatrix = zmath.scaling(scaleFactor, scaleFactor, scaleFactor);
            scale.* = zmath.mul(scale.*, scaleMatrix);

            state.scroll = 0;
            state.mouse.last_x = state.mouse.x;
            state.mouse.last_y = state.mouse.y;

        },
        .none => {},
    }
}