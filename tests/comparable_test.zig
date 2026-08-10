const std = @import("std");
const ingest = @import("ingest");
const comparable = @import("comparable");

test "effective rate is tax divided by market value" {
    var p: ingest.Property = .{};
    p.total_tax = 1420;
    p.market_value = 100000;
    try std.testing.expectApproxEqAbs(@as(f64, 1.42), comparable.effectiveRate(&p), 0.0001);
}
