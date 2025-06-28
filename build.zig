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

    // Build docs
    const doc_object = b.addObject(.{
        .name = "napi_docs",
        .root_module = napi_module,
        .optimize = optimize,
    });
    doc_object.root_module.addImport("napi", napi_module);
    const docs_step = b.step("docs", "Generate docs");
    const docs_install = b.addInstallDirectory(.{
        .source_dir = doc_object.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    docs_step.dependOn(&docs_install.step);

    // Build examples/tests
    inline for (.{
        // (dir, name)
        .{ .examples, "hello" },
        .{ .examples, "function" },
        .{ .tests, "main" },
    }) |input| {
        const dir, const name = input;
        const path = std.fmt.comptimePrint("{s}/{s}.zig", .{ @tagName(dir), name });
        const example = b.addLibrary(.{
            .name = name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(path),
                .optimize = optimize,
                .target = target,
            }),
            .linkage = .dynamic,
        });
        example.root_module.addImport("napi", napi_module);
        example.linker_allow_shlib_undefined = true;

        const install_lib = b.addInstallArtifact(example, .{
            .dest_sub_path = name ++ ".node",
        });
        b.getInstallStep().dependOn(&install_lib.step);
    }
}
