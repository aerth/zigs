// library_tester command: test shared library hash result
//
// Usage:
//     printf hello | ./library_tester libzigs.so fasthash -

const std = @import("std");
const native_endian = @import("builtin").cpu.arch.endian();

// the dynlib symbol function signature
const HashFn = *const fn (buf: [*]const u8, n: usize, out: [*]u8) c_int;

pub fn main() !void {
    // get args
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const args = try std.process.argsAlloc(gpa.allocator());
    defer std.process.argsFree(gpa.allocator(), args);

    // dynamic load library (arg1)
    if (args.len < 4) {
        std.log.err("not enough args\nUsage:\t{s} libzigs.so fasthash -", .{args[0]});
        std.process.exit(2);
    }
    const dynlib_name = args[1];
    var lib = try std.DynLib.open(dynlib_name);
    defer lib.close();

    // lookup symbol (arg2)
    const hashFn = lib.lookup(HashFn, args[2]) orelse return error.SymbolNotFound;

    // hash input (arg3)
    var input_raw: [*c]const u8 = args[3];
    var inputlen = args[3].len;
    var input: [*]const u8 = input_raw;
    if (args[3].len == 1 and args[3][0] == '-') {
        // read stdin
        const in = std.io.getStdIn();
        var buffered = std.io.bufferedReader(in.reader());
        var r = buffered.reader();
        var buf: [4096]u8 = undefined;
        var msg = try r.readUntilDelimiterOrEof(&buf, '\n');
        inputlen = msg.?.len;
        if (inputlen == 4096) {
            return error.toobig;
        }
        if (msg) |m| {
            input = @constCast(m.ptr);
        } else {
            return error.wtf;
        }
    }
    var digest: [32]u8 = undefined;
    const result = hashFn(input, inputlen, &digest);
    std.debug.assert(result == 0);

    //   const n: u256 = std.mem.readInt(u256, &digest, .big);
    try std.io.getStdOut().writer().print("{s}\n", .{std.fmt.bytesToHex(digest, .lower)});
}
