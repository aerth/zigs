const std = @import("std");
const builtin = @import("builtin");
const networking = @import("networking.zig");
const log = std.log;
const expect = std.testing.expect;
const fmt = std.fmt;
const http = std.http;
const net = std.net;
const xx = std.fmt.fmtSliceHexLower;
const disable_tls = std.options.http_disable_tls;

const socks = @import("socks.zig");
const debuglog = std.debug.print;

pub const TcpConnectToAddressError = std.os.SocketError || std.os.ConnectError;

//const T = struct { privateKey: [:0]u8, messageHash: [:0]u8 };
pub fn run(
    http_client: *std.http.Client,
    uri_input: std.Uri,
    //json_input: [:0]const u8,
    h: *std.http.Headers,
) !void {
    // const host = "httpbin.org";
    //   const port = 443;
    var uri = uri_input;
    debuglog("resolving host {s}", .{uri.host.?});
    if (uri.port == null) {
        uri.port = 80;
        if (uri.scheme.len > 0 and std.mem.startsWith(u8, uri.scheme, "https")) {
            uri.port = 443;
        }
    }
    const allocator = http_client.allocator;
    const addr = try networking.resolveHost(allocator, uri.host.?, 80); // dns, port used later

    //   const conn = try tcpConnectToAddress(addr);
    const proxy_addr = try std.net.Address.resolveIp("127.0.0.1", 1080);
    const conn = try socks.Socksv5.connectAddress(proxy_addr, null, addr);
    //o
    //
    //
    //var tls_client = try std.crypto.tls.Client.init(conn, bundle, uri.host.?);

    var bundle = std.crypto.Certificate.Bundle{};
    try bundle.rescan(allocator);
    defer bundle.deinit(allocator);

    const proto = std.http.Client.protocol_map.get(uri.scheme) orelse .plain;
    var httpconnection: http.Client.Connection = .{
        .stream = conn,
        //      .tls_client = &tls_client,
        .tls_client = undefined,
        .host = @constCast(uri.host),
        .port = (uri.port) orelse if (proto == .plain) 80 else 443,
        .protocol = proto,
    };

    var opts: std.http.Client.RequestOptions = .{
        .connection = &httpconnection,
    };
    var req = try http_client.open(.GET, uri, h.*, opts);
    defer req.deinit();
    try req.send(.{});
    log.debug("sent request", .{});

    if (true) {
        return;
    }
    try req.wait(); // cool
    const body = try req.reader().readAllAlloc(allocator, 8192);
    defer allocator.free(body);
    const ct = req.response.headers.getFirstValue("content-type") orelse "??";
    //   const origin = req.response.headers.getFirstValue("origin") orelse "??";
    log.debug("json in ({s}): {s}\n", .{ ct, body });
    //try std.debug.expect(std.mem.eql(u8, got, "https://httpbin.org/get"));

}

pub const JsonClient = struct {
    http_client: *std.http.Client,
    headers: *std.http.Headers,
    uri: *std.Uri,
    pub fn jsonPost(self: *JsonClient, method: []u8, paramsJsonString: []u8, outputBuffer: std.io.Stream) !void {
        var req = try self.http_client.open(.POST, self.uri, self.headers, .{});
        defer req.deinit();

        req.transfer_encoding = .{ .content_length = 14 };

        try req.send(.{});
        try req.writeAll(
            \\
            \\ { "method": "test", "params": [1,2,3,4]}
            \\
        );
        try req.finish();
        try req.wait(); // cool
        //
        //

        _ = paramsJsonString;
        _ = method;
        _ = outputBuffer;
    }
};

test "httpbin" {
    //   const allocator = std.heap.page_allocator;
    const allocator = std.testing.allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    for (args, 0..) |arg, i| {
        log.debug("{d}: {s}", .{ i, arg });
        if (arg[0] == '-') {
            log.err("bad cmdline flag", .{});
            std.process.exit(1);
        }
    }
    var http_client: std.http.Client = .{ .allocator = allocator };
    const uri: std.Uri = try std.Uri.parse("http://httpbin.org/get");
    var h = std.http.Headers.init(allocator);
    defer h.deinit();
    defer http_client.deinit();
    run(&http_client, uri, &h) catch |err| {
        log.err("fatal: {}", .{err});
    };
}

test "httpbin jsonrpc" {
    const allocator = std.testing.allocator;
    var http_client = std.http.Client{ .allocator = allocator };
    const uri: std.Uri = try std.Uri.parse("http://httpbin.org/get");
    var h = std.http.Headers.init(allocator);
    defer h.deinit();
    run(&http_client, uri, &h) catch |err| {
        return err;
    };
}
