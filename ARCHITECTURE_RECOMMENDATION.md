# Property Tax Map Platform Architecture Recommendation

Status: design only; no application code has been implemented.

Detailed product behavior is documented in [FUNCTIONALITY_REQUIREMENTS.md](<D:/dev case/taxes/FUNCTIONALITY_REQUIREMENTS.md>).

## Recommendation

Use Zig for the ingestion service, query API, geometry-cache pipeline, and static asset server. Use PolymorphDB through its documented native Zig interface, while keeping a provider boundary around database operations so the HTTP surface remains stable.

## Map integration

The CSV data can be tied to a map using parcel identifiers rather than bulk address geocoding:

```text
CSV.Parcel_ID -> Anoka County GIS PIN -> parcel polygon / centroid
```

The Anoka County parcel layer exposes `PIN`, address fields, and parcel polygon geometry. It supports JSON, GeoJSON, and PBF responses.

Primary GIS layer:

https://gis.anokacountymn.gov/anoka_gis/rest/services/Parcels_Tyler_StatePlane/MapServer/0

The `save/Anoka_County_Comparable_Tax_Rate_Analysis.csv` file contains 101,229 single-family records with usable addresses and parcel IDs. The all-parcel dataset contains 140,220 records; some of those have blank addresses, which is another reason to use `Parcel_ID`/`PIN` as the stable join key.

Parcel IDs must be preserved as 12-character strings, including leading zeros. They must never be converted through floating-point or unconstrained integer parsing.

## Proposed components

1. **Zig ingestion service**

   Stream CSV parsing, schema validation, normalization, indexing, and import progress reporting.

2. **PolymorphDB provider adapter**

   Define provider operations for property lookup, filtering, aggregation, import status, and geometry-cache access. Keep the HTTP API independent of PolymorphDB-specific implementation details.

3. **Parcel geometry cache**

   Fetch county parcel geometry by `PIN`, calculate and store centroids, and optionally retain simplified polygons for selected properties.

4. **Zig HTTP API**

   Provide server-side filtering, pagination, tax summaries, property detail, CSV upload, and map-data endpoints.

5. **Map frontend**

   Use MapLibre GL JS with OpenStreetMap-derived basemap data. Display clustered property points initially, then load detailed parcel polygons when a user selects a CSV-backed property.

6. **Seven-day tile cache and coverage gate**

   Serve OpenStreetMap tiles through a Zig cache/proxy with a seven-day cache target, visible attribution, a stable application identity, and no bulk prefetching. For the initial release, allow property overlays, parcel geometry, and map tile coverage only for locations represented in the imported CSV files. Because base-map tiles are geographic squares, enforce this boundary using a tile-coordinate coverage index derived from CSV-backed parcel geometry or centroids.

## PolymorphDB qualification

The application will use PolymorphDB through its documented native Zig interface. Its current analyst-table workflow is bounded and explicitly does not claim general SQL or persistent-table support, so the target deployment must be checked for the persistence, filtering, aggregation, and spatial capabilities required by this specification. Its PostgreSQL-compatible endpoint is not assumed.

Relevant local references:

- `D:/dev case/crucible-energy-review/polymorph-db/docs/analyst-table-workflow.md`
- `D:/dev case/crucible-energy-review/polymorph-db/docs/CURRENT_STATUS.md`

The provider interface keeps the HTTP/API surface stable while PolymorphDB capabilities are validated and promoted for this workload.

The first product is a read-only public explorer with no public data uploads or authentication. It will be self-hosted on Linux over HTTPS, with the Zig service behind an open-source HTTPS reverse proxy such as Caddy.

## Performance principles

- Do not send the full 100,000+ row dataset to the browser.
- Filter, aggregate, and paginate on the server.
- Cache parcel centroids and geometry by parcel ID.
- Use clustered points or vector tiles for map overview rendering.
- Load full parcel polygons only on demand.
- Benchmark database and geometry-query performance separately from Zig HTTP performance.

## Next design artifact

Before implementation, write a Zig-oriented technical specification covering:

- provider interface and PolymorphDB boundary;
- CSV import schema and validation rules;
- geometry-cache format and refresh policy;
- HTTP routes and response shapes;
- multi-user dataset isolation;
- map rendering strategy;
- performance and load-test targets.

## Important product safeguards

- Preserve county data attribution and disclaimers.
- Preserve OpenStreetMap attribution and follow its tile-usage policy.
- Do not expose property records or parcel geometry that are absent from the imported CSV files.
- Clearly label tax comparisons as informational analysis, not tax or legal advice.
- Avoid exposing owner-related fields unless explicitly required and authorized.
- Record the source dataset and tax year for every published result.
