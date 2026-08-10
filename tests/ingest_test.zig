const std = @import("std");
const ingest = @import("ingest");
const comparable = @import("comparable");
const geometry = @import("geometry");
const operations = @import("operations");
const model = @import("model");

comptime {
    _ = geometry;
    _ = operations;
    _ = model;
}

test "CSV parser preserves comparable fields" {
    var property: ingest.Property = .{};
    const line = "1,000000000001,1 MAIN ST,CITY,MN,55000,01,,1a RESIDENTIAL SINGLE UNIT,Two Story,Y,,2026.0,400000.0,100000.0,300000.0,,5000.0,,2000.0,,4.0,2.0,2.0,Y,,1990.0,,0.25,0.25,N01,123-,,,";
    try std.testing.expect(ingest.parseRecordForTest(line, &property));
    try std.testing.expectEqualStrings("000000000001", property.parcelId());
    try std.testing.expectEqual(@as(i32, 2026), property.tax_year);
    try std.testing.expectEqual(@as(f64, 400000), property.market_value);
}

test "comparable model excludes different levy context" {
    var subject: ingest.Property = .{};
    var candidate: ingest.Property = .{};
    subject.levy_code_len = 4;
    @memcpy(subject.levy_code[0..4], "123-");
    candidate.levy_code_len = 4;
    @memcpy(candidate.levy_code[0..4], "999-");
    try std.testing.expect(!comparable.eligible(&subject, &candidate));
}
