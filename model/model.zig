const std = @import("std");
const ingest = @import("ingest");

pub const Prediction = struct { predicted_rate: f64, actual_rate: f64, residual: f64, sample_size: usize };

/// Phase-two independent baseline. It does not reuse the comparable engine’s
/// candidate set or tax-rate score; it estimates a robust context baseline from
/// the annual county observations and reports a residual for review.
pub fn predict(subject: *const ingest.Property, records: []const ingest.Property, scratch: []f64) Prediction {
    var count: usize = 0;
    for (records) |*record| {
        if (record.tax_year != subject.tax_year or record.market_value <= 0) continue;
        if (subject.classText().len > 0 and record.classText().len > 0 and !std.mem.eql(u8, subject.classText(), record.classText())) continue;
        scratch[count] = record.total_tax / record.market_value * 100.0;
        count += 1;
        if (count == scratch.len) break;
    }
    if (count == 0) return .{ .actual_rate = actual(subject), .predicted_rate = 0, .residual = actual(subject), .sample_size = 0 };
    std.sort.insertion(f64, scratch[0..count], {}, comptime std.sort.asc(f64));
    const predicted = scratch[count / 2];
    return .{ .actual_rate = actual(subject), .predicted_rate = predicted, .residual = actual(subject) - predicted, .sample_size = count };
}

fn actual(property: *const ingest.Property) f64 { return if (property.market_value <= 0) 0 else property.total_tax / property.market_value * 100.0; }

test "statistical residual is actual minus robust baseline" {
    var subject: ingest.Property = .{};
    subject.tax_year = 2026;
    subject.market_value = 100000;
    subject.total_tax = 2000;
    subject.property_class_len = 1;
    subject.property_class[0] = 'A';
    var records: [2]ingest.Property = .{ subject, subject };
    records[0].total_tax = 1000;
    records[1].total_tax = 1500;
    var scratch: [4]f64 = undefined;
    const prediction = predict(&subject, &records, &scratch);
    try std.testing.expect(prediction.sample_size == 2);
    try std.testing.expect(prediction.residual > 0);
}
