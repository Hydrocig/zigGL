//! Window and input handling
//!
//! Provides structs that store the states of keys, mouse, and the window itself
//! Also provides the necessary glfw callback functions to handle input
//! Creates the window and sets up the OpenGL context

const std = @import("std");
const glfw = @import("zglfw");
const zmath = @import("zmath");
const gl = @import("gl");

var gl_proc_table: gl.ProcTable = undefined;

const DEFAULT_WIDTH: f32 = 800;     // Initial window width
const DEFAULT_HEIGHT: f32 = 800;    // Initial window height

/// Window state struct
///
/// Contains:
/// - width and height of the window
/// - mouse state struct
/// - key state union
/// - scroll value
pub const WindowState = struct {
    width: f32 = DEFAULT_WIDTH,
    height: f32 = DEFAULT_HEIGHT,
    mouse: MouseState = .{},
    keys: KeyState = .none,
    scroll: f64 = 0,
};

/// Mouse state struct
///
/// Contains:
/// - current mouse position
/// - last mouse position
/// - dragging state
/// - justPressed state (used to prevent sudden jumps when dragging)
pub const MouseState = struct {
    x: f64 = 0,
    y: f64 = 0,
    last_x: f64 = 0,
    last_y: f64 = 0,
    dragging: bool = false,
    justPressed: bool = true,
};

/// Key state union
///
/// Contains:
/// - none: no key pressed
/// - x, y, z: keys pressed (move along X, Y, or Z axis)
/// - s: key pressed (scale)
pub const KeyState = union(enum) {
    none,
    x,
    y,
    z,
    s,
};

/// Initialize the window and OpenGL context
/// Gets called once at the start of the program
pub fn init(title: [:0]const u8) !*glfw.Window {
    const errorCallbackResult = glfw.setErrorCallback(errorCallback);
    _ = errorCallbackResult;

    //const gl_major = 4;
    //const gl_minor = 5;
    //glfw.windowHint(.context_version_major, gl_major);
    //glfw.windowHint(.context_version_minor, gl_minor);
    //glfw.windowHint(.opengl_profile, .opengl_core_profile);
    //glfw.windowHint(.opengl_forward_compat, true);
    //glfw.windowHint(.client_api, .opengl_api);
    //glfw.windowHint(.doublebuffer, true);

    const window = try glfw.Window.create(
        @intFromFloat(DEFAULT_WIDTH),                    // Window-width
        @intFromFloat(DEFAULT_HEIGHT),                  // Window-height
        title,                                            // Window-title
        null
    );

    glfw.makeContextCurrent(window);

    // Initialize OpenGL function pointers
    if (!gl_proc_table.init(glfw.getProcAddress)) {
        std.log.err("failed to initialize ProcTable ", .{});
        return error.GLInitFailed;
    }
    gl.makeProcTableCurrent(&gl_proc_table);

    glfw.swapInterval(1);
    return window;
}

fn errorCallback(error_code: glfw.ErrorCode, description: ?[*:0]const u8) callconv(.C) void {
    std.log.err("GLFW error: {}: {s}", .{ error_code, description.? });
}

/// Setup the GLFW callbacks for the window
/// Sets the user pointer to the window state
pub fn setupCallbacks(window: *glfw.Window, state: *WindowState) void {
    window.setUserPointer(state);

    _ = window.setMouseButtonCallback(mouseCallback);
    _ = window.setCursorPosCallback(cursorCallback);
    _ = window.setKeyCallback(keyCallback);
    _ = window.setScrollCallback(scrollCallback);
    _ = window.setFramebufferSizeCallback(resizeCallback);
}

/// GLFW cursor position callback
/// Updates the mouse position when the cursor moves
fn cursorCallback(window: *glfw.Window, xpos: f64, ypos: f64) callconv(.C) void {
    const state: *WindowState = window.getUserPointer(WindowState).?; // Retrieve the window state

    state.mouse.x = xpos;
    state.mouse.y = ypos;
}

/// GLFW mouse button callback
/// Updates the mouse dragging state when a mouse button is pressed or released
fn mouseCallback(window: *glfw.Window, button: glfw.MouseButton, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
    const state: *WindowState = window.getUserPointer(WindowState).?; // Retrieve the window state
    state.keys = .none;

    // Left mouse button pressed with shift key -> dragging
    if (button == .left and mods.shift == true) {
        if (action == .press) {
            state.mouse.dragging = true;
            state.mouse.justPressed = true;
        } else {
            state.mouse.dragging = false;
            state.mouse.justPressed = false;
        }
    } else {
        state.mouse.dragging = false;
    }
}

/// GLFW key callback
/// Updates the key state when a key is pressed or released
fn keyCallback(window: *glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
    _ = &scancode;
    _ = &window;
    const state: *WindowState = window.getUserPointer(WindowState).?; // Retrieve the window state

    // Set key union based on key pressed
    if (action == .press and mods.control == false and mods.shift == false) {
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

/// GLFW scroll callback
/// Updates the scroll value when the mouse wheel is scrolled
fn scrollCallback(window: *glfw.Window, xoffset: f64, yoffset: f64) callconv(.C) void {
    _ = &xoffset;
    _ = &window;
    const state: *WindowState = window.getUserPointer(WindowState).?; // Retrieve the window state

    state.scroll += yoffset;
}

/// GLFW framebuffer size callback
/// Updates the window width and height when the window is resized
fn resizeCallback(window: *glfw.Window, width: c_int, height: c_int) callconv(.C) void {
    _ = &window;
    const state: *WindowState = window.getUserPointer(WindowState).?; // Retrieve the window state

    // Update window width and height
    state.width = @floatFromInt(width);
    state.height = @floatFromInt(height);
    gl.Viewport(0, 0, @intCast(width), @intCast(height));
}
