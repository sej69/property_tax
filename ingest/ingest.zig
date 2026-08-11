const std = @import("std");

pub const Error = error{
    InvalidHeader,
    InvalidParcelId,
    DuplicateParcelId,
};

pub const Property = struct {
    parcel_id: [12]u8 = [_]u8{0} ** 12,
    parcel_id_len: u8 = 0,
    address: [96]u8 = [_]u8{0} ** 96,
    address_len: u8 = 0,
    city: [48]u8 = [_]u8{0} ** 48,
    city_len: u8 = 0,
    zip: [12]u8 = [_]u8{0} ** 12,
    zip_len: u8 = 0,
    property_class: [64]u8 = [_]u8{0} ** 64,
    property_class_len: u8 = 0,
    structure_type: [48]u8 = [_]u8{0} ** 48,
    structure_type_len: u8 = 0,
    homestead: [8]u8 = [_]u8{0} ** 8,
    homestead_len: u8 = 0,
    neighborhood: [32]u8 = [_]u8{0} ** 32,
    neighborhood_len: u8 = 0,
    levy_code: [16]u8 = [_]u8{0} ** 16,
    levy_code_len: u8 = 0,
    tax_year: i32 = 0,
    market_value: f64 = 0,
    land_value: f64 = 0,
    building_value: f64 = 0,
    total_tax: f64 = 0,
    living_sq_ft: f64 = 0,
    bedrooms: f64 = 0,
    bathrooms: f64 = 0,
    stories: f64 = 0,
    year_built: f64 = 0,
    acres: f64 = 0,
    deed_acres: f64 = 0,
    basement: bool = false,

    pub fn parcelId(self: *const Property) []const u8 { return self.parcel_id[0..self.parcel_id_len]; }
    pub fn addressText(self: *const Property) []const u8 { return self.address[0..self.address_len]; }
    pub fn cityText(self: *const Property) []const u8 { return self.city[0..self.city_len]; }
    pub fn zipText(self: *const Property) []const u8 { return self.zip[0..self.zip_len]; }
    pub fn classText(self: *const Property) []const u8 { return self.property_class[0..self.property_class_len]; }
    pub fn neighborhoodText(self: *const Property) []const u8 { return self.neighborhood[0..self.neighborhood_len]; }
    pub fn levyCodeText(self: *const Property) []const u8 { return self.levy_code[0..self.levy_code_len]; }
    pub fn homesteadText(self: *const Property) []const u8 { return self.homestead[0..self.homestead_len]; }
};

pub const Store = struct {
    allocator: std.mem.Allocator,
    records: std.array_list.Managed(Property),
    years: std.array_list.Managed(i32),
    parcel_year_keys: std.AutoHashMap(u64, void),
    source_rows: usize = 0,
    rejected_rows: usize = 0,

    pub fn init(allocator: std.mem.Allocator) Store {
        return .{ .allocator = allocator, .records = .init(allocator), .years = .init(allocator), .parcel_year_keys = .init(allocator) };
    }

    pub fn deinit(self: *Store) void {
        self.records.deinit();
        self.years.deinit();
        self.parcel_year_keys.deinit();
    }

    pub fn loadCsv(self: *Store, io: std.Io, path: []const u8) !void {
        const data = try std.Io.Dir.cwd().readFileAlloc(io, path, self.allocator, .limited(512 * 1024 * 1024));
        defer self.allocator.free(data);
        var lines = std.mem.splitScalar(u8, data, '\n');
        const header = std.mem.trimStart(u8, lines.next() orelse return Error.InvalidHeader, "\xEF\xBB\xBF");
        if (!std.mem.startsWith(u8, header, "OBJECTID,Parcel_ID,Address")) return Error.InvalidHeader;
        while (lines.next()) |raw| {
            const line = std.mem.trimEnd(u8, raw, "\r");
            if (line.len == 0) continue;
            self.source_rows += 1;
            var property: Property = .{};
            if (parseRecord(line, &property)) |record| {
                if (!validParcelId(record.parcelId())) { self.rejected_rows += 1; continue; }
                if (record.tax_year <= 0) { self.rejected_rows += 1; continue; }
                const key = parcelYearKey(record.parcelId(), record.tax_year) orelse { self.rejected_rows += 1; continue; };
                if (self.parcel_year_keys.contains(key)) {
                    self.rejected_rows += 1;
                    continue;
                }
                try self.parcel_year_keys.put(key, {});
                try self.records.append(record);
                if (!containsYear(self.years.items, record.tax_year)) try self.years.append(record.tax_year);
            } else self.rejected_rows += 1;
        }
    }

    pub fn containsParcel(self: *const Store, parcel_id: []const u8) bool {
        for (self.records.items) |*record| if (std.mem.eql(u8, record.parcelId(), parcel_id)) return true;
        return false;
    }

    pub fn containsParcelYear(self: *const Store, parcel_id: []const u8, year: i32) bool {
        for (self.records.items) |*record| if (record.tax_year == year and std.mem.eql(u8, record.parcelId(), parcel_id)) return true;
        return false;
    }

    pub fn yearAvailable(self: *const Store, year: i32) bool {
        return containsYear(self.years.items, year);
    }
};

