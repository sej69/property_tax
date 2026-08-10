# Test contracts

- `zig build test --summary all` must pass all committed Zig tests.
- `zig build` must compile the Linux-targetable service and static assets.
- A full operator CSV check must report the accepted record count and available
  tax years without converting parcel IDs to numeric values.
- The running service must return successful responses for `/healthz`,
  `/api/v1/years`, `/api/v1/rankings?year=<available-year>`, and `/`.
- Non-GET requests must be rejected by the public API.

