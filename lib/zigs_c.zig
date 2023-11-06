const std = @import("std");

//
export fn clearChar(buf: [*:0]u8, n: usize, ch: u8) usize {
    for (0..n) |i| {
        if (buf[i] == 0) {
            return (n - 1);
        }
        buf[i] = ch;
    }
    return n;
}

const argon2 = std.crypto.pwhash.argon2;
const expect = std.testing.expect;
const eql = std.mem.eql;
const allocator = std.heap.page_allocator;
const pwhash = argon2.HashOptions{
    .allocator = allocator,
    .params = .{ .t = 2, .m = 1048, .p = 2 },
    .mode = argon2.Mode.argon2id,
};
const Hash = [32]u8;

// hash exposes a zig stdlib hash as a c library
export fn hash(buf: [*:0]const u8, n: usize, out: *[]u8) c_int {
    const salt: [8]u8 = undefined; // 8 zeroes (?)
    argon2.kdf(allocator, out.*, buf[0..n], &salt, pwhash.params, pwhash.mode) catch |err| {
        std.debug.print("err: {}", .{err});
        return -12;
    };
    return 0;
}
