const std = @import("std");
const glfw = @import("mach-glfw");
const zmath = @import("zmath");
const gl = @import("gl");

const DEFAULT_WIDTH: f32 = 800;
const DEFAULT_HEIGHT: f32 = 800;

pub const WindowState = struct {
    width: f32 = DEFAULT_WIDTH,
    height: f32 = DEFAULT_HEIGHT,
    mouse: MouseState = .{},
    keys: KeyState = .none,
    scroll: f64 = 0,
};

pub const MouseState = struct {
    x: f64 = 0,
    y: f64 = 0,
    last_x: f64 = 0,
    last_y: f64 = 0,
    dragging: bool = false,
};

pub const KeyState = union(enum) {
    none,
    x,
    y,
    z,
    s,
};

pub fn init(title: [*:0]const u8) !glfw.Window {
    glfw.setErrorCallback(errorCallback);
    if (!glfw.init(.{})) return error.GLFWInitFailed;

    const window = glfw.Window.create(

        @intFromFloat(DEFAULT_WIDTH),
        @intFromFloat(DEFAULT_HEIGHT),
        title,
        null, null, .{
        .context_version_major = 4,
        .context_version_minor = 5,
        .opengl_profile = .opengl_core_profile,
        .opengl_forward_compat = true,
    }) orelse return error.WindowCreateFailed;

    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);
    return window;
}

fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("GLFW error: {}: {s}", .{error_code, description});
}

pub fn setupCallbacks(window: glfw.Window, state: *WindowState) void {
    window.setUserPointer(state);
    window.setMouseButtonCallback(mouseCallback);
    window.setKeyCallback(keyCallback);
    window.setScrollCallback(scrollCallback);
    window.setFramebufferSizeCallback(resizeCallback);
}

fn mouseCallback(window: glfw.Window, button: glfw.MouseButton, action: glfw.Action, mods: glfw.Mods) void {
    _ = &mods;
    const state: *WindowState = window.getUserPointer(WindowState).?;

    if (button == .left) {
        if (action == .press) {
            const pos = window.getCursorPos();
            state.mouse.dragging = true;
            state.mouse.last_x = pos.xpos;
            state.mouse.last_y = pos.ypos;
        } else {
            state.mouse.dragging = false;
        }
    }
}

fn keyCallback(window: glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) void {
    _ = &scancode;
    _ = &mods;
    _ = &window;
    const state: *WindowState = window.getUserPointer(WindowState).?;

    if (action == .press) {
        state.keys = switch (key) {
            .x => .x,
            .y => .y,
            .z => .z,
            .s => .s,
            else => .none,
        };
    } else if (action == .release) {
        state.keys = .none;
    }
}

fn scrollCallback(window: glfw.Window, xoffset: f64, yoffset: f64) void {
    _ = &xoffset;
    _ = &window;
    const state: *WindowState = window.getUserPointer(WindowState).?;

    state.scroll += yoffset;
}

fn resizeCallback(window: glfw.Window, width: u32, height: u32) void {
    _ = &window;
    const state: *WindowState = window.getUserPointer(WindowState).?;

    state.width = @floatFromInt(width);
    state.height = @floatFromInt(height);
    gl.Viewport(0, 0, @intCast(width), @intCast(height));
}
