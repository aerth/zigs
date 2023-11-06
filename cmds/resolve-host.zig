// resolve-host command - resolve domain name, print first ipv4 to stdout (with no port number)

const std = @import("std");
const networking = @import("zigs").networking;
const process = std.process;
const net = std.net;
const io = std.io;
const log = std.log;

//var fixed_buffer_mem: [1 * 1024 * 1024]u8 = undefined; // 1 M
var fixed_buffer_mem: [10 * 1024]u8 = undefined; // 4K as low as i can go, 10k safer

pub fn main() !void {
    var fixed_buf_alloc = std.heap.FixedBufferAllocator.init(fixed_buffer_mem[0..]);
    var allocator = fixed_buf_alloc.allocator();
    //   const allocator = std.heap.page_allocator;
    const stdout = (io.getStdOut()).writer();
    const args = try process.argsAlloc(allocator);
    if (args.len < 2 or args[1][0] == '-') {
        process.argsFree(allocator, args);
        fatal("missing argument (hostname to resolve)", .{});
    }
    const hostname = args[1];
    const addr: net.Address = networking.resolveHost(allocator, hostname, 0) catch |err| {
        //fatal("could not resolve host: {}", .{err}); // this has extra prefix 'error.'
        fatal("could not resolve host: {s}", .{@errorName(err)});
    };
    process.argsFree(allocator, args); //move up one line to segfault

    // var buffer: [1024:0]u8 = undefined;
    var buffer = @as([]u8, fixed_buffer_mem[0..]);
    const host: [*:0]u8 = try networking.splitHostAddr(addr, buffer); // and.. right back to a string
    try std.fmt.format(stdout, "{s}\n", .{host}); // output to stdout
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    log.err(format, args);
    process.exit(1);
}
