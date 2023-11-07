const std = @import("std");

const builtin = @import("builtin");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    var all_step = b.step("all", "Build all commands");
    // check minimum compiler version
    comptime {
        const current_zig = builtin.zig_version;
        const min_zig = std.SemanticVersion.parse("0.12.0-dev.64+b835fd90c") catch unreachable;
        if (current_zig.order(min_zig) == .lt) {
            @compileError(std.fmt.comptimePrint("Your Zig version v{} does not meet the minimum build requirement of v{}", .{ current_zig, min_zig }));
        }
    }

    // zig module so cmds can @import
    const zigsmod = b.addModule("zigs", .{
        .source_file = .{ .path = "lib/zigs.zig" },
        //       .dependencies = .{},
        //
    });
    // zig module so cmds can @import
    _ = b.addModule("zigsb", .{
        .source_file = .{ .path = "lib/latest.zig" },
        //       .dependencies = .{},
    });

    if (true) {
        const post_install_step = std.Build.Step.Run.create(b, b.fmt("reticulate splines", .{}));
        post_install_step.addArgs(&.{ "tree", b.install_prefix });
        post_install_step.step.dependOn(all_step);
        b.default_step = &post_install_step.step;
    }

    //
    //
    //
    // library exports (.a, .so, .h)
    //
    //
    //
    const sharedlib = b.addSharedLibrary(.{
        .name = "zigs", // creates libzigs.so.xxx
        .root_source_file = .{ .path = "libzigs/zigs_c.zig" }, // only exported fns to call from C
        .target = target,
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .optimize = optimize,
    });
    const staticlib = b.addStaticLibrary(.{
        .name = "zigs", // creates libzigs.a
        .root_source_file = .{ .path = "libzigs/zigs_c.zig" },
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .target = target,
        .optimize = optimize,
    });

    sharedlib.addModule("zigs", zigsmod);
    staticlib.addModule("zigs", zigsmod);

    const shared_step = b.step("shared", "build shared library");
    const lib_step = b.step("lib", "Build library (only)");

    staticlib.installHeader("zigs.h", "zigs.h");
    sharedlib.installHeader("zigs.h", "zigs.h");

    sharedlib.linkLibC();
    staticlib.linkLibC();

    shared_step.dependOn(&sharedlib.step);
    shared_step.dependOn(&b.addInstallArtifact(sharedlib, .{}).step);
    lib_step.dependOn(&staticlib.step);
    lib_step.dependOn(&b.addInstallArtifact(staticlib, .{}).step);

    b.installArtifact(sharedlib);
    b.installArtifact(staticlib);

    // add to all
    all_step.dependOn(b.getInstallStep());

    //
    //
    // example (and run) depends on install
    //
    //
    {
        const exe = b.addExecutable(.{
            .name = "resolve-host",
            .root_source_file = .{
                .path = "cmds/resolve-host.zig",
            },
            .target = target,
            .optimize = optimize,
        });
        exe.addModule("zigs", zigsmod);

        // link to the static library
        exe.linkLibrary(staticlib);

        const exe_install = b.addInstallArtifact(exe, .{});
        const exe_step = b.step("examplezig", "Build the example app ('resolve-host')");
        exe_step.dependOn(&exe_install.step);
        const run_cmd = b.addRunArtifact(exe);
        //   run_cmd.step.dependOn(b.getInstallStep()); // install shared and static library
        if (b.args) |args| {
            run_cmd.addArgs(args);
        } else {
            run_cmd.addArgs(&.{"ziglang.org"});
        }
        const run_step = b.step("run-resolve", "demo: zig build run-resolve -- localhost  (default ziglang.org)");
        run_step.dependOn(&run_cmd.step);
    }
    {
        const exe = b.addExecutable(.{
            .name = "jsonclient",
            .root_source_file = .{
                .path = "cmds/jsonclient.zig",
            },
            .target = target,
            .optimize = optimize,
        });
        exe.addModule("zigs", zigsmod);

        // link to the static library
        exe.linkLibrary(staticlib);

        const exe_install = b.addInstallArtifact(exe, .{});
        const exe_step = b.step("jsonclient", "Build the example app ('jsonclient')");
        exe_step.dependOn(&exe_install.step);
    }

    //
    //
    // testing
    //
    //

    {
        const unit_tests = b.addTest(.{
            .name = "tester",
            .root_source_file = .{ .path = "lib/zigs.zig" },
            .target = target,
            .optimize = optimize,
        });

        // run unit tests (not tester command)
        const run_unit_tests = b.addRunArtifact(unit_tests);
        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_unit_tests.step);

        // build unit tester app
        const tester_step = b.step("tester", "Build the unit tester (only)");
        const tester_install = b.addInstallArtifact(unit_tests, .{});
        tester_step.dependOn(&tester_install.step);

        // debug test step
        if (false) {
            const gdb_command = b.addSystemCommand(&[_][]const u8{"cgdb"});
            gdb_command.addArg("--args");
            gdb_command.addFileArg(unit_tests.getEmittedBin());
            //   gdb_command.addArgs(&.{ "--test-filter", "*" });
            gdb_command.step.dependOn(&unit_tests.step);
            const debug_test_step = b.step("debug_test", "Run gdb on tests");
            debug_test_step.dependOn(&gdb_command.step);
        }
    }

    // would be easier:
    //   b.post_install_step = b.addSystemCommand(&.{ "tree", b.install_prefix });
    //

    // not in order.. but one liner
    //`b.getInstallStep().dependOn(&b.addSystemCommand(&.{ "tree", b.install_prefix }).step);`
}
