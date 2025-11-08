# libdeflate

This is [libdeflate](https://github.com/ebiggers/libdeflate),
packaged for [Zig](https://ziglang.org/).

## How to use it

First, update your `build.zig.zon`:

```
zig fetch --save git+https://github.com/burakssen/libdeflate
```

Next, add this snippet to your `build.zig` script:

```zig
const libdeflate_dep = b.dependency("libdeflate", .{
    .target = target,
    .optimize = optimize,
});
your_compilation.linkLibrary(libdeflate_dep.artifact("deflate"));
```

This will provide libdeflate as a static library to `your_compilation`.
