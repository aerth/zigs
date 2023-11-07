const std = @import("std");
const builtin = @import("builtin"); // for cpu
const testing = std.testing;
const os = std.os;
const net = std.net;
const native_arch = builtin.cpu.arch;
const mem = std.mem;
const native_endian = native_arch.endian(); // enum big or little

var default_timeout: u32 = 5; // 5 seconds (eg: not for downloadz)

pub fn setDefaultTimeout(seconds: u32) void {
    default_timeout = seconds;
}
pub fn getDefaultTimeout() u32 {
    return default_timeout;
}

/// resolveHost return first ipv4 found
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

/// splitHostAddr returns null terminated host string (without the port) TODO ipv6
pub fn splitHostAddr(addr: net.Address, buffer: anytype) ![*:0]u8 {
    const bytes: *const [4]u8 = @as(*const [4]u8, @ptrCast(&@as(*const os.sockaddr.in, @ptrCast(&addr)).addr));
    const host_str = try std.fmt.bufPrintZ(buffer, "{}.{}.{}.{}", .{ bytes[0], bytes[1], bytes[2], bytes[3] });
    return host_str;
}

/// splitHostAddrBytes casting
pub fn splitHostAddrBytes(addr: net.Address) *[4]u8 {
    return @as(*const [4]u8, @ptrCast(&@as(*const os.sockaddr.in, @ptrCast(&addr)).addr));
}

/// ip4tou32 uses mem.bigToNative
pub fn ip4tou32(ipaddr: net.Address) u32 {
    const dec: u32 = mem.bigToNative(u32, @as(*const os.sockaddr.in, @ptrCast(&ipaddr)).addr);
    return dec;
}

/// tcpConnectToAddress with default_timeout
pub fn tcpConnectToAddress(address: Address) !Stream {
    return tcpConnectToAddressT(address, default_timeout);
}
/// tcpConnectToHost with default_timeout
pub fn tcpConnectToHost(allocator: std.mem.Allocator, name: []const u8, port: u16) !Stream {
    return tcpConnectToHostT(allocator, name, port, default_timeout);
}
pub fn tcpConnectToHostT(allocator: std.mem.Allocator, name: []const u8, port: u16, timeout: u32) !Stream {
    const list = try std.net.getAddressList(allocator, name, port); // TODO resolve timeout
    defer list.deinit();

    if (list.addrs.len == 0) return error.UnknownHostName;

    for (list.addrs) |addr| {
        return tcpConnectToAddressT(addr, timeout) catch |err| switch (err) {
            error.ConnectionRefused => {
                continue;
            },
            else => return err,
        };
    }
    return std.os.ConnectError.ConnectionRefused;
}

///
/// set_stream_timeout  (seconds) if timeout is null, no timeout
pub fn set_stream_timeout(sockfd: i32, timeout: ?u32) !void {
    const timeo = std.os.timeval{
        .tv_sec = timeout orelse 0,
        .tv_usec = 0,
    };
    try std.os.setsockopt(sockfd, std.os.SOL.SOCKET, std.os.SO.RCVTIMEO, std.mem.asBytes(&timeo));
    try std.os.setsockopt(sockfd, std.os.SOL.SOCKET, std.os.SO.SNDTIMEO, std.mem.asBytes(&timeo));
}

/// tcpConnectToAddressT with custom timeout (in seconds)
pub fn tcpConnectToAddressT(address: Address, timeout: u32) !Stream {
    const nonblock = if (std.io.is_async) os.SOCK.NONBLOCK else 0;
    const sock_flags = os.SOCK.STREAM | nonblock |
        (if (builtin.target.os.tag == .windows) 0 else os.SOCK.CLOEXEC);
    const sockfd = try os.socket(address.any.family, sock_flags, os.IPPROTO.TCP);
    errdefer os.closeSocket(sockfd);
    try set_stream_timeout(sockfd, timeout);
    if (std.io.is_async) {
        std.debug.print("is_async true\n", .{});
        const loop = std.event.Loop.instance orelse return error.ConnectionTimedOut;
        try loop.connect(sockfd, &address.any, address.getOsSockLen());
    } else {
        std.debug.print("is_async false\n", .{});
        os.connect(sockfd, &address.any, address.getOsSockLen()) catch |err| {
            std.debug.print("is_async false, got err {}\n", .{err});
            switch (err) {
                error.WouldBlock => return error.ConnectionTimedOut,
                error.Unexpected => return error.ConnectionTimedOut, // TODO
                else => |e| return e,
            }
            return err;
        };
    }
    return Stream{ .handle = sockfd };
}

test "resolve google.com 2" {
    var some_buffer: [128:0]u8 = undefined;
    const addr: net.Address = try resolveHost(testing.allocator, "google.com", 80);
    std.debug.print("\nhost resolved: {}\n", .{addr});
    const host: [*:0]u8 = try splitHostAddr(addr, &some_buffer);
    std.debug.print("host split:    {s}\n", .{host});
}
test "resolve ziglang.org" {
    // (NOT resolving dns. this is 'parsing an IP' into an ipv4/ipv6 + port)
    var ip = try net.Address.resolveIp("127.0.0.1", 80);
    // resolve dns, returns unknown number of ipv4/ipv6 combo
    const hostname = "ziglang.org";
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
//

const Address = net.Address;
const Stream = net.Stream;
