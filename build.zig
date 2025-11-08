const std = @import("std");

pub fn build(b: *std.Build) void {
    const upstream = b.dependency("libdeflate", .{});
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build options matching CMake's options
    const compression_support = b.option(bool, "compression_support", "Support compression") orelse true;
    const decompression_support = b.option(bool, "decompression_support", "Support decompression") orelse true;
    const zlib_support = b.option(bool, "zlib_support", "Support the zlib format") orelse true;
    const gzip_support = b.option(bool, "gzip_support", "Support the gzip format") orelse true;
    const freestanding = b.option(bool, "freestanding", "Build a freestanding library") orelse false;

    const lib = b.addLibrary(.{
        .name = "deflate",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });

    // Link libc unless in freestanding mode
    if (!freestanding) {
        lib.linkLibC();
    }

    // Common sources
    lib.addIncludePath(upstream.path(""));
    lib.addIncludePath(upstream.path("lib"));

    var sources: std.ArrayList([]const u8) = .empty;
    defer sources.deinit(b.allocator);

    // Always include utils.c
    sources.append(b.allocator, "utils.c") catch @panic("OOM");

    // Compression sources
    if (compression_support) {
        sources.append(b.allocator, "deflate_compress.c") catch @panic("OOM");
    }

    // Decompression sources
    if (decompression_support) {
        sources.append(b.allocator, "deflate_decompress.c") catch @panic("OOM");
    }

    // Zlib format support
    if (zlib_support) {
        sources.append(b.allocator, "adler32.c") catch @panic("OOM");
        if (compression_support) {
            sources.append(b.allocator, "zlib_compress.c") catch @panic("OOM");
        }
        if (decompression_support) {
            sources.append(b.allocator, "zlib_decompress.c") catch @panic("OOM");
        }
    }

    // Gzip format support
    if (gzip_support) {
        sources.append(b.allocator, "crc32.c") catch @panic("OOM");
        if (compression_support) {
            sources.append(b.allocator, "gzip_compress.c") catch @panic("OOM");
        }
        if (decompression_support) {
            sources.append(b.allocator, "gzip_decompress.c") catch @panic("OOM");
        }
    }

    // Add the collected source files
    lib.addCSourceFiles(.{
        .root = upstream.path("lib"),
        .files = sources.items,
        .flags = &.{
            "-Wall",
            "-Wdeclaration-after-statement",
            "-Wimplicit-fallthrough",
            "-Wmissing-field-initializers",
            "-Wmissing-prototypes",
            "-Wpedantic",
            "-Wshadow",
            "-Wstrict-prototypes",
            "-Wundef",
            "-Wvla",
            "-std=c99",
        },
    });

    // Compiler definitions
    if (freestanding) {
        lib.root_module.addCMacro("FREESTANDING", "null");
    }

    // Architecture-specific sources and includes
    switch (target.result.cpu.arch) {
        .arm, .aarch64, .aarch64_be, .armeb => {
            lib.addCSourceFiles(.{
                .root = upstream.path("lib/arm"),
                .files = &.{"cpu_features.c"},
            });
            lib.addIncludePath(upstream.path("lib/arm"));
        },
        .riscv32, .riscv64 => {
            lib.addIncludePath(upstream.path("lib/riscv"));
        },
        .x86, .x86_64 => {
            lib.addCSourceFiles(.{
                .root = upstream.path("lib/x86"),
                .files = &.{"cpu_features.c"},
            });
            lib.addIncludePath(upstream.path("lib/x86"));
        },
        else => {},
    }

    // Install the library
    b.installArtifact(lib);

    // Install the public header
    const header_install = b.addInstallHeaderFile(
        upstream.path("libdeflate.h"),
        "libdeflate.h",
    );
    b.getInstallStep().dependOn(&header_install.step);
}
