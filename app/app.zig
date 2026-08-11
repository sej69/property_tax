const std = @import("std");
const http = std.http;
const ingest = @import("ingest");
const provider = @import("provider");
const comparable = @import("comparable");
const geometry = @import("geometry");
const tiles = @import("tiles");

const default_csv = "Anoka_County_Single_Family_Property_Taxes_Enhanced.csv";

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var csv_path: []const u8 = default_csv;
    var port: u16 = 8080;
    var should_serve = true;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--csv")) {
            csv_path = args.next() orelse default_csv;
        } else if (std.mem.eql(u8, arg, "--port")) {
            port = std.fmt.parseInt(u16, args.next() orelse "8080", 10) catch 8080;
        } else if (std.mem.eql(u8, arg, "--check")) {
            should_serve = false;
        }
    }

    var store = ingest.Store.init(init.gpa);
    defer store.deinit();
    store.loadCsv(init.io, csv_path) catch |err| {
        std.debug.print("unable to load {s}: {t}\n", .{ csv_path, err });
        return err;
    };
    std.debug.print("loaded {d} records across {d} years from {s}\n", .{ store.records.items.len, store.years.items.len, csv_path });
    if (!should_serve) return;
    try serve(init, &store, port);
}

fn serve(init: std.process.Init, store: *const ingest.Store, port: u16) !void {
    const address = try std.Io.net.IpAddress.parse("0.0.0.0", port);
    var listener = try address.listen(init.io, .{ .reuse_address = true });
    defer listener.deinit(init.io);
    std.debug.print("property-tax-explorer listening on http://127.0.0.1:{d}\n", .{port});
    while (true) {
        var stream = try listener.accept(init.io);
        defer stream.close(init.io);
        var recv_buffer: [16 * 1024]u8 = undefined;
        var send_buffer: [32 * 1024]u8 = undefined;
        var reader = stream.reader(init.io, &recv_buffer);
        var writer = stream.writer(init.io, &send_buffer);
        var server: http.Server = .init(&reader.interface, &writer.interface);
        var request = server.receiveHead() catch continue;
        handle(init.io, init.gpa, store, &request) catch |err| {
            std.debug.print("request failed: {t}\n", .{err});
        };
        writer.interface.flush() catch {};
    }
}

fn handle(io: std.Io, allocator: std.mem.Allocator, store: *const ingest.Store, request: *http.Server.Request) !void {
    const target = request.head.target;
    if (request.head.method != .GET) return respond(request, .method_not_allowed, "application/json", "{\"error\":\"read-only GET API\"}");
    if (std.mem.eql(u8, target, "/healthz")) return health(request, store);
    if (std.mem.eql(u8, target, "/api/v1/years")) return years(request, store);
    if (std.mem.startsWith(u8, target, "/api/v1/properties/search")) return search(request, store);
    if (std.mem.startsWith(u8, target, "/api/v1/properties/") and std.mem.indexOf(u8, target, "/location") != null) return propertyLocation(io, allocator, request, store);
    if (std.mem.startsWith(u8, target, "/api/v1/properties/")) return propertyDetail(request, store);
    if (std.mem.startsWith(u8, target, "/api/v1/rankings")) return rankings(request, store);
    if (std.mem.startsWith(u8, target, "/api/v1/map")) return mapData(request, store);
    if (std.mem.startsWith(u8, target, "/tiles/")) return tileRequest(io, allocator, request, store);
    return staticFile(io, allocator, request, target);
}

fn health(request: *http.Server.Request, store: *const ingest.Store) !void {
    var body: [512]u8 = undefined;
    const rendered = try std.fmt.bufPrint(&body, "{{\"status\":\"ok\",\"records\":{d},\"years\":{d},\"read_only\":true,\"uploads\":false}}", .{ store.records.items.len, store.years.items.len });
    return respond(request, .ok, "application/json", rendered);
}

