const std = @import("std");
const ingest = @import("ingest");

pub const Candidate = struct { property: *const ingest.Property, score: f64 };
pub const Result = struct { count: usize = 0, median_rate: f64 = 0, lower_rate: f64 = 0, upper_rate: f64 = 0, confidence: []const u8 = "low" };

pub fn effectiveRate(property: *const ingest.Property) f64 {
    if (property.market_value <= 0) return 0;
    return property.total_tax / property.market_value * 100.0;
}

pub fn eligible(subject: *const ingest.Property, candidate: *const ingest.Property) bool {
    if (std.mem.eql(u8, subject.parcelId(), candidate.parcelId())) return false;
    if (!sameOrBlank(subject.levyCodeText(), candidate.levyCodeText())) return false;
    if (!sameOrBlank(subject.classText(), candidate.classText())) return false;
    if (!sameOrBlank(subject.homesteadText(), candidate.homesteadText())) return false;
    if (subject.neighborhoodText().len > 0 and candidate.neighborhoodText().len > 0 and !std.mem.eql(u8, subject.neighborhoodText(), candidate.neighborhoodText())) return false;
    if (subject.living_sq_ft > 0 and candidate.living_sq_ft > 0 and relativeDifference(subject.living_sq_ft, candidate.living_sq_ft) > 0.20) return false;
    if (subject.market_value > 0 and candidate.market_value > 0 and relativeDifference(subject.market_value, candidate.market_value) > 0.25) return false;
    if (subject.year_built > 0 and candidate.year_built > 0 and @abs(subject.year_built - candidate.year_built) > 15) return false;
    if (subject.bedrooms > 0 and candidate.bedrooms > 0 and @abs(subject.bedrooms - candidate.bedrooms) > 1) return false;
    if (subject.bathrooms > 0 and candidate.bathrooms > 0 and @abs(subject.bathrooms - candidate.bathrooms) > 1) return false;
    return true;
}

pub fn similarity(subject: *const ingest.Property, candidate: *const ingest.Property) f64 {
    return 0.25 * normalizedDifference(subject.living_sq_ft, candidate.living_sq_ft, 1000) +
        0.20 * normalizedDifference(subject.market_value, candidate.market_value, 500000) +
        0.15 * normalizedDifference(subject.year_built, candidate.year_built, 50) +
        0.10 * normalizedDifference(subject.acres, candidate.acres, 5) +
        0.10 * normalizedDifference(subject.bedrooms, candidate.bedrooms, 3) +
        0.10 * normalizedDifference(subject.bathrooms, candidate.bathrooms, 2) +
        0.10 * (if (subject.stories == candidate.stories) @as(f64, 0) else @as(f64, 1));
}

pub fn find(subject: *const ingest.Property, records: []const ingest.Property, output: []Candidate) Result {
    var count: usize = 0;
    for (records) |*candidate| {
        if (!eligible(subject, candidate)) continue;
        const item = Candidate{ .property = candidate, .score = similarity(subject, candidate) };
        if (count < output.len) {
            output[count] = item;
            count += 1;
        } else {
            var worst: usize = 0;
            for (output[1..], 1..) |other, index| {
                if (other.score > output[worst].score) worst = index;
            }
            if (item.score < output[worst].score) output[worst] = item;
        }
    }
    sortCandidates(output[0..count]);
    var rates: [32]f64 = undefined;
    const rate_count = @min(count, rates.len);
    for (output[0..rate_count], 0..) |candidate, index| rates[index] = effectiveRate(candidate.property);
    std.sort.insertion(f64, rates[0..rate_count], {}, comptime std.sort.asc(f64));
    const result_count = rate_count;
    return .{
        .count = result_count,
        .median_rate = if (result_count == 0) 0 else rates[result_count / 2],
        .lower_rate = if (result_count == 0) 0 else rates[result_count / 4],
        .upper_rate = if (result_count == 0) 0 else rates[(result_count * 3) / 4],
        .confidence = if (result_count >= 15) "high" else if (result_count >= 5) "medium" else "low",
    };
}

fn sortCandidates(items: []Candidate) void {
    std.sort.block(Candidate, items, {}, struct { fn lessThan(_: void, a: Candidate, b: Candidate) bool { return a.score < b.score; } }.lessThan);
}
fn sameOrBlank(a: []const u8, b: []const u8) bool { return a.len == 0 or b.len == 0 or std.mem.eql(u8, a, b); }
fn relativeDifference(a: f64, b: f64) f64 { const scale = @max(@abs(a), @abs(b)); return if (scale == 0) 0 else @abs(a - b) / scale; }
fn normalizedDifference(a: f64, b: f64, scale: f64) f64 { return @min(1.0, @abs(a - b) / scale); }
