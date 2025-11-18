[![CI](https://github.com/brodo/libssh/actions/workflows/ci.yaml/badge.svg)](https://github.com/brodo/libsshactions)

# libssh

This is [libssh](https://www.libssh.org), packaged for [Zig](https://ziglang.org/).

## Installation

First, update your `build.zig.zon`:

```
# Initialize a `zig build` project if you haven't already
zig init
zig fetch --save git+https://github.com/brodo/libssh
```

You can then import `libssh` in your `build.zig` with:

```zig
const libssh_dep = b.dependency("libssh", .{
    .target = target,
    .optimize = optimize,
});
your_exe.root_module.linkLibrary(libssh_dep.artifact("libssh"));
```