fn containsYear(years: []const i32, year: i32) bool {
    for (years) |value| if (value == year) return true;
    return false;
}

fn validParcelId(value: []const u8) bool {
    if (value.len != 12) return false;
    for (value) |c| if (c < '0' or c > '9') return false;
    return true;
}

fn parcelYearKey(parcel_id: []const u8, year: i32) ?u64 {
    const numeric = std.fmt.parseInt(u64, parcel_id, 10) catch return null;
    return numeric ^ (@as(u64, @bitCast(@as(i64, year))) *% 0x9e3779b97f4a7c15);
}

fn copyField(comptime N: usize, dest: *[N]u8, len: *u8, source: []const u8) void {
    const amount = @min(source.len, N);
    @memset(dest, 0);
    @memcpy(dest[0..amount], source[0..amount]);
    len.* = @intCast(amount);
}

fn parseFloat(value: []const u8) f64 { return std.fmt.parseFloat(f64, value) catch 0; }
fn parseYear(value: []const u8) i32 { return @intFromFloat(parseFloat(value)); }

fn nextField(line: []const u8, cursor: *usize, buffer: []u8) []const u8 {
    var count: usize = 0;
    if (cursor.* < line.len and line[cursor.*] == '"') {
        cursor.* += 1;
        while (cursor.* < line.len) {
            const c = line[cursor.*];
            if (c == '"') {
                if (cursor.* + 1 < line.len and line[cursor.* + 1] == '"') {
                    if (count < buffer.len) buffer[count] = '"';
                    count += 1;
                    cursor.* += 2;
                    continue;
                }
                cursor.* += 1;
                break;
            }
            if (count < buffer.len) buffer[count] = c;
            count += 1;
            cursor.* += 1;
        }
    } else {
        const start = cursor.*;
        while (cursor.* < line.len and line[cursor.*] != ',') cursor.* += 1;
        const source = line[start..cursor.*];
        const amount = @min(source.len, buffer.len);
        @memcpy(buffer[0..amount], source[0..amount]);
        count = amount;
    }
    if (cursor.* < line.len and line[cursor.*] == ',') cursor.* += 1;
    return buffer[0..@min(count, buffer.len)];
}

fn parseRecord(line: []const u8, out: *Property) ?Property {
    var cursor: usize = 0;
    var fields: [34][256]u8 = undefined;
    var values: [34][]const u8 = undefined;
    for (&fields, 0..) |*buffer, index| values[index] = nextField(line, &cursor, buffer);
    if (values[1].len == 0) return null;
    copyField(12, &out.parcel_id, &out.parcel_id_len, values[1]);
    copyField(96, &out.address, &out.address_len, values[2]);
    copyField(48, &out.city, &out.city_len, values[3]);
    copyField(12, &out.zip, &out.zip_len, values[5]);
    copyField(64, &out.property_class, &out.property_class_len, values[8]);
    copyField(48, &out.structure_type, &out.structure_type_len, values[9]);
    copyField(8, &out.homestead, &out.homestead_len, values[10]);
    out.tax_year = parseYear(values[12]);
    out.market_value = parseFloat(values[13]);
    out.land_value = parseFloat(values[14]);
    out.building_value = parseFloat(values[15]);
    out.total_tax = parseFloat(values[17]);
    out.living_sq_ft = parseFloat(values[19]);
    out.bedrooms = parseFloat(values[21]);
    out.bathrooms = parseFloat(values[22]);
    out.stories = parseFloat(values[23]);
    out.basement = values[24].len > 0 and (values[24][0] == 'Y' or values[24][0] == 'y');
    out.year_built = parseFloat(values[26]);
    out.acres = parseFloat(values[27]);
    out.deed_acres = parseFloat(values[28]);
    copyField(32, &out.neighborhood, &out.neighborhood_len, values[29]);
    copyField(16, &out.levy_code, &out.levy_code_len, values[30]);
    return out.*;
}

pub fn parseRecordForTest(line: []const u8, out: *Property) bool {
    return parseRecord(line, out) != null;
}

test "parcel IDs remain twelve-character text" {
    var property: Property = .{};
    try std.testing.expect(parseRecord("1,000000000001,1 MAIN ST,CITY,MN,55000,,,,,,,,2026,100000,50000,50000,,1000,,1200,,3,2,2,Y,,1990,,1,1,N01,123-,,,", &property) != null);
    try std.testing.expectEqualStrings("000000000001", property.parcelId());
}
