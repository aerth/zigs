const std = @import("std");
const builtin = @import("builtin"); // for cpu
const testing = std.testing;
const os = std.os;
const net = std.net;
const native_arch = builtin.cpu.arch;
const mem = std.mem;
const native_endian = native_arch.endian(); // enum big or little

// resolveHost return first ipv4 found
pub fn resolveHost(allocator: std.mem.Allocator, hostname: []const u8, port: u16) !net.Address {
    const list = try net.getAddressList(allocator, hostname, port); // port is added each in list :(
    defer list.deinit(); // unallocate list memory
    for (list.addrs) |addr| {
        if (addr.any.family == os.AF.INET) {
            return addr;
        }
    }
    return error.NoneResolved;
}

// splitHostAddr returns null terminated host string (without the port) TODO ipv6
pub fn splitHostAddr(addr: net.Address, buffer: anytype) ![*:0]u8 {
    const bytes: *const [4]u8 = @as(*const [4]u8, @ptrCast(&@as(*const os.sockaddr.in, @ptrCast(&addr)).addr));
    const host_str = try std.fmt.bufPrintZ(buffer, "{}.{}.{}.{}", .{ bytes[0], bytes[1], bytes[2], bytes[3] });
    return host_str;
}

// splitHostAddrBytes casting
pub fn splitHostAddrBytes(addr: net.Address) *[4]u8 {
    return @as(*const [4]u8, @ptrCast(&@as(*const os.sockaddr.in, @ptrCast(&addr)).addr));
}

// ip4tou32 uses mem.bigToNative
pub fn ip4tou32(ipaddr: net.Address) u32 {
    const dec: u32 = mem.bigToNative(u32, @as(*const os.sockaddr.in, @ptrCast(&ipaddr)).addr);
    return dec;
}

test "resolve google.com 2" {
    var some_buffer: [128:0]u8 = undefined;
    const addr: net.Address = try resolveHost(testing.allocator, "google.com", 80);
    std.debug.print("\nhost resolved: {}\n", .{addr});
    const host: [*:0]u8 = try splitHostAddr(addr, &some_buffer);
    std.debug.print("host split:    {s}\n", .{host});
}
test "resolve google.com" {
    // (NOT resolving dns. this is 'parsing an IP' into an ipv4/ipv6 + port)
    var ip = try net.Address.resolveIp("127.0.0.1", 80);
    // resolve dns, returns unknown number of ipv4/ipv6 combo
    const hostname = "google.com";
    const list = try net.getAddressList(testing.allocator, hostname, 80); // port is added each in list :(
    defer list.deinit(); // unallocate list memory
    for (list.addrs) |addr| {
        if (addr.any.family == os.AF.INET) {
            ip = addr; // lets use first returned ipv4 for example
            break;
        }
    }
    std.debug.print("resolved done -> {}\n", .{ip});
}

test "split host port addr" {
    std.debug.print("\n", .{}); // left oneliners because nobody needs all 3 in the same scope ever
    var some_buffer: [128:0]u8 = undefined;

    // parse string to net.Address
    var ipaddr = try net.Address.resolveIp("127.0.0.1", 80);
    // split host out
    const host = try splitHostAddr(ipaddr, &some_buffer);

    std.debug.print("got host: {s}\n", .{host});
    try std.testing.expect(std.mem.eql(u8, "127.0.0.1", host[0..9]));
}
test "split host port address" {
    std.debug.print("\n", .{}); // left oneliners because nobody needs all 3 in the same scope ever
    var some_buffer: [128:0]u8 = undefined;

    // parse string to net.Address
    var ipaddr = try net.Address.resolveIp("127.0.0.1", 80);
    // might have to flip endian to get correct decimal output
    const dec: u32 = mem.bigToNative(u32, @as(*const os.sockaddr.in, @ptrCast(&ipaddr)).addr);
    // cast to 4 bytes (big endian as they are)
    const bytes: *const [4]u8 = @as(*const [4]u8, @ptrCast(&@as(*const os.sockaddr.in, @ptrCast(&ipaddr)).addr));
    // make a host ip string (null terminated here)
    const host_str = try std.fmt.bufPrintZ(&some_buffer, "{}.{}.{}.{}", .{ bytes[0], bytes[1], bytes[2], bytes[3] });

    for (bytes, 0..) |byte, u| {
        std.debug.print("byte {}: {}\n", .{ u, byte });
    }
    std.debug.print(
        \\
        \\split host:                         {s} 
        \\split host port: 127.0.01 as u32:   {d}
        \\this machine's native endianness:   {}
        \\had to flip to bigEndian for u32:   {}
        \\
    , .{ host_str, dec, native_endian, native_endian != std.builtin.Endian.big });
    std.debug.print("\ntry compare: https://www.silisoftware.com/tools/ipconverter.php?convert_from={d}\n", .{dec});
    try testing.expect(dec == 2130706433);
}

//
// hex= 0x7F000001    dec= 2130706433  dotdecimal= 127.0.0.1    octal= 0177.0000.0000.0001
//
//
