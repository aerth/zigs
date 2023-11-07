const std = @import("std");
const cryptos = @import("zigs").cryptos;
const argon2 = cryptos.argon2;
const c = @cImport({
    @cDefine("FOO", "1");
    @cInclude("stdio.h");
});

var allocator: ?std.mem.Allocator = null;
fn initallocator() void {
    if (allocator == null) {
        allocator = std.heap.c_allocator;
    }
}

// slowhash exposes argon2id(8,1024,3) hash (with no salt)
export fn slowhash(buf: [*]const u8, n: usize, out: [*]u8) c_int {
    initallocator();
    const salt: [0]u8 = undefined; // zero len salt
    var input: []const u8 = buf[0..n];
    argon2.kdf(allocator.?, out[0..32], input, &salt, //
        cryptos.params.slowhash, .argon2id) catch |err| {
        std.log.err("{}", .{err});
        return -12;
    };
    return 0;
}
// okayhash exposes argon2id(8,1024,3) hash (with no salt)
export fn okayhash(buf: [*]const u8, n: usize, out: [*]u8) c_int {
    initallocator();
    const salt: [0]u8 = undefined; // zero len salt
    var input: []const u8 = buf[0..n];
    argon2.kdf(allocator.?, out[0..32], input, &salt, //
        cryptos.params.okayhash, .argon2id) catch |err| {
        std.log.err("{}", .{err});
        return -12;
    };
    return 0;
}

// fasthash exposes argon2id(1,1,1) hash (with no salt)
export fn fasthash(buf: [*]const u8, n: usize, out: [*]u8) c_int {
    initallocator();
    const salt: [0]u8 = undefined; // zero len salt
    const input: []const u8 = buf[0..n];
    //    const allocator = std.heap.c_allocator;
    argon2.kdf(allocator.?, out[0..32], input, &salt, //
        cryptos.params.fasthash, .argon2id) catch |err| {
        std.log.err("{}", .{err});
        return -12;
    };
    return 0;
}
test {
    std.testing.refAllDecls(@This());
}
