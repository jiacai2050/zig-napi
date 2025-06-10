const std = @import("std");
const Build = std.Build;
const Step = Build.Step;
const Module = Build.Module;
const Allocator = std.mem.Allocator;

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .optimize = optimize,
        .target = target,
    });
    const addon = b.addLibrary(.{
        .name = "hello",
        .root_module = module,
        .linkage = .dynamic,
    });
    addon.linker_allow_shlib_undefined = true;

    const headers_dep = b.dependency("napi_headers", .{
        .optimize = optimize,
        .target = target,
    });
    addon.addSystemIncludePath(headers_dep.path("include"));

    const install_lib = b.addInstallArtifact(addon, .{
        .dest_sub_path = "hello.node",
    });
    b.getInstallStep().dependOn(&install_lib.step);
}