fn years(request: *http.Server.Request, store: *const ingest.Store) !void {
    var body: [2048]u8 = undefined;
    var offset: usize = 0;
    append(&body, &offset, "{\"years\":[");
    for (store.years.items, 0..) |year, index| {
        if (index != 0) append(&body, &offset, ",");
        appendFmt(&body, &offset, "{d}", .{year});
    }
    append(&body, &offset, "]}");
    return respond(request, .ok, "application/json", body[0..offset]);
}

fn search(request: *http.Server.Request, store: *const ingest.Store) !void {
    const query = queryValue(request.head.target, "q") orelse "";
    var body: [16 * 1024]u8 = undefined;
    var offset: usize = 0;
    append(&body, &offset, "{\"results\":[");
    var emitted: usize = 0;
    for (store.records.items) |*property| {
        if (query.len > 0 and std.ascii.indexOfIgnoreCase(property.addressText(), query) == null and std.ascii.indexOfIgnoreCase(property.cityText(), query) == null and !std.mem.eql(u8, property.parcelId(), query)) continue;
        if (emitted != 0) append(&body, &offset, ",");
        appendFmt(&body, &offset, "{{\"parcel_id\":\"{s}\",\"address\":\"{s}\",\"city\":\"{s}\",\"year\":{d},\"effective_rate\":{d:.4}}}", .{ property.parcelId(), property.addressText(), property.cityText(), property.tax_year, comparable.effectiveRate(property) });
        emitted += 1;
        if (emitted == 20) break;
    }
    appendFmt(&body, &offset, "],\"query\":\"{s}\"}}", .{query});
    return respond(request, .ok, "application/json", body[0..offset]);
}

fn propertyDetail(request: *http.Server.Request, store: *const ingest.Store) !void {
    const prefix = "/api/v1/properties/";
    const rest = request.head.target[prefix.len..];
    const end = std.mem.indexOfScalar(u8, rest, '?') orelse rest.len;
    const parcel_id = rest[0..end];
    const year = queryInt(request.head.target, "year");
    var selected: ?*const ingest.Property = null;
    for (store.records.items) |*property| if (std.mem.eql(u8, property.parcelId(), parcel_id) and (year == null or property.tax_year == year.?)) { selected = property; break; };
    const property = selected orelse return respond(request, .not_found, "application/json", "{\"error\":\"CSV-backed property not found\"}");
    var candidates: [20]comparable.Candidate = undefined;
    const result = comparable.find(property, store.records.items, &candidates);
    var body: [4096]u8 = undefined;
    const rendered = try std.fmt.bufPrint(&body, "{{\"property\":{{\"parcel_id\":\"{s}\",\"address\":\"{s}\",\"city\":\"{s}\",\"tax_year\":{d},\"market_value\":{d:.2},\"total_tax\":{d:.2},\"effective_rate\":{d:.4},\"levy_code\":\"{s}\",\"property_class\":\"{s}\",\"homestead\":\"{s}\",\"neighborhood\":\"{s}\"}},\"comparables\":{{\"count\":{d},\"median_rate\":{d:.4},\"lower_rate\":{d:.4},\"upper_rate\":{d:.4},\"confidence\":\"{s}\"}},\"geometry\":null,\"geometry_status\":\"county GIS join pending\"}}", .{ property.parcelId(), property.addressText(), property.cityText(), property.tax_year, property.market_value, property.total_tax, comparable.effectiveRate(property), property.levyCodeText(), property.classText(), property.homesteadText(), property.neighborhoodText(), result.count, result.median_rate, result.lower_rate, result.upper_rate, result.confidence });
    return respond(request, .ok, "application/json", rendered);
}

