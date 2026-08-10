const std = @import("std");
const geometry = @import("geometry");

pub const CachePolicy = struct {
    max_age_seconds: i64 = 7 * 24 * 60 * 60,
    upstream_host: []const u8 = "tile.openstreetmap.org",
    coverage: geometry.TileCoverage,

    pub fn allows(self: CachePolicy, z: u8, x: u32, y: u32) bool { return self.coverage.allows(z, x, y); }
    pub fn cachePath(self: CachePolicy, allocator: std.mem.Allocator, z: u8, x: u32, y: u32) ![]u8 { return std.fmt.allocPrint(allocator, "{s}/{d}/{d}/{d}.tile", .{ self.upstream_host, z, x, y }); }
};

test "tile policy is seven days and coverage gated" {
    var policy = CachePolicy{ .coverage = .{ .csv_backed_count = 1 } };
    try std.testing.expectEqual(@as(i64, 604800), policy.max_age_seconds);
    try std.testing.expect(!policy.allows(0, 0, 0));
}
