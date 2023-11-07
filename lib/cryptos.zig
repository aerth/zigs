const std = @import("std");
const debuglog = std.log.debug;

pub const argon2 = @import("aquahash.zig");
pub const secureZero = std.crypto.utils;
pub const HashParams = argon2.Params; // modified for zero-length salt
pub const Known = struct {
    pub const V: u8 = 7;
    pub const X: u256 = 0xebc4b08a96e4b2437bdbaa33394b7ab2d3d228474b6a7bae35b2c8630c9172ff;
    pub const Z: u256 = 0xa4097a0b50d96e01f8c152aaa0f83803959ea44c0520059b19604339ea579139;
    pub const dead_addr: [:0]u8 = "0x000000000000000000000000000000000000dead";
    pub const zero_addr: [:8]u8 = "0x0000000000000000000000000000000000000000";
    pub const one_u256: u256 = 0x0000000000000000000000000000000000000000000000000000000000000001;
    pub const max_u256: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    pub const maxuint256 = max_u256;
    //   pub const maxuint256: u256 = std.math.maxInt(u256);
};
pub fn print_hex(comptime T: type, buf: []T, prefix: []const u8) void {
    if (prefix.len != 0) {
        std.debug.print("{s}", .{prefix});
    }
    for (buf) |byte| {
        std.debug.print("{x}", .{byte});
    }
    std.debug.print("\n", .{});
}

const Error = error{ // inferred_error_sets
    Overflow,
};
pub const params = struct {
    pub const slowhash = HashParams{
        .t = 100,
        .m = 2048,
        .p = 3,
    };
    pub const okayhash = HashParams{
        .t = 50,
        .m = 2048,
        .p = 3,
    };
    pub const fasthash = HashParams{
        .t = 1,
        .m = 1,
        .p = 1,
    };
};

pub const native_endian = @import("builtin").target.cpu.arch.endian();
pub const is_le = native_endian == .little;
pub const is_be = native_endian == .big;

pub const bytesToHex = std.fmt.bytesToHex; // the way to do it
pub const hexToBytes = std.fmt.bytesToHex;

pub fn toHexBE(v: anytype, case: std.fmt.Case) [@sizeOf(@TypeOf(v)) * 2]u8 {
    return any2hex(v, .big, case);
}
pub fn toHexLE(v: anytype, case: std.fmt.Case) [@sizeOf(@TypeOf(v)) * 2]u8 {
    return any2hex(v, .little, case);
}
pub fn any2hex(v: anytype, endianness: std.builtin.Endian, case: std.fmt.Case) [@sizeOf(@TypeOf(v)) * 2]u8 {
    return bytesToHex(std.mem.asBytes(&std.mem.nativeTo(@TypeOf(v), v, endianness)), case);
}
pub fn any2bytes(v: anytype) [@sizeOf(v)]u8 {
    return std.mem.asBytes(v);
}

test "max uint256 in zig ⚡" {
    std.debug.print("\nmaxu256 = {s}", .{toHexBE(Known.max_u256, .upper)});
    std.debug.print("\noneu256 = {s}\n", .{toHexBE(Known.one_u256, .upper)});
}

test "print really big uint, 8000 bytes (64000 bits)" {
    if (true) {
        return error.SkipZigTest;
    }
    const bigbig = std.math.maxInt(u64000);
    std.debug.print("\nbigbig uint: {d}\n", .{bigbig});
}
test "max largest fast uints, u128, u256, u512, u1024, u2048, u4096 bits" {
    inline for (.{ u128, u256, u512, u1024, u2048, u4096 }) |Int| {
        //// integer sizes over 8192 adds compilation time for me
        //inline for (.{ u128, u256, u512, u1024, u2048, u4096, u8192 }) |Int| {
        var bigbig: Int = std.math.maxInt(Int);
        std.debug.print("\nlargest {}: {d}\n", .{ Int, bigbig });
    }
}
test "max u256 and one in hex" {
    var buf: [32]u8 = undefined;
    std.crypto.utils.secureZero(u8, &buf);
    buf[31] = 1;
    const just_one = std.mem.readInt(u256, &buf, .big);
    std.debug.print("\n1 =       {s}", .{bytesToHex(buf, .upper)});
    @memcpy(&buf, std.mem.asBytes(&Known.max_u256));
    std.debug.print("\nmaxu256 = {s}\n", .{bytesToHex(buf, .upper)});
    std.debug.assert(just_one == 1);
    std.debug.assert(1 == Known.one_u256);
    std.debug.assert(std.mem.readInt(u256, &buf, .big) == Known.max_u256);
    // check each 32 byte is 0xFF
    std.debug.assert(std.mem.count(u8, &buf, &.{0xFF}) == 32);
}