fn propertyLocation(io: std.Io, allocator: std.mem.Allocator, request: *http.Server.Request, store: *const ingest.Store) !void {
    const prefix = "/api/v1/properties/";
    const suffix = "/location";
    const rest = request.head.target[prefix.len..];
    const suffix_start = std.mem.indexOf(u8, rest, suffix) orelse return respond(request, .not_found, "application/json", "{\"error\":\"invalid property location path\"}");
    const trailing = rest[suffix_start + suffix.len ..];
    if (trailing.len > 0 and trailing[0] != '?') return respond(request, .not_found, "application/json", "{\"error\":\"invalid property location path\"}");
    const parcel_id = rest[0..suffix_start];
    var selected: ?*const ingest.Property = null;
    for (store.records.items) |*property| if (std.mem.eql(u8, property.parcelId(), parcel_id)) { selected = property; break; };
    const property = selected orelse return respond(request, .not_found, "application/json", "{\"error\":\"CSV-backed property not found\"}");

    var cache_path_buffer: [128]u8 = undefined;
    const cache_path = try std.fmt.bufPrint(&cache_path_buffer, ".cache/geocode/{s}.json", .{parcel_id});
    const now_ms = std.Io.Clock.real.now(io).toMilliseconds();
    if (std.Io.Dir.cwd().statFile(io, cache_path, .{})) |stat| {
        const age_ms = now_ms - stat.mtime.toMilliseconds();
        if (age_ms >= 0 and age_ms <= 7 * 24 * std.time.ms_per_s) {
            const cached = std.Io.Dir.cwd().readFileAlloc(io, cache_path, allocator, .limited(4096)) catch null;
            if (cached) |body| {
                defer allocator.free(body);
                return respondLocation(request, .ok, body, "HIT");
            }
        }
    } else |_| {}

    var upstream_url_buffer: [1024]u8 = undefined;
    var upstream_url_offset: usize = 0;
    append(&upstream_url_buffer, &upstream_url_offset, "https://nominatim.openstreetmap.org/search?format=jsonv2&limit=1&countrycodes=us&q=");
    if (!appendUrlEncoded(&upstream_url_buffer, &upstream_url_offset, property.addressText()) or
        !appendUrlEncoded(&upstream_url_buffer, &upstream_url_offset, ", ") or
        !appendUrlEncoded(&upstream_url_buffer, &upstream_url_offset, property.cityText()) or
        !appendUrlEncoded(&upstream_url_buffer, &upstream_url_offset, ", MN ") or
        !appendUrlEncoded(&upstream_url_buffer, &upstream_url_offset, property.zipText())) {
        return respond(request, .bad_request, "application/json", "{\"error\":\"property address is too long to locate\"}");
    }

    var response_storage: [256 * 1024]u8 = undefined;
    var response_writer = std.Io.Writer.fixed(&response_storage);
    var client: http.Client = .{ .allocator = allocator, .io = io };
    defer client.deinit();
    const upstream_headers = [_]http.Header{
        .{ .name = "User-Agent", .value = "AnokaCountyPropertyTaxExplorer/0.1 (https://github.com/sej69/property_tax)" },
        .{ .name = "Accept", .value = "application/json" },
    };
    const result = client.fetch(.{
        .location = .{ .url = upstream_url_buffer[0..upstream_url_offset] },
        .response_writer = &response_writer,
        .headers = .{ .accept_encoding = .{ .override = "identity" } },
        .extra_headers = &upstream_headers,
        .keep_alive = false,
    }) catch return respond(request, .bad_gateway, "application/json", "{\"error\":\"address location service unavailable\"}");
    if (result.status != .ok) return respond(request, .bad_gateway, "application/json", "{\"error\":\"address location service returned an error\"}");

    const upstream_body = response_writer.buffered();
    const latitude_text = jsonStringField(upstream_body, "lat") orelse return respond(request, .not_found, "application/json", "{\"error\":\"address could not be located\"}");
    const longitude_text = jsonStringField(upstream_body, "lon") orelse return respond(request, .not_found, "application/json", "{\"error\":\"address could not be located\"}");
    const latitude = std.fmt.parseFloat(f64, latitude_text) catch return respond(request, .not_found, "application/json", "{\"error\":\"address location was invalid\"}");
    const longitude = std.fmt.parseFloat(f64, longitude_text) catch return respond(request, .not_found, "application/json", "{\"error\":\"address location was invalid\"}");

    var body: [512]u8 = undefined;
    const rendered = try std.fmt.bufPrint(&body, "{{\"status\":\"ok\",\"latitude\":{d:.7},\"longitude\":{d:.7},\"source\":\"nominatim\"}}", .{ latitude, longitude });
    std.Io.Dir.cwd().createDirPath(io, ".cache/geocode") catch {};
    std.Io.Dir.cwd().writeFile(io, .{ .sub_path = cache_path, .data = rendered, .flags = .{ .truncate = true } }) catch {};
    return respondLocation(request, .ok, rendered, "MISS");
}

