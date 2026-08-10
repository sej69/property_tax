# Anoka County Property Tax Explorer

Read-only Anoka County property-tax explorer implemented in Zig, with a native
PolymorphDB provider boundary and MapLibre GL JS using OpenStreetMap-derived
basemap data.

## Repository contents

- [Architecture recommendation](ARCHITECTURE_RECOMMENDATION.md)
- [Functionality requirements](FUNCTIONALITY_REQUIREMENTS.md)
- [Enhanced current-data downloader](anoka_property_tax_downloader_enhanced.py)
- [Historical data and geometry puller](pull_anoka_historical_data.py)
- [Local data layout](save/README.md)
- [Implementation status](IMPLEMENTATION_STATUS.md)
- [Self-hosted deployment](docs/deployment.md)

The Zig service, versioned CSV ingestion, comparable engine, read-only API,
MapLibre UI shells, county ranking endpoint, and self-hosting configuration are
included. Production geometry joins and the upstream tile fetch/cache remain
explicit follow-up work documented in `IMPLEMENTATION_STATUS.md`.

## Data handling

Downloaded parcel and tax CSV files are intentionally excluded from Git. They
are operator-managed inputs for local ingestion and may contain address-level
property records. The downloader scripts preserve parcel IDs as 12-character
text identifiers, including leading zeroes.

## Planned product

The explorer will provide:

1. property search, map location, tax history, and comparable-property analysis;
2. county-wide map ranking for a selected tax year; and
3. comparable-relative and county-wide effective-rate display modes.

The direct comparable engine is implemented for the first release. An
independent statistical model is represented as a separately labeled phase-two
slice so it cannot be confused with the direct comparable result.

## Build and run

Requires Zig 0.16 or newer.

```text
zig build test
zig build
zig build run -- --csv Anoka_County_Single_Family_Property_Taxes_Enhanced.csv --port 8080
```

The service is read-only and does not expose upload or mutation endpoints.
