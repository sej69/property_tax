const comparable = @import("comparable");
const ingest = @import("ingest");

pub const Ranked = struct { property: *const ingest.Property, rate: f64 };

pub fn effectiveRate(property: *const ingest.Property) f64 { return comparable.effectiveRate(property); }

pub fn percentile(subject: *const ingest.Property, records: []const ingest.Property, allocator: std.mem.Allocator) !f64 {
    var values = std.array_list.Managed(f64).init(allocator);
    defer values.deinit();
    for (records) |*property| {
        if (property.tax_year != subject.tax_year) continue;
        try values.append(effectiveRate(property));
    }
    if (values.items.len == 0) return 0;
    std.sort.insertion(f64, values.items, {}, comptime std.sort.asc(f64));
    const rank = @min(values.items.len - 1, values.items.len * 95 / 100);
    return values.items[rank];
}

const std = @import("std");