fn rankings(request: *http.Server.Request, store: *const ingest.Store) !void {
    const year = queryInt(request.head.target, "year") orelse if (store.years.items.len > 0) store.years.items[0] else 0;
    var body: [8192]u8 = undefined;
    var offset: usize = 0;
    const Ranked = struct { property: *const ingest.Property, rate: f64 };
    var top: [50]Ranked = undefined;
    var top_count: usize = 0;
    for (store.records.items) |*property| {
        if (property.tax_year != year or property.market_value <= 0) continue;
        const item = Ranked{ .property = property, .rate = comparable.effectiveRate(property) };
        var position: usize = 0;
        while (position < top_count and top[position].rate >= item.rate) position += 1;
        if (position >= top.len) continue;
        if (top_count < top.len) top_count += 1;
        var shift = top_count;
        while (shift > position + 1) : (shift -= 1) top[shift - 1] = top[shift - 2];
        top[position] = item;
    }
    appendFmt(&body, &offset, "{{\"year\":{d},\"ranking\":[", .{year});
    var emitted: usize = 0;
    for (top[0..top_count]) |item| {
        const property = item.property;
        if (emitted != 0) append(&body, &offset, ",");
        appendFmt(&body, &offset, "{{\"rank\":{d},\"parcel_id\":\"{s}\",\"rate\":{d:.4},\"address\":\"{s}\"}}", .{ emitted + 1, property.parcelId(), item.rate, property.addressText() });
        emitted += 1;
    }
    appendFmt(&body, &offset, "],\"returned\":{d},\"ranked_property_count\":{d},\"scope\":\"CSV-backed records only\"}}", .{emitted, top_count});
    return respond(request, .ok, "application/json", body[0..offset]);
}

fn mapData(request: *http.Server.Request, store: *const ingest.Store) !void {
    _ = store;
    return respond(request, .ok, "application/geo+json", "{\"type\":\"FeatureCollection\",\"features\":[],\"scope\":\"CSV-backed properties only; geometry join required\"}");
}

