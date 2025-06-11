const std = @import("std");
const Build = std.Build;
const Step = Build.Step;
const Module = Build.Module;
const Allocator = std.mem.Allocator;

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const napi_module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .optimize = optimize,
        .target = target,
    });
    const headers_dep = b.dependency("napi_headers", .{
        .optimize = optimize,
        .target = target,
    });
    napi_module.addSystemIncludePath(headers_dep.path("include"));

    const example = b.addLibrary(.{
        .name = "hello",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/hello.zig"),
            .optimize = optimize,
            .target = target,
        }),
        .linkage = .dynamic,
    });
    example.root_module.addImport("zig-napi", napi_module);
    example.linker_allow_shlib_undefined = true;

    const install_lib = b.addInstallArtifact(example, .{
        .dest_sub_path = "hello.node",
    });
    b.getInstallStep().dependOn(&install_lib.step);
}
