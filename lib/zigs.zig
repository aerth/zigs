pub const version = "0.0.1";
pub const networking = @import("./networking.zig");
pub const cryptos = @import("./cryptos.zig");

test "awooa" {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
