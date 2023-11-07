// test http timeout

const std = @import("std");
const zigs = @import("zigs.zig");

const print = std.debug.print;
//const test_website = "http://httpbin.org/post";
const test_website = "http://httpbin.org/delay/2.5";
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    //const website = "http://127.0.0.1:8080";
    comptime var i: u32 = 1;
    inline while (i < 4) : (i += 1) {
        runit(allocator, test_website, i) catch |err| {
            print("found err {}\n", .{err});
        };
    }
}
pub fn runit(allocator: std.mem.Allocator, website: []const u8, timeout: u32) !void {
    const addr = try std.Uri.parse(website);
    std.log.info("connecting: addr={} timeout={d} seconds", .{ addr, timeout });
    try http_post(allocator, addr, timeout);
}

test "main" {
    //const website = "http://127.0.0.1:8080";
    try runit(std.testing.allocator, test_website, 4);
}

const net = std.net;
const HttpClient = @import("HttpClient.zig");
const networking = @import("networking.zig");

pub fn http_post(allocator: std.mem.Allocator, uri: std.Uri, timeout: u32) !void {
    var client: HttpClient = .{ .allocator = allocator, .timeout = timeout };
    defer client.deinit();

    var headers = std.http.Headers.init(allocator);
    defer headers.deinit();
    try headers.append("Content-Type", "application/json");
    try headers.append("Content-Length", "2"); // todo json content-len
    try headers.append("user-agent", "zigs/1.0");
    try client.loadDefaultProxies();
    var options = HttpClient.RequestOptions{};
    var request: HttpClient.Request = try client.open(.POST, uri, headers, options);
    defer request.deinit();
    try request.send(.{});
    try request.writeAll("{}");
    try request.finish();
    try request.wait();
    std.debug.print("status={any}\n", .{request.response.status});
    std.debug.print("headers={any}\n", .{request.response.headers});
    std.debug.print("contentlen={any}\n", .{request.response.content_length});
    request.reader().streamUntilDelimiter(std.io.getStdOut().writer(), '\x00', null) catch |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    };
}
