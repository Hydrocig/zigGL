//! Window and input handling
//!
//! Provides structs that store the states of keys, mouse, and the window itself
//! Also provides the necessary glfw callback functions to handle input
//! Creates the window and sets up the OpenGL context

const std = @import("std");
const glfw = @import("mach-glfw");
const zmath = @import("zmath");
const gl = @import("gl");

const c = @cImport({
    @cInclude("cimgui.h");
});

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
pub fn init(title: [*:0]const u8) !glfw.Window {
    glfw.setErrorCallback(errorCallback);

    const window = glfw.Window.create(
        @intFromFloat(DEFAULT_WIDTH),                    // Window-width
        @intFromFloat(DEFAULT_HEIGHT),                  // Window-height
        title,                                            // Window-title
        null, null, .{
        .context_version_major = 4,                      // OpenGL major version
        .context_version_minor = 5,                      // OpenGL minor version
        .opengl_profile = .opengl_core_profile,  // OpenGL profile
        .opengl_forward_compat = true,                   // OpenGL forward compatibility
    }) orelse return error.WindowCreateFailed;

    glfw.makeContextCurrent(window);

    // Initialize OpenGL function pointers
    if (!gl_proc_table.init(glfw.getProcAddress)) {
        std.log.err("failed to initialize ProcTable: {?s}", .{glfw.getErrorString()});
        return error.GLInitFailed;
    }
    gl.makeProcTableCurrent(&gl_proc_table);

    glfw.swapInterval(1);
    return window;
}

fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("GLFW error: {}: {s}", .{ error_code, description });
}

/// Setup the GLFW callbacks for the window
/// Sets the user pointer to the window state
pub fn setupCallbacks(window: glfw.Window, state: *WindowState) void {
    window.setUserPointer(state);

    window.setMouseButtonCallback(mouseCallback);
    window.setCursorPosCallback(cursorCallback);
    window.setKeyCallback(keyCallback);
    window.setScrollCallback(scrollCallback);
    window.setFramebufferSizeCallback(resizeCallback);
}

/// GLFW cursor position callback
/// Updates the mouse position when the cursor moves
fn cursorCallback(window: glfw.Window, xpos: f64, ypos: f64) void {
    const state: *WindowState = window.getUserPointer(WindowState).?; // Retrieve the window state

    c.ImGui_CursorPosCallback(@ptrCast(window.handle), xpos, ypos); // Cpp glfw callback

    state.mouse.x = xpos;
    state.mouse.y = ypos;
}

/// GLFW mouse button callback
/// Updates the mouse dragging state when a mouse button is pressed or released
fn mouseCallback(window: glfw.Window, button: glfw.MouseButton, action: glfw.Action, mods: glfw.Mods) void {
    const state: *WindowState = window.getUserPointer(WindowState).?; // Retrieve the window state
    state.keys = .none;

    c.ImGui_MouseButtonCallback(@ptrCast(window.handle), @intFromEnum(button), @intFromEnum(action), mods.toInt(c_int)); // Cpp glfw callback

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
fn keyCallback(window: glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) void {
    _ = &scancode;
    _ = &window;
    const state: *WindowState = window.getUserPointer(WindowState).?; // Retrieve the window state

    c.ImGui_KeyCallback(@ptrCast(window.handle), @intFromEnum(key), scancode, @intFromEnum(action), mods.toInt(c_int)); // Cpp glfw callback

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
fn scrollCallback(window: glfw.Window, xoffset: f64, yoffset: f64) void {
    _ = &xoffset;
    _ = &window;
    const state: *WindowState = window.getUserPointer(WindowState).?; // Retrieve the window state

    c.ImGui_ScrollCallback(@ptrCast(window.handle), xoffset, yoffset); // Cpp glfw callback

    state.scroll += yoffset;
}

/// GLFW framebuffer size callback
/// Updates the window width and height when the window is resized
fn resizeCallback(window: glfw.Window, width: u32, height: u32) void {
    _ = &window;
    const state: *WindowState = window.getUserPointer(WindowState).?; // Retrieve the window state

    // Update window width and height
    state.width = @floatFromInt(width);
    state.height = @floatFromInt(height);
    gl.Viewport(0, 0, @intCast(width), @intCast(height));
}