fn tileRequest(io: std.Io, allocator: std.mem.Allocator, request: *http.Server.Request, store: *const ingest.Store) !void {
    const policy = tiles.CachePolicy{ .coverage = .{ .csv_backed_count = store.records.items.len } };
    const coordinates = parseTileTarget(request.head.target) orelse return respond(request, .bad_request, "application/json", "{\"error\":\"invalid tile path\"}");
    if (!policy.allows(coordinates.z, coordinates.x, coordinates.y)) {
        return respond(request, .forbidden, "application/json", "{\"error\":\"tile is outside the CSV-backed county coverage envelope\"}");
    }

    var tile_path_buffer: [128]u8 = undefined;
    const tile_path = try std.fmt.bufPrint(&tile_path_buffer, ".cache/tiles/{d}/{d}/{d}.png", .{ coordinates.z, coordinates.x, coordinates.y });
    const now_ms = std.Io.Clock.real.now(io).toMilliseconds();
    if (std.Io.Dir.cwd().statFile(io, tile_path, .{})) |stat| {
        const age_ms = now_ms - stat.mtime.toMilliseconds();
        if (age_ms >= 0 and age_ms <= policy.max_age_seconds * std.time.ms_per_s) {
            const cached = std.Io.Dir.cwd().readFileAlloc(io, tile_path, allocator, .limited(4 * 1024 * 1024)) catch null;
            if (cached) |body| {
                defer allocator.free(body);
                return respondTile(request, body, true);
            }
        }
    } else |_| {}

    var upstream_buffer: [256]u8 = undefined;
    const upstream_url = try std.fmt.bufPrint(&upstream_buffer, "https://tile.openstreetmap.org/{d}/{d}/{d}.png", .{ coordinates.z, coordinates.x, coordinates.y });
    var response_storage: [4 * 1024 * 1024]u8 = undefined;
    var response_writer = std.Io.Writer.fixed(&response_storage);
    var client: http.Client = .{ .allocator = allocator, .io = io };
    defer client.deinit();
    const upstream_headers = [_]http.Header{
        .{ .name = "User-Agent", .value = "AnokaCountyPropertyTaxExplorer/0.1" },
        .{ .name = "Accept", .value = "image/png" },
    };
    const result = client.fetch(.{
        .location = .{ .url = upstream_url },
        .response_writer = &response_writer,
        .headers = .{ .accept_encoding = .{ .override = "identity" } },
        .extra_headers = &upstream_headers,
        .keep_alive = false,
    }) catch return respond(request, .bad_gateway, "application/json", "{\"error\":\"OpenStreetMap tile request failed\"}");
    if (result.status != .ok) return respond(request, .bad_gateway, "application/json", "{\"error\":\"OpenStreetMap tile upstream returned an error\"}");
    const body = response_writer.buffered();
    if (body.len == 0) return respond(request, .bad_gateway, "application/json", "{\"error\":\"OpenStreetMap tile upstream returned an empty response\"}");

    const directory_path = try std.fmt.bufPrint(&tile_path_buffer, ".cache/tiles/{d}/{d}", .{ coordinates.z, coordinates.x });
    std.Io.Dir.cwd().createDirPath(io, directory_path) catch {};
    std.Io.Dir.cwd().writeFile(io, .{ .sub_path = tile_path, .data = body, .flags = .{ .truncate = true } }) catch {};
    return respondTile(request, body, false);
}

const TileCoordinates = struct { z: u8, x: u32, y: u32 };

fn parseTileTarget(target: []const u8) ?TileCoordinates {
    var parts = std.mem.splitScalar(u8, target, '/');
    _ = parts.next();
    if (!std.mem.eql(u8, parts.next() orelse return null, "tiles")) return null;
    const z_text = parts.next() orelse return null;
    const x_text = parts.next() orelse return null;
    var y_text = parts.next() orelse return null;
    if (parts.next() != null or !std.mem.endsWith(u8, y_text, ".png")) return null;
    y_text = y_text[0 .. y_text.len - 4];
    const z = std.fmt.parseInt(u8, z_text, 10) catch return null;
    const x = std.fmt.parseInt(u32, x_text, 10) catch return null;
    const y = std.fmt.parseInt(u32, y_text, 10) catch return null;
    return .{ .z = z, .x = x, .y = y };
}

fn respondTile(request: *http.Server.Request, body: []const u8, cached: bool) !void {
    const cache_state = if (cached) "HIT" else "MISS";
    const headers = [_]http.Header{
        .{ .name = "Content-Type", .value = "image/png" },
        .{ .name = "Cache-Control", .value = "public, max-age=604800" },
        .{ .name = "X-Tile-Cache", .value = cache_state },
        .{ .name = "X-Content-Type-Options", .value = "nosniff" },
    };
    try request.respond(body, .{ .status = .ok, .extra_headers = &headers });
}

fn respondLocation(request: *http.Server.Request, status: http.Status, body: []const u8, cache_state: []const u8) !void {
    const headers = [_]http.Header{
        .{ .name = "Content-Type", .value = "application/json" },
        .{ .name = "Cache-Control", .value = "public, max-age=604800" },
        .{ .name = "X-Geocode-Cache", .value = cache_state },
        .{ .name = "X-Content-Type-Options", .value = "nosniff" },
    };
    try request.respond(body, .{ .status = status, .extra_headers = &headers });
}

