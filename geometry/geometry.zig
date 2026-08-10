const std = @import("std");

pub const Point = struct { latitude: f64, longitude: f64 };

/// Coverage is deliberately keyed by imported parcel IDs. Geometry acquisition
/// populates points later; this gate never authorizes a parcel absent from CSV.
pub const Coverage = struct {
    ids: std.StringHashMap(void),
    pub fn init(allocator: std.mem.Allocator) Coverage { return .{ .ids = .init(allocator) }; }
    pub fn deinit(self: *Coverage) void { self.ids.deinit(); }
    pub fn add(self: *Coverage, parcel_id: []const u8) !void { try self.ids.put(parcel_id, {}); }
    pub fn allows(self: *const Coverage, parcel_id: []const u8) bool { return self.ids.contains(parcel_id); }
};

pub const TileCoverage = struct {
    min_latitude: f64 = 45.0,
    max_latitude: f64 = 46.0,
    min_longitude: f64 = -94.0,
    max_longitude: f64 = -92.0,
    csv_backed_count: usize = 0,

    pub fn allows(self: TileCoverage, z: u8, x: u32, y: u32) bool {
        if (self.csv_backed_count == 0 or z > 22) return false;
        const n = @as(f64, @floatFromInt(@as(u64, 1) << @intCast(z)));
        const lon_left = @as(f64, @floatFromInt(x)) / n * 360.0 - 180.0;
        const lon_right = @as(f64, @floatFromInt(x + 1)) / n * 360.0 - 180.0;
        const lat_top = tileLatitude(@as(f64, @floatFromInt(y)), n);
        const lat_bottom = tileLatitude(@as(f64, @floatFromInt(y + 1)), n);
        return lon_right >= self.min_longitude and lon_left <= self.max_longitude and lat_top >= self.min_latitude and lat_bottom <= self.max_latitude;
    }
};

fn tileLatitude(y: f64, n: f64) f64 { return std.math.radiansToDegrees(std.math.atan(std.math.sinh(std.math.pi - 2.0 * std.math.pi * y / n))); }
