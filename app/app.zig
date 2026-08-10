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
    if (std.mem.startsWith(u8, target, "/api/v1/properties/")) return propertyDetail(request, store);
    if (std.mem.startsWith(u8, target, "/api/v1/rankings")) return rankings(request, store);
    if (std.mem.startsWith(u8, target, "/api/v1/map")) return mapData(request, store);
    if (std.mem.startsWith(u8, target, "/tiles/")) return tileRequest(request, store);
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

fn tileRequest(request: *http.Server.Request, store: *const ingest.Store) !void {
    const policy = tiles.CachePolicy{ .coverage = .{ .csv_backed_count = store.records.items.len } };
    _ = policy;
    return respond(request, .forbidden, "application/json", "{\"error\":\"tile access requires a CSV-backed geometry coverage index\"}");
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
fn queryValue(target: []const u8, key: []const u8) ?[]const u8 { var marker_buffer: [64]u8 = undefined; const marker = std.fmt.bufPrint(&marker_buffer, "{s}=", .{key}) catch return null; const start = (std.mem.indexOf(u8, target, marker) orelse return null) + marker.len; const end = std.mem.indexOfScalarPos(u8, target, start, '&') orelse target.len; return target[start..end]; }
fn queryInt(target: []const u8, key: []const u8) ?i32 { const value = queryValue(target, key) orelse return null; return std.fmt.parseInt(i32, value, 10) catch null; }
