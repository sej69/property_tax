const std = @import("std");
const geometry = @import("geometry");

test "tile coverage rejects empty CSV coverage" {
    const coverage = geometry.TileCoverage{};
    try std.testing.expect(!coverage.allows(10, 0, 0));
}