fn staticFile(io: std.Io, allocator: std.mem.Allocator, request: *http.Server.Request, target: []const u8) !void {
    const path = if (std.mem.eql(u8, target, "/") or target.len == 0) "property-ui/index.html" else if (std.mem.eql(u8, target, "/app.js")) "property-ui/app.js" else if (std.mem.eql(u8, target, "/styles.css")) "property-ui/styles.css" else if (std.mem.eql(u8, target, "/map.js")) "county-ui/map.js" else if (std.mem.eql(u8, target, "/map.css")) "county-ui/map.css" else return respond(request, .not_found, "text/plain", "not found");
    const content = std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(4 * 1024 * 1024)) catch return respond(request, .not_found, "text/plain", "asset not found");
    defer allocator.free(content);
    const content_type = if (std.mem.endsWith(u8, path, ".html")) "text/html; charset=utf-8" else if (std.mem.endsWith(u8, path, ".css")) "text/css; charset=utf-8" else "application/javascript; charset=utf-8";
    return respond(request, .ok, content_type, content);
}

fn respond(request: *http.Server.Request, status: http.Status, content_type: []const u8, body: []const u8) !void {
    const headers = [_]http.Header{ .{ .name = "Content-Type", .value = content_type }, .{ .name = "Cache-Control", .value = "no-store" }, .{ .name = "X-Content-Type-Options", .value = "nosniff" } };
    try request.respond(body, .{ .status = status, .extra_headers = &headers });
}

fn append(buffer: []u8, offset: *usize, text: []const u8) void {
    const amount = @min(text.len, buffer.len - offset.*);
    @memcpy(buffer[offset.* .. offset.* + amount], text[0..amount]);
    offset.* += amount;
}
fn appendFmt(buffer: []u8, offset: *usize, comptime format: []const u8, args: anytype) void { const text = std.fmt.bufPrint(buffer[offset.*..], format, args) catch return; offset.* += text.len; }
fn appendUrlEncoded(buffer: []u8, offset: *usize, text: []const u8) bool {
    const hex = "0123456789ABCDEF";
    for (text) |character| {
        const unreserved = (character >= 'a' and character <= 'z') or (character >= 'A' and character <= 'Z') or (character >= '0' and character <= '9') or character == '-' or character == '_' or character == '.' or character == '~';
        if (unreserved) {
            if (offset.* >= buffer.len) return false;
            buffer[offset.*] = character;
            offset.* += 1;
        } else {
            if (offset.* + 3 > buffer.len) return false;
            buffer[offset.*] = '%';
            buffer[offset.* + 1] = hex[character >> 4];
            buffer[offset.* + 2] = hex[character & 0x0f];
            offset.* += 3;
        }
    }
    return true;
}
fn jsonStringField(body: []const u8, field: []const u8) ?[]const u8 {
    var marker: [64]u8 = undefined;
    const marker_text = std.fmt.bufPrint(&marker, "\"{s}\"", .{field}) catch return null;
    const marker_start = std.mem.indexOf(u8, body, marker_text) orelse return null;
    var cursor = marker_start + marker_text.len;
    while (cursor < body.len and (body[cursor] == ' ' or body[cursor] == '\n' or body[cursor] == '\r' or body[cursor] == '\t' or body[cursor] == ':')) cursor += 1;
    if (cursor >= body.len or body[cursor] != '"') return null;
    cursor += 1;
    const value_start = cursor;
    while (cursor < body.len) : (cursor += 1) if (body[cursor] == '"' and body[cursor - 1] != '\\') return body[value_start..cursor];
    return null;
}
fn queryValue(target: []const u8, key: []const u8) ?[]const u8 { var marker_buffer: [64]u8 = undefined; const marker = std.fmt.bufPrint(&marker_buffer, "{s}=", .{key}) catch return null; const start = (std.mem.indexOf(u8, target, marker) orelse return null) + marker.len; const end = std.mem.indexOfScalarPos(u8, target, start, '&') orelse target.len; return target[start..end]; }
fn queryInt(target: []const u8, key: []const u8) ?i32 { const value = queryValue(target, key) orelse return null; return std.fmt.parseInt(i32, value, 10) catch null; }
