const std = @import("std");

const c_flags = &.{
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
};

const Options = struct {
    compression: bool,
    decompression: bool,
    zlib: bool,
    gzip: bool,
    freestanding: bool,

    fn init(b: *std.Build) Options {
        return .{
            .compression = b.option(bool, "compression_support", "Support compression") orelse true,
            .decompression = b.option(bool, "decompression_support", "Support decompression") orelse true,
            .zlib = b.option(bool, "zlib_support", "Support the zlib format") orelse true,
            .gzip = b.option(bool, "gzip_support", "Support the gzip format") orelse true,
            .freestanding = b.option(bool, "freestanding", "Build a freestanding library") orelse false,
        };
    }
};

fn addIf(
    b: *std.Build,
    sources: *std.ArrayList([]const u8),
    cond: bool,
    files: []const []const u8,
) void {
    if (cond) sources.appendSlice(b.allocator, files) catch @panic("OOM");
}

pub fn build(b: *std.Build) void {
    const upstream = b.dependency("libdeflate", .{});
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const opts = Options.init(b);

    const lib = b.addLibrary(.{
        .name = "deflate",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = !opts.freestanding,
        }),
    });

    const mod = lib.root_module;

    mod.addIncludePath(upstream.path(""));
    mod.addIncludePath(upstream.path("lib"));
    lib.installHeader(upstream.path("libdeflate.h"), "libdeflate.h");

    var sources: std.ArrayList([]const u8) = .empty;
    defer sources.deinit(b.allocator);

    addIf(b, &sources, true, &.{"utils.c"});

    addIf(b, &sources, opts.compression, &.{
        "deflate_compress.c",
    });

    addIf(b, &sources, opts.decompression, &.{
        "deflate_decompress.c",
    });

    addIf(b, &sources, opts.zlib, &.{
        "adler32.c",
    });
    addIf(b, &sources, opts.zlib and opts.compression, &.{
        "zlib_compress.c",
    });
    addIf(b, &sources, opts.zlib and opts.decompression, &.{
        "zlib_decompress.c",
    });

    addIf(b, &sources, opts.gzip, &.{
        "crc32.c",
    });
    addIf(b, &sources, opts.gzip and opts.compression, &.{
        "gzip_compress.c",
    });
    addIf(b, &sources, opts.gzip and opts.decompression, &.{
        "gzip_decompress.c",
    });

    mod.addCSourceFiles(.{
        .root = upstream.path("lib"),
        .files = sources.items,
        .flags = c_flags,
    });

    if (opts.freestanding)
        mod.addCMacro("FREESTANDING", "1");

    switch (target.result.cpu.arch) {
        .arm, .armeb, .aarch64, .aarch64_be => {
            mod.addIncludePath(upstream.path("lib/arm"));
            mod.addCSourceFiles(.{
                .root = upstream.path("lib/arm"),
                .files = &.{"cpu_features.c"},
            });
        },
        .x86, .x86_64 => {
            mod.addIncludePath(upstream.path("lib/x86"));
            mod.addCSourceFiles(.{
                .root = upstream.path("lib/x86"),
                .files = &.{"cpu_features.c"},
            });
        },
        .riscv32, .riscv64 => {
            mod.addIncludePath(upstream.path("lib/riscv"));
        },
        else => {},
    }

    b.installArtifact(lib);
}
