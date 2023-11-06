const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const all_step = b.step("all", "Build all commands");

    //   b.verbose = true;

    // c libraries exports
    const libsh = b.addSharedLibrary(.{
        .name = "zigs", // creates libzigs.a
        .root_source_file = .{ .path = "lib/zigs_c.zig" }, // only exported fns to call from C
        .target = target,
        .optimize = optimize,
        // .optimize = std.builtin.OptimizeMode.ReleaseFast, // TODO: how else to prevent weird getaddr
    });
    b.installArtifact(libsh);

    const lib = b.addStaticLibrary(.{
        .name = "zigs", // creates libzigs.a
        .root_source_file = .{ .path = "lib/zigs_c.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);
    const lib_step = b.step("lib", "Build library (only)");
    lib_step.dependOn(b.getInstallStep());
    all_step.dependOn(b.getInstallStep());

    // zig module so cmds can @import
    const zigsmod = b.addModule("zigs", .{
        .source_file = .{ .path = "lib/zigs.zig" },
        //       .dependencies = .{},
    });

    // test app
    const exe = b.addExecutable(.{
        .name = "resolve-host",
        .root_source_file = .{
            .path = "cmds/resolve-host.zig",
        },
        .target = target,
        .optimize = optimize,
    });

    // app needs module
    exe.addModule("zigs", zigsmod);

    // link to the static library
    exe.linkLibrary(lib);

    // example and run depends on install to prefix
    const exe_install = b.addInstallArtifact(exe, .{});
    const exe_step = b.step("examplezig", "Build the example app (only)");
    exe_step.dependOn(&exe_install.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the example app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .name = "tester",
        .root_source_file = .{ .path = "lib/zigs.zig" },
        .target = target,
        .optimize = optimize,
    });

    // test command for repeating tests
    const tester_install = b.addInstallArtifact(unit_tests, .{});
    const tester_step = b.step("tester", "Build the tester app (only)");
    tester_step.dependOn(&tester_install.step);
    //   b.installArtifact(unit_tests);
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // debug test step
    const gdb_command = b.addSystemCommand(&[_][]const u8{"cgdb"});
    gdb_command.addFileArg(unit_tests.getEmittedBin());
    gdb_command.step.dependOn(&unit_tests.step);
    const debug_test_step = b.step("debug_test", "Run gdb on tests");
    debug_test_step.dependOn(&gdb_command.step);
}
