const std = @import("std");
const Builder = std.build.Builder;
const Pkg = std.build.Pkg;

pub fn build(b: *Builder) void {
    var release_buf: [64]u8 = undefined;
    const slice = (std.fs.cwd().openDir(b.build_root, .{}) catch unreachable)
        .readFile("RELEASE", &release_buf) catch @panic("Couldn't read RELEASE");
    const release = std.mem.trim(u8, slice, "\n");

    const dist: []const u8 = blk: {
        var ret: u8 = undefined;
        const output = b.execAllowFail(
            &[_][]const u8{ "git", "-C", b.build_root, "rev-parse", "HEAD" },
            &ret,
            .Inherit,
        ) catch break :blk "UNKNOWN";
        break :blk output[0..7];
    };

    const options = b.addOptions();
    options.addOption([]const u8, "release", release);
    options.addOption([]const u8, "dist", dist);

    const opt_tun_gif = b.option(bool, "tunneler-gif", "Link GIFLIB and use to export a GIF of the tunneler mapgen") orelse false;
    options.addOption(bool, "tunneler_gif", opt_tun_gif);

    const opt_use_sdl = b.option(bool, "use-sdl", "Build a graphical tiles version of Oathbreaker") orelse false;
    options.addOption(bool, "use_sdl", opt_use_sdl);

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const is_windows = target.os_tag != null and target.os_tag.? == .windows;

    const exe = b.addExecutable("rl", "src/main.zig");
    exe.linkLibC();
    exe.addPackagePath("rexpaint", "third_party/zig-rexpaint/lib.zig");

    exe.addIncludeDir("third_party/janet/"); // janet.h
    exe.addCSourceFile("third_party/janet/janet.c", &[_][]const u8{"-std=c99"});

    if (opt_tun_gif) {
        exe.linkSystemLibrary("gif");
    }

    if (is_windows) {
        exe.addIncludeDir("third_party/mingw/zlib/include/");
        exe.addObjectFile("third_party/mingw/zlib/lib/libz.dll.a");
        b.installBinFile("third_party/mingw/zlib/bin/zlib1.dll", "zlib1.dll");

        exe.addIncludeDir("third_party/mingw/libpng/include/libpng16/");
        exe.addObjectFile("third_party/mingw/libpng/lib/libpng.dll.a");
        b.installBinFile("third_party/mingw/libpng/bin/libpng16-16.dll", "libpng16-16.dll");
    } else {
        exe.linkSystemLibrary("z");
        exe.linkSystemLibrary("png");
    }

    if (!opt_use_sdl) {
        const termbox_sources = [_][]const u8{
            "third_party/termbox/src/input.c",
            "third_party/termbox/src/memstream.c",
            "third_party/termbox/src/ringbuffer.c",
            "third_party/termbox/src/termbox.c",
            "third_party/termbox/src/term.c",
            "third_party/termbox/src/utf8.c",
        };

        const termbox_cflags = [_][]const u8{
            "-std=c99",
            "-Wpedantic",
            "-Wall",
            //"-Werror", // Disabled to keep clang from tantruming about unused
            //              function results in memstream.c
            "-g",
            "-I./third_party/termbox/src",
            "-D_POSIX_C_SOURCE=200809L",
            "-D_XOPEN_SOURCE",
            "-D_DARWIN_C_SOURCE", // Needed for macOS and SIGWINCH def
        };

        for (termbox_sources) |termbox_source|
            exe.addCSourceFile(termbox_source, &termbox_cflags);
    } else {
        if (is_windows) {
            exe.addIncludeDir("third_party/mingw/SDL2/include/SDL2/");
            exe.addObjectFile("third_party/mingw/SDL2/lib/libSDL2.dll.a");
            b.installBinFile("third_party/mingw/SDL2/bin/SDL2.dll", "SDL2.dll");
        } else {
            exe.linkSystemLibrary("sdl2");
        }
    }

    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.addOptions("build_options", options);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run the roguelike");
    run_step.dependOn(&run_cmd.step);

    var tests = b.addTest("tests/tests.zig");
    tests.setBuildMode(mode);
    tests.addPackagePath("src", "src/test.zig");
    const tests_step = b.step("tests", "Run the various tests");
    //tests_step.dependOn(&exe.step);
    tests_step.dependOn(&tests.step);
}
