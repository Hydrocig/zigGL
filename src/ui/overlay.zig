//! UI Overlay
//!
//! OverlayState struct for storing overlay state
//! ImGui initialization and rendering functions
//! ImGui UI elements

const std = @import("std");
const glfw = @import("mach-glfw");
const zmath = @import("zmath");

const errors = @import("../util/errors.zig");
const validator = @import("../util/validator.zig");
const mesh = @import("../graphics/mesh.zig");
const window = @import("../window/window.zig");
const c = @cImport({
    @cInclude("cimgui.h");
});

/// OverlayState struct
///
/// Contains:
/// - position, rotation, scale (transformations)
/// - objPath (file path)
/// - manualEdit (flag for manual transformation editing)
/// - visible (flag for overlay visibility)
/// - errorMessage
pub const OverlayState = struct {
    // Transformation
    position: [3]f32 = .{ 0.0, 0.0, 0.0 },
    rotation: [3]f32 = .{ 0.0, 0.0, 0.0 },
    scale: f32 = 1.0,

    // File paths
    objPath: [256]u8 = [_]u8{0} ** 256,

    // State flags
    manualEdit: bool = false,
    visible: bool = false,

    // Error message
    errorMessage: [128]u8 = [_]u8{0} ** 128,

    // Material states
    diffuseVisible: bool = true,
    normalVisible: bool = true,
    roughnessVisible: bool = true,
    metallicVisible: bool = true,

    /// Helper method to set error message
    pub fn setErrorMessage(self: *OverlayState, msg: []const u8) void {
        std.mem.copyForwards(u8, &self.errorMessage, msg);
        // Add null terminator for C strings
        if (msg.len < self.errorMessage.len) {
            self.errorMessage[msg.len] = 0;
        }
    }

    /// Helper to get C-compatible error message pointer
    pub fn getErrorMessagePtr(self: *const OverlayState) [*c]const u8 {
        return @ptrCast(&self.errorMessage);
    }
};

// General purpose allocator
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

/// Initializes ImGui context
pub fn init(win: *const glfw.Window) void {
    c.InitImgui(win.handle);
}

/// Begins new UI frame
pub fn beginFrame() void {
    c.ImGuiImplOpenGL3_NewFrame();
    c.ImGuiImplGlfw_NewFrame();
    c.ImGuiNewFrame();
}

/// Ends UI frame and renders
pub fn endFrame() void {
    c.ImGuiRender();
    c.ImGuiImplOpenGL3_RenderDrawData();
}

/// Main UI rendering function
pub fn draw(state: *window.WindowState) !void {
    // Don't render if overlay is not visible
    if (!state.overlayState.visible) {
        return;
    }

    try filePanel(&state.overlayState);
    transformationPanel(&state.overlayState);
    materialPanel(&state.overlayState);
    resetButton(&state.overlayState);
}

/// UI part that handles file loading from .obj and .mtl paths
fn filePanel(state: *OverlayState) !void {
    c.ImGuiBeginGroup();
    defer c.ImGuiEndGroup();

    // OBJ file path
    c.Text("OBJ");
    c.SameLine(0, 18);
    const enterPressed = c.InputTextWithHint("##obj", "Path to .obj file", &state.objPath, state.objPath.len, c.ImGuiInputTextFlagsEnterReturnsTrue, null, null);

    // Load button
    if (c.Button("Load") or enterPressed) {
        try loadNewObject(&state.objPath, state);
    }
    c.SameLine(10, 35);
    c.TextColoredRGBA(1, 0, 0, 1, state.getErrorMessagePtr()); // Red RGBA
    c.Separator();
}

/// Loads new object from .obj path
fn loadNewObject(objPath: []const u8, state: *OverlayState) !void {
    // Clear any previous errors
    errors.errorCollector.clearError();

    mesh.deinit();
    try mesh.load(objPath);

    // Check if errorCollector has any error to display
    if (errors.errorCollector.getLastErrorMessage()) |errorMsg| {
        state.setErrorMessage(errorMsg);
        errors.errorCollector.clearError();
    } else {
        state.setErrorMessage("");
    }
}

/// UI part that handles transformation editing
fn transformationPanel(state: *OverlayState) void {
    c.ImGuiBeginGroup();
    defer c.ImGuiEndGroup();

    if (c.CollapsingHeaderStatic("Transformation", 0)) {
        _ = c.Checkbox("Enable ", &state.manualEdit); // Enable manual editing checkbox

        if (c.CollapsingHeader("Position", &state.manualEdit, 0)) {
            // x position
            c.Text("x:");
            c.SameLine(0, 10);
            _ = c.DragFloat("##xPos", &state.position[0], 0.007, -500.0, 500.0, "%.02f", 0);
            // y position
            c.Text("y:");
            c.SameLine(0, 10);
            _ = c.DragFloat("##yPos", &state.position[1], 0.007, -500.0, 500.0, "%.02f", 0);
            // z position
            c.Text("z:");
            c.SameLine(0, 10);
            _ = c.DragFloat("##zPos", &state.position[2], 0.007, -500.0, 500.0, "%.02f", 0);

            c.NewLine();
        }
        if (c.CollapsingHeader("Rotation", &state.manualEdit, 0)) {
            // x rotation
            c.Text("x:");
            c.SameLine(0, 10);
            _ = c.DragFloat("##xDeg", &state.rotation[0], 0.07, -360.0, 360.0, "%.01f °", 0);
            // y rotation
            c.Text("y:");
            c.SameLine(0, 10);
            _ = c.DragFloat("##yDeg", &state.rotation[1], 0.07, -360.0, 360.0, "%.01f °", 0);
            // z rotation
            c.Text("z:");
            c.SameLine(0, 10);
            _ = c.DragFloat("##zDeg", &state.rotation[2], 0.07, -360.0, 360.0, "%.01f °", 0);

            c.NewLine();
        }
        if (c.CollapsingHeader("Scale", &state.manualEdit, 0)) {
            // Scale
            c.Text("Scale: ");
            c.SameLine(0, 10);
            _ = c.DragFloat("##scale", &state.scale, 0.004, 0.01, 500.0, "%.02f", 0);

            c.NewLine();
        }
    }
    c.Separator();
}

/// UI part that handles material visibility
fn materialPanel(state: *OverlayState) void {
    c.ImGuiBeginGroup();
    defer c.ImGuiEndGroup();

    if (c.CollapsingHeaderStatic("Materials", 0)) {
        if (c.BeginTable2("MaterialTable", 2, c.ImGuiTableFlagsNone)) {
            _ = c.TableNextColumn();
            _ = c.Checkbox("Diffuse", &state.diffuseVisible);
            _ = c.TableNextColumn();
            _ = c.Checkbox("Normal", &state.normalVisible);
            _ = c.TableNextColumn();
            _ = c.Checkbox("Roughness", &state.roughnessVisible);
            _ = c.TableNextColumn();
            _ = c.Checkbox("Metallic", &state.metallicVisible);

            c.EndTable();
        }
    }

    c.Separator();
}

/// UI part that handles reset button
fn resetButton(state: *OverlayState) void {
    c.ImGuiBeginGroup();
    defer c.ImGuiEndGroup();

    if (c.Button("Reset")) {
        state.position = .{ 0.0, 0.0, 0.0 };
        state.rotation = .{ 0.0, 0.0, 0.0 };
        state.scale = 1.0;
    }
}
