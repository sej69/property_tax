# Validation and security checklist

The checked-in validation path is `zig build test`, followed by `zig build`.
Release validation must also exercise a real annual CSV import, leading-zero
parcel IDs, duplicate parcel-year rejection, read-only HTTP methods, unknown
parcel denial, year cycling, and tile coverage denial outside the CSV-backed
coverage index. Caddy supplies HTTPS and baseline security headers.
