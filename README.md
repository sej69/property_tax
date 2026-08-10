# Anoka County Property Tax Explorer

Design and data-ingestion repository for a read-only Anoka County property-tax
explorer. The planned application will be implemented in Zig, use PolymorphDB
through a native provider boundary, and render maps with MapLibre GL JS and
OpenStreetMap-derived basemap data.

## Repository contents

- [Architecture recommendation](ARCHITECTURE_RECOMMENDATION.md)
- [Functionality requirements](FUNCTIONALITY_REQUIREMENTS.md)
- [Enhanced current-data downloader](anoka_property_tax_downloader_enhanced.py)
- [Historical data and geometry puller](pull_anoka_historical_data.py)
- [Local data layout](save/README.md)

The repository currently contains design artifacts and ingestion utilities. The
application implementation has not started.

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

The direct comparable engine is planned for the first release. An independent
statistical anomaly model is reserved for a later validated phase.
