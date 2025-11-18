const std = @import("std");

const Options = struct {
    linkage: std.builtin.LinkMode = .static,
    global_bind_config: []const u8 = "/etc/ssh/libssh_server_config",
    global_client_config: []const u8 = "/etc/ssh/ssh_config",
};

const version: std.SemanticVersion = .{
    .major = 0,
    .minor = 11,
    .patch = 3,
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options: Options = .{
        .linkage = b.option(std.builtin.LinkMode, "linkage", "Whether to build as a static or dynamic library (default: static)") orelse .static,
        .global_bind_config = b.option([]const u8, "global_bind_config", "") orelse "/etc/ssh/libssh_server_config",
        .global_client_config = b.option([]const u8, "global_client_config", "") orelse "/etc/ssh/ssh_config",
    };

    const libssh = b.addLibrary(.{
        .name = "libssh",
        .linkage = options.linkage,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    const mbedtls_dependency = b.dependency("mbedtls", .{
        .target = target,
        .optimize = optimize,
    });
    libssh.root_module.linkLibrary(mbedtls_dependency.artifact("mbedtls"));
    const zlib_dep = b.dependency("zlib", .{
        .target = target,
        .optimize = optimize,
    });
    libssh.root_module.linkLibrary(zlib_dep.artifact("z"));

    const libssh_dep = b.dependency("libssh", .{});
    try addCSourceFiles(b, libssh.root_module, libssh_dep.path("src"));
    libssh.root_module.addIncludePath(libssh_dep.path("include"));
    libssh.installHeadersDirectory(libssh_dep.path("include/libssh"), "libssh", .{});

    const is_windows = target.result.os.tag == .windows;
    const is_mac = target.result.os.tag == .macos;
    const config_header = b.addConfigHeader(.{
        .style = .{ .cmake = libssh_dep.path("config.h.cmake") },
        .include_path = "config.h",
    }, .{
        .PROJECT_NAME = "libssh",
        .PROJECT_VERSION = b.fmt("{f}", .{version}),
        .SYSCONFDIR = null,
        .BINARYDIR = b.makeTempPath(),
        .SOURCEDIR = b.build_root.path.?,
        .GLOBAL_BIND_CONFIG = options.global_bind_config,
        .GLOBAL_CLIENT_CONFIG = options.global_client_config,

        .HAVE_PTHREAD = getThreadsLib(libssh.root_module.resolved_target.?.result) == .pthreads,
        .HAVE_TERMIOS_H = !is_windows,
        .HAVE_SYS_TIME_H = true,
        .HAVE_ISBLANK = true,
        .HAVE_STRNCPY = true,
        .HAVE_STRNDUP = !is_windows,
        .HAVE_STRTOULL = true,
        .HAVE_EXPLICIT_BZERO = !is_windows and !is_mac,
        .HAVE_MEMSET_S = !is_windows,
        .HAVE_COMPILER__FUNC__ = true,
        .HAVE_GETADDRINFO = true,
        .HAVE_LIBMBEDCRYPTO = true,
        .HAVE_HTONLL = is_mac or is_windows,
        .HAVE_NTOHLL = is_mac or is_windows,
        .WITH_ZLIB = true,
        .WITH_SERVER = true,
    });
    libssh.addConfigHeader(config_header);

    const version_header = b.addConfigHeader(.{
        .style = .{ .cmake = libssh_dep.path("include/libssh/libssh_version.h.cmake") },
        .include_path = "libssh/libssh_version.h",
    }, .{
        .libssh_VERSION_MAJOR = @as(i64, @intCast(version.major)),
        .libssh_VERSION_MINOR = @as(i64, @intCast(version.minor)),
        .libssh_VERSION_PATCH = @as(i64, @intCast(version.patch)),
    });
    libssh.addConfigHeader(version_header);
    b.installArtifact(libssh);
}

fn getThreadsLib(target: std.Target) ?enum { pthreads, win32 } {
    return switch (target.os.tag) {
        .windows => .win32,
        .wasi => null,
        else => .pthreads,
    };
}

fn addCSourceFiles(b: *std.Build, mod: *std.Build.Module, src: std.Build.LazyPath) !void {
    const flags: []const []const u8 = &.{};

    // unconditional source files
    mod.addCSourceFiles(.{
        .root = src,
        .files = &.{
            "agent.c",
            "auth.c",
            "base64.c",
            "bignum.c",
            "buffer.c",
            "callbacks.c",
            "channels.c",
            "client.c",
            "config.c",
            "connect.c",
            "connector.c",
            "crypto_common.c",
            "curve25519.c",
            "dh.c",
            "ecdh.c",
            "error.c",
            "getpass.c",
            "init.c",
            "kdf.c",
            "kex.c",
            "known_hosts.c",
            "knownhosts.c",
            "legacy.c",
            "log.c",
            "match.c",
            "messages.c",
            "misc.c",
            "options.c",
            "packet.c",
            "packet_cb.c",
            "packet_crypt.c",
            "pcap.c",
            "pki.c",
            "pki_container_openssh.c",
            "poll.c",
            "session.c",
            "scp.c",
            "socket.c",
            "string.c",
            "threads.c",
            "ttyopts.c",
            "wrapper.c",
            "external/bcrypt_pbkdf.c",
            "external/blowfish.c",
            "config_parser.c",
            "token.c",
            "pki_ed25519_common.c",
        },
        .flags = flags,
    });

    // threads
    mod.addCSourceFile(.{
        .file = try src.join(b.allocator, "threads/noop.c"),
        .flags = flags,
    });
    if (getThreadsLib(mod.resolved_target.?.result)) |threads| mod.addCSourceFile(.{
        .file = switch (threads) {
            .pthreads => try src.join(b.allocator, "threads/pthread.c"),
            .win32 => try src.join(b.allocator, "threads/winlocks.c"),
        },
        .flags = flags,
    });
}
