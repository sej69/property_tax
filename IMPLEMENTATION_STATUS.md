# Implementation status

The first executable baseline is now in Zig and is intentionally read-only.

Implemented:

- Zig 0.16 build/run/test entry points.
- Streaming-style annual CSV normalization with BOM handling, discovered years,
  typed tax/comparable fields, duplicate parcel-year rejection, and
  twelve-character text parcel IDs.
- PolymorphDB provider boundary and deterministic in-memory vertical slice.
- Hierarchical comparable eligibility, weighted physical similarity, median
  rates, percentile range, and confidence level.
- Read-only HTTP routes for health, years, search, property detail, rankings,
  map-data scope, and tile-policy denial.
- MapLibre/OpenStreetMap browser shell with property and county views, year
  cycling, visible attribution, and CSV-backed scope messaging.
- Caddy HTTPS reverse-proxy configuration, operational manifest types, license
  notes, and a phase-two independent residual model baseline.

Known staged follow-ups:

- County parcel GeoJSON/PIN acquisition must populate the geometry cache before
  parcel boundaries and exact tile-coordinate coverage can be served.
- The tile route currently denies requests until that exact coverage index is
  published; the seven-day policy seam is present but upstream fetch/cache
  storage is not yet enabled.
- The rankings endpoint currently returns a bounded sample for the UI contract;
  PolymorphDB-backed county-wide ranking materialization is the next production
  optimization.

Acceptance status:

- The Spec Kitty mission remains unmerged because the acceptance matrix records
  geometry, tile-cache, durable-provider, and production-publication gaps
  honestly as unverified or failing criteria.
- No additional Anoka County data was downloaded during this run. The validated
  local input remains the operator-provided CSV snapshot.
