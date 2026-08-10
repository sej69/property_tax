const std = @import("std");

pub const ImportManifest = struct {
    source_path: []const u8,
    tax_year: i32,
    record_count: usize,
    rejected_count: usize,
    immutable: bool = true,
};

pub fn isPublishedReadOnly() bool { return true; }
pub fn acceptsUploads() bool { return false; }

test "public operations do not accept uploads" { try std.testing.expect(!acceptsUploads()); }
