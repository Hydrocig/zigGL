const std = @import("std");

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

    // zglfw
    const zglfw = b.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zglfw", zglfw.module("root"));
    exe.linkLibrary(zglfw.artifact("glfw"));

    // zigglgen (OpenGL bindings)
    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"4.1",
        .profile = .core,
        .extensions = &.{ .ARB_clip_control, .NV_scissor_exclusive },
    });
    exe.root_module.addImport("gl", gl_bindings);

    // zgui
    const zgui = b.dependency("zgui", .{
        .shared = false,
        .with_implot = true,
    });
    exe.root_module.addImport("zgui", zgui.module("root"));
    exe.linkLibrary(zgui.artifact("imgui"));
    { // Needed for glfw/wgpu rendering backend
        const zpool = b.dependency("zpool", .{});
        exe.root_module.addImport("zpool", zpool.module("root"));

        const zgpu = b.dependency("zgpu", .{});
        exe.root_module.addImport("zgpu", zgpu.module("root"));
        exe.linkLibrary(zgpu.artifact("zdawn"));
    }

    exe.linkSystemLibrary("c");
    b.installArtifact(exe);
    exe.addIncludePath(b.path("libs"));

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the executable");
    run_step.dependOn(&run_cmd.step);
}

// Define the paths for the build
pub const paths = struct {
    src: []const u8 = "src",
    build: []const u8 = "zig-out",
};
