const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "raylib_game",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Add include and lib paths to the copied raylib_bin
    exe.root_module.addIncludePath(b.path("raylib_bin/include"));
    exe.root_module.addLibraryPath(b.path("raylib_bin/lib"));
    
    // Link the required libraries
    exe.root_module.linkSystemLibrary("raylib", .{});
    exe.root_module.linkSystemLibrary("gdi32", .{});
    exe.root_module.linkSystemLibrary("winmm", .{});
    exe.root_module.linkSystemLibrary("opengl32", .{});
    exe.root_module.link_libc = true;

    b.installArtifact(exe);

    // Install the raylib.dll next to the executable
    b.installBinFile(
        "raylib_bin/lib/raylib.dll",
        "raylib.dll",
    );

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
