const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
    });
    const sdl_image_dep = b.dependency("SDL_image", .{
        .target = target,
        .optimize = optimize,
    });

    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/context.zig"),
    });

    const lib = b.addLibrary(.{
        .name = "zsdlgpu",
        .root_module = mod,
    });
    lib.linkLibrary(sdl_dep.artifact("SDL3"));
    lib.linkLibrary(sdl_image_dep.artifact("sdl_image"));
    b.installArtifact(lib);


    const exe = b.addExecutable(.{
        .name = "zz",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/tests/test1.zig"),
        }),
    });
    b.installArtifact(exe);
    exe.root_module.addImport("zsdlgpu", mod);
    const run_exe = b.addRunArtifact(exe);
    // if (b.args) |args| run_mod_tests.addArgs(args);
    const run_step = b.step("run", "Run");
    run_step.dependOn(&run_exe.step);
}
