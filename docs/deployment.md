# Self-hosted Linux deployment

Build the Zig binary with `zig build -Doptimize=ReleaseFast`, place the
published CSV snapshot beside the binary, and run it behind Caddy. Caddy
terminates HTTPS and forwards only to the local Zig listener. The public
service has no authentication and no upload endpoint; operators publish new
immutable annual snapshots through the controlled import process.
