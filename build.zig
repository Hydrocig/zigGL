const std = @import("std");
const mach_glfw = @import("mach-glfw");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zigGL",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // zmath
    const zmath = b.dependency("zmath", .{});
    exe.root_module.addImport("zmath", zmath.module("root"));

    // mach-glfw
    const glfw_dep = b.dependency("mach_glfw", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("mach-glfw", glfw_dep.module("mach-glfw"));

    // zigglen (OpenGL bindings)
    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"4.1",
        .profile = .core,
        .extensions = &.{ .ARB_clip_control, .NV_scissor_exclusive },
    });
    exe.root_module.addImport("gl", gl_bindings);

    // Add GLFW include path
    const glfw_include_path = b.path("libs/glfw/include/"); // Path to GLFW headers
    exe.addIncludePath(glfw_include_path);

    // Add GLFW library path
    const glfw_lib_path = b.path("libs/glfw/lib-static-ucrt/"); // Path to GLFW libraries
    exe.addLibraryPath(glfw_lib_path);

    // Add ImGui include path
    const imgui_include_path = b.path("libs/imgui/"); // Path to ImGui headers
    exe.addIncludePath(imgui_include_path);

    // Add ImGui source files
    exe.addCSourceFile(.{ .file = b.path("libs/imgui/imgui.cpp"), .flags = &.{"-std=c++11"} });
    exe.addCSourceFile(.{ .file = b.path("libs/imgui/imgui_draw.cpp"), .flags = &.{"-std=c++11"} });
    exe.addCSourceFile(.{ .file = b.path("libs/imgui/imgui_tables.cpp"), .flags = &.{"-std=c++11"} });
    exe.addCSourceFile(.{ .file = b.path("libs/imgui/imgui_widgets.cpp"), .flags = &.{"-std=c++11"} });
    exe.addCSourceFile(.{ .file = b.path("libs/imgui/backends/imgui_impl_glfw.cpp"), .flags = &.{"-std=c++11"} });
    exe.addCSourceFile(.{ .file = b.path("libs/imgui/backends/imgui_impl_opengl3.cpp"), .flags = &.{"-std=c++11"} });
    
    exe.addCSourceFile(.{.file = b.path("libs/cimgui.cpp"), .flags = &.{"-std=c++11"}});
    exe.addIncludePath(b.path("libs"));

    exe.linkSystemLibrary("glfw3"); // Link against glfw3.lib
    exe.linkSystemLibrary("opengl32"); // Link against OpenGL

    exe.linkLibC(); // Link against the C standard library
    exe.linkLibCpp(); // Link against the C++ standard library

    // Install the executable
    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the executable");
    run_step.dependOn(&run_cmd.step);
}