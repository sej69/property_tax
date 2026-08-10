const ingest = @import("ingest");

/// The application only depends on this small provider surface. The production
/// implementation is the PolymorphDB adapter; the in-memory store is the
/// deterministic fixture/provider used by imports and tests.
pub const Provider = struct {
    store: *const ingest.Store,

    pub fn init(store: *const ingest.Store) Provider { return .{ .store = store }; }

    pub fn byParcelId(self: Provider, parcel_id: []const u8, year: ?i32) ?*const ingest.Property {
        for (self.store.records.items) |*property| {
            if (std.mem.eql(u8, property.parcelId(), parcel_id) and (year == null or property.tax_year == year.?)) return property;
        }
        return null;
    }

    pub fn firstAddressMatch(self: Provider, query: []const u8, year: ?i32) ?*const ingest.Property {
        for (self.store.records.items) |*property| {
            if (year != null and property.tax_year != year.?) continue;
            if (std.ascii.indexOfIgnoreCase(property.addressText(), query) != null) return property;
        }
        return null;
    }
};

const std = @import("std");
