const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    var fixed_buffer_mem: [10 * 1024]u8 = undefined;
    var fixed_buf_alloc = std.heap.FixedBufferAllocator.init(fixed_buffer_mem[0..]);
    const allocator = fixed_buf_alloc.allocator();

    // args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    for (args, 0..) |arg, i| {
        std.log.debug("{d}: {s}", .{ i, arg });
        if (arg[0] == '-') {
            std.log.err("bad cmdline flag (try builtin, types, keywords, style or type any stdlib package (crypto.pwhash)", .{});
            std.process.exit(1);
        }
    }

    // some shortcuts
    if (args.len > 1 and std.mem.startsWith(u8, args[1], "-")) {
        try open_desktop_browser(allocator, "https://ziglang.org/documentation/master/#Builtin-Functions");
        return;
    }
    if (args.len < 2 or std.mem.startsWith(u8, args[1], "builtin")) {
        try open_desktop_browser(allocator, "https://ziglang.org/documentation/master/#Builtin-Functions");
        return;
    }
    if (std.mem.startsWith(u8, args[1], "types")) {
        try open_desktop_browser(allocator, "https://ziglang.org/documentation/master/#Primitive-Types");
        return;
    }
    if (std.mem.startsWith(u8, args[1], "keyw")) {
        try open_desktop_browser(allocator, "https://ziglang.org/documentation/master/#Keyword-Reference");
        return;
    }
    if (std.mem.startsWith(u8, args[1], "style")) {
        try open_desktop_browser(allocator, "https://ziglang.org/documentation/master/#Examples");
        return;
    }
    if (std.mem.startsWith(u8, args[1], "oper")) {
        try open_desktop_browser(allocator, "https://ziglang.org/documentation/master/#Operators");
        return;
    }

    // otherwise concat (urlprefix + arg1 to check a stdlib module)
    var buffer: [1024]u8 = undefined;
    const urlprefix = "https://ziglang.org/documentation/master/std/#A;std:";
    const url = try std.fmt.bufPrint(&buffer, "{s}{s}", .{ urlprefix, args[1] });
    try open_desktop_browser(allocator, url);
}

pub fn open_desktop_browser(allocator: std.mem.Allocator, url: []const u8) !void {
    const argv = switch (builtin.os.tag) { // thanks sinon
        .linux => &.{ "xdg-open", url },
        .macos => &.{ "open", url },
        .windows => &.{ "rundll32", "url.dll,FileProtocolHandler", url },
        else => @panic("cannot open url on os"),
    };

    var pc1 = std.process.Child.init(argv, allocator);
    try pc1.spawn();
    std.debug.print("child process {}\n", .{pc1.id});
    const out = try pc1.wait();
    std.debug.print("pid {} exit code: {}\n", .{ pc1.id, out });
}
