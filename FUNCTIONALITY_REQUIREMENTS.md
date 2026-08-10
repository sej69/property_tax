# Property Tax Map Platform — Functionality Requirements

Status: design document only. No application code is implemented.

## 1. Product purpose

Create a public, browser-based property-tax exploration platform for Anoka County. A user should be able to:

1. find an individual property and understand its tax history and comparable-property context; and
2. explore county-wide tax-rate patterns on a map for a selected tax year.

The application will be implemented as a Zig service using PolymorphDB through an explicit provider boundary. Browser map rendering will use open-source MapLibre GL JS because browsers require a client-side rendering runtime; no Python runtime or proprietary mapping SDK is required.

## 2. Current data constraints

The current workspace contains a 2026 snapshot:

- `save/Anoka_County_Comparable_Tax_Rate_Analysis.csv` contains approximately 101,229 single-family property records with comparable-tax analysis.
- `Anoka_County_All_Parcels_Enhanced.csv` contains approximately 140,220 parcel records.
- The comparable-tax file currently contains only tax year 2026.
- The all-parcel file also appears to be a 2026 snapshot and includes parcels without usable addresses.

The importer shall discover and publish every tax year present in the operator-provided source files; it shall not hardcode a year list. Source acquisition and download logistics are outside this specification. The user interface must not imply that a year exists until that year has been ingested and validated.

### Field completeness and derived-file requirements

The enhanced source CSV contains the fields needed for the two-stage comparable model, but the current derived comparable CSV does not preserve all of them. The next ingestion/rebuild must retain, at minimum:

- `Levy_Code`;
- `Neighborhood`;
- `Homestead`;
- `Property_Class`;
- `Living_Sq_Ft`;
- `Market_Value`;
- `Year_Built`;
- `Acres` and `Deed_Acres` when present;
- `Bedrooms`;
- `Bathrooms`;
- `Stories`;
- `Basement`;
- `Structure_Type`;
- `Building_Value`; and
- `Land_Value`.

Observed 2026 source limitations must be represented in the confidence score rather than silently imputed:

- 441 records have a blank `Levy_Code`;
- 11,422 records have a blank `Homestead`;
- each of `Living_Sq_Ft`, `Year_Built`, and `Structure_Type` has 1,376 blank records;
- 1,477 records have blank bedrooms;
- 56,131 records have blank bathrooms;
- 1,382 records have blank stories;
- 4,578 records have blank basement status; and
- `Lot_Size` is not populated, so `Acres` is the initial lot-size feature.

The current single-family source also contains a small number of non-standard property classes, including seasonal residential, multi-unit, manufactured-home-park, and nursing-home records. Eligibility must use `Property_Class` and `Use_Code`; the import must not assume that the filename alone proves single-family status.

Parcel IDs are a data-integrity boundary and must remain strings. The source contains 12-character parcel IDs, while the current derived comparable file has lost leading zeros for approximately 24,441 IDs and omits four source parcel IDs entirely. The importer shall:

- preserve `Parcel_ID`/`PIN` as a 12-character string;
- left-pad only when the source contract explicitly identifies a numeric-looking value as a parcel ID;
- reject duplicate normalized parcel IDs;
- report source rows missing from a derived projection; and
- never use floating-point or unconstrained integer conversion for parcel IDs.

The current derived file can be reconciled for the leading-zero cases, but it should be rebuilt rather than used as the authoritative identity source.

The stable map join is:

```text
property.Parcel_ID -> county parcel layer.PIN -> parcel geometry / centroid
```

The primary county parcel service is:

https://gis.anokacountymn.gov/anoka_gis/rest/services/Parcels_Tyler_StatePlane/MapServer/0

The service exposes parcel polygons, `PIN`, address fields, and GeoJSON-capable query responses. Parcel identifiers should be preferred over address geocoding.

## 3. Design principles

- Use parcel ID/PIN as the property identity and address as a searchable display attribute.
- Keep tax-year records immutable after publication; corrections create a new import version.
- Calculate and display effective rates consistently across all views.
- Perform filtering, aggregation, ranking, and pagination server-side.
- Never send the full county dataset to the browser for an ordinary map view.
- Cache parcel centroids and simplified geometry by parcel ID.
- Show the data source, tax year, comparison cohort, and freshness timestamp for every result.
- Avoid owner-related fields unless a later product decision explicitly authorizes them.
- Clearly label the application as informational tax analysis, not tax or legal advice.

## 3.1 Mapping stack and CSV-backed map access

MapLibre GL JS is the required browser map renderer. OpenStreetMap is the required base-map data source. PROJ is optional and may be included only if the Zig service needs local coordinate-reference-system conversion instead of requesting WGS84 geometry from the county GIS service.

The application shall use a Zig tile proxy/cache for the OpenStreetMap base layer:

- cache lifetime target: seven days;
- honor upstream cache headers when they are more restrictive or otherwise required;
- use HTTPS;
- send a stable, identifiable application `User-Agent`;
- preserve a valid browser `Referer` where applicable;
- show visible OpenStreetMap attribution; and
- never prefetch or bulk-download tiles outside active user map views.

OpenStreetMap standard tiles are community-funded and best-effort. A seven-day cache is compatible with the published policy when caching headers cannot be read, but the application must still follow the full policy and be prepared to switch to self-hosted OSM-derived tiles later. See https://operations.osmfoundation.org/policies/tiles/.

For the initial release, application map access shall be restricted to locations represented by the imported CSV files:

1. Build a published coverage index from CSV-backed parcel IDs and their resolved county geometries or centroids.
2. Permit property search only against indexed CSV-backed records.
3. Permit parcel geometry requests only when the requested parcel ID/PIN exists in the published CSV index.
4. Permit property overlays, ranked map features, and map-data tiles only for CSV-backed records.
5. Reject unknown addresses and parcel IDs without calling an external geocoder or returning live county-property data.
6. Restrict base-map tile requests to tile coordinates that intersect the published CSV-backed coverage index or its explicitly configured display buffer.

Base-map tiles are geographic squares and cannot be restricted to one address inside the square. The enforceable boundary is therefore tile-coordinate coverage, while all property data and parcel geometry inside the application remain strictly CSV-backed. A tile may show ordinary OSM roads or labels within an allowed square, but it must not expose non-CSV property records through the application’s overlays or APIs.

The tile-coverage decision shall be logged with the dataset/import version so a later data refresh can rebuild the allowlist deterministically.

## 4. Feature A — individual property search and history

### A1. Search entry point

The application shall provide a property search control that accepts:

- street address, including partial address;
- city;
- ZIP code;
- parcel ID/PIN; and
- a combined address-and-city query.

Search results shall be ranked in this order:

1. exact parcel ID/PIN;
2. exact normalized address plus city;
3. exact normalized address;
4. prefix or token match on address, city, or ZIP.

The search response shall include, at minimum:

- parcel ID/PIN;
- display address;
- city, state, and ZIP;
- available tax years;
- property type/class;
- current or latest available effective rate; and
- whether the property has a valid comparable cohort.

If multiple properties match, the user shall choose a result before the property detail view opens. If no result matches, the application shall explain whether the property was not found, has no address, or has no imported tax-year data.

### A2. Property map view

After selection, the application shall:

- center the map on the selected parcel;
- display the selected parcel boundary when geometry is available;
- display a centroid or address point when a boundary is not available;
- highlight the selected property independently from the county-wide color scale;
- provide a link or citation to the county GIS source; and
- show a geometry-status message when the parcel geometry could not be resolved.

Full polygon geometry should be loaded on demand. The initial property response should use cached centroid and simplified geometry where possible.

### A3. Selected-year property summary

For the selected tax year, display:

- total tax;
- special assessments, separately identified;
- market value;
- land value and building value when available;
- effective tax rate;
- effective tax rate as a percentage;
- living square feet and tax per living square foot when available;
- property class and structure type;
- homestead and use-program indicators when available;
- physical comparable score, tax anomaly score, and confidence label; and
- source dataset and import version.

The effective tax rate shall be defined consistently as:

```text
effective_tax_rate = total_tax / market_value
effective_tax_rate_percent = effective_tax_rate * 100
```

If market value is zero or missing, the rate shall be null and the UI shall display `Not available`; it shall never display an artificial zero rate.

### A4. Tax-history view

The property detail view shall provide a year-by-year chart and table containing, where available:

- tax year;
- total tax;
- market value;
- effective tax rate;
- effective tax rate percentage;
- special assessments;
- comparable median rate;
- comparable 25th–75th percentile range;
- difference from comparable median;
- comparable peer count; and
- comparable-match basis;
- tax anomaly score; and
- confidence label.

The chart shall allow the user to switch between:

- total tax;
- market value; and
- effective tax rate.

The default chart shall be effective tax rate because it is the primary comparison measure.

Missing years must be represented as gaps or unavailable states, not interpolated values.

### A5. Tax-year cycling

The property view shall provide a year selector, slider, or previous/next controls.

Changing the selected year shall update atomically:

- the selected property’s tax statistics;
- the selected property’s comparable cohort;
- comparable median and mean;
- comparable percentile range;
- difference from the comparable median;
- tax anomaly score;
- confidence score and label;
- percentile/rank values;
- the selected-year map styling; and
- any linked comparison table.

The property identity and map location shall remain unchanged while the year changes. If a year has no data, the controls shall skip it or visibly mark it unavailable.

### A6. Comparable-property analysis

Each property-year record shall use a two-stage, county-only comparable model:

1. constrain the candidate pool to properties that should be taxed under roughly the same rules; then
2. rank eligible candidates by physical and property similarity.

Tax rate, total tax, and tax anomaly values must never be inputs to the similarity score. They are the outcomes being evaluated.

#### Stage 1 — hard tax-context eligibility

Candidate properties shall remain within Anoka County and shall be eligible only when they share:

- `Levy_Code`;
- `Property_Class`; and
- `Homestead` when both subject and candidate values are known.

The model shall strongly prefer the same assessor `Neighborhood`. Neighborhood is an eligibility tier, not a numeric similarity weight:

1. **Tier 1 / high context match:** same levy code, property class, known homestead status, and same neighborhood;
2. **Tier 2 / acceptable fallback:** same levy code, property class, known homestead status, and a different neighborhood within the same levy code; and
3. **Tier 3 / weak fallback:** same levy code and property class where homestead or neighborhood data is missing or the neighborhood constraint had to be relaxed.

The selected tier and all relaxed criteria shall be recorded as `comparable_match_basis`. A missing hard-match field shall never be silently treated as equal.

#### Stage 2 — physical/property similarity

Rank eligible candidates using an explicit weighted similarity score. The initial weights shall be:

| Characteristic | Weight |
|---|---:|
| Living square footage | 25% |
| Market value | 20% |
| Year built | 15% |
| Lot acreage | 10% |
| Bedrooms | 10% |
| Bathrooms | 10% |
| Structure type, stories, and basement | 10% |

Numeric differences shall be normalized before weighting so one variable cannot dominate because of its units. Categorical compatibility shall be scored explicitly for structure type, stories, and basement. The score must not use tax amount, effective tax rate, comparable flag, or estimated excess tax.

The initial numeric component rule should be:

```text
component_similarity = max(0, 1 - normalized_difference / configured_tolerance)
```

Use relative differences for living area, market value, and lot acreage; year difference in years; and bounded absolute differences for bedrooms and bathrooms. Exact categorical matches receive full credit, while incompatible structure/stories/basement values receive zero for that component. Building-value-to-land-value ratio may be retained as a diagnostic feature but is not part of the initial weighted score.

Missing physical fields shall not be imputed from tax outcomes or silently treated as equal. A pair may omit a missing component and renormalize the remaining weights, but it shall fail the pair if less than 70% of the configured physical-score weight remains available. Subject-level missingness and pair coverage shall reduce confidence and be recorded with the match basis.

The initial tolerance gates shall be configurable with these defaults:

- living area within approximately 20%;
- market value within approximately 25%;
- year built within 15 years;
- bedroom difference no greater than 1;
- bathroom difference no greater than 1; and
- lot-area tolerance determined by urban/rural context, using `Acres` when available and `Deed_Acres` as a secondary field.

Candidates outside a tolerance gate shall be excluded before nearest-neighbor ranking, except when the model explicitly enters a lower-confidence fallback tier and records that relaxation.

The initial target is 15 nearest comparable properties, configurable within a 10–20 range. The subject property itself shall never be included as a peer. Ties shall be resolved deterministically by normalized score and then parcel ID. A property with fewer than 5 valid peers shall be classified as insufficient data unless an explicit product decision changes that minimum.

#### Comparable statistics and anomaly result

Use the peer median as the primary comparison statistic. Also calculate the 25th and 75th percentiles when enough peers exist. The result shall display:

- peer count;
- median effective tax rate;
- comparable 25th–75th percentile range;
- subject-property effective tax rate;
- difference in percentage points from the peer median;
- percentage difference from the peer median;
- subject-property peer percentile;
- estimated tax above comparable median when calculable; and
- a plain-language flag.

Unless the peer median is zero or unavailable, define the direct tax anomaly score as:

```text
tax_anomaly_score = (subject_effective_tax_rate - peer_median_effective_tax_rate)
                    / peer_median_effective_tax_rate
```

Display the score as a percentage, while also retaining the absolute percentage-point difference. Positive values mean the subject property’s effective rate is higher than the comparable median.

The platform shall keep three distinct concepts:

1. **Comparable score:** how similar the selected peers are to the subject property;
2. **Tax anomaly score:** how unusual the subject property’s effective tax rate is relative to its peers; and
3. **Confidence score:** how much the system should trust the comparison based on peer count, context tier, similarity, missing fields, and tolerance relaxation.

Suggested confidence labels:

- **High:** at least 15 peers, Tier 1 context, no critical missing subject fields, and strong similarity;
- **Medium:** at least 10 peers with a Tier 2 context match or minor missingness; and
- **Low:** 5–9 peers, Tier 3 context, or substantial tolerance relaxation.

These labels are evidence-quality descriptions, not legal or tax conclusions.

Suggested flags:

- `Below Comparable Range`;
- `Within Comparable Range`;
- `Above Comparable Range`;
- `High Tax Anomaly`;
- `Insufficient Comparable Data`; and
- `Rate Not Available`.

The application shall never label a property “overtaxed.” It shall describe a property as unusual or high relative to its documented comparable cohort.

#### Independent statistical model

The data model shall reserve space for a second, independent anomaly test that predicts expected effective tax rate from tax context and property characteristics. A robust regression is the preferred first model; a gradient-boosted model may be evaluated later if its behavior can be explained and validated.

The statistical model shall be a later phase unless it can be validated against held-out data. When enabled, the property view shall show actual rate, predicted rate, residual, model version, and model confidence separately from the direct-comparable result. A high-confidence investigation signal requires agreement between the direct comparable anomaly and the statistical residual; neither model alone shall be presented as proof of an incorrect assessment.

The application shall distinguish comparison with similar properties from raw county-wide ranking. Both can be displayed, but they must not be represented as the same statistic.

### A7. Comparable-property list

The property view shall include a paginated comparable-property table containing:

- address;
- city;
- parcel ID/PIN;
- market value;
- total tax;
- effective tax rate;
- physical similarity score;
- difference from the selected property;
- peer percentile; and
- confidence label; and
- selected-year map action.

The user shall be able to sort the table by rate, market value, total tax, or distance when geometry is available.

## 5. Feature B — county-wide tax-rate map

### B1. Map scope

The county-wide map shall support two data layers:

1. **Comparable-ranked properties:** properties with enough data to calculate a valid comparable-relative ranking. These properties receive the green-to-red color scale.
2. **All CSV parcels:** all parcels present in the imported all-parcel CSV. Parcels without a valid comparable ranking remain visible as gray/unranked or may be hidden through a layer toggle.

This distinction is necessary because the current single-family comparable dataset does not represent every parcel type in the all-parcel file. The initial release shall not query or display parcels that are absent from the imported CSV datasets.

### B2. Selected tax year

The map shall provide a tax-year selector. Selecting a year shall replace the map’s data view and legend values for that year.

Changing years shall update:

- property colors;
- visible/unranked status;
- rank and percentile values;
- map popups;
- summary counts; and
- any active filters.

The map shall not mix tax-rate values from different years in a single color layer.

### B3. Ranking and color semantics

The map shall provide a ranking-mode selector with two modes:

1. **Comparable anomaly mode:** color by the property’s tax anomaly relative to its valid comparable cohort for the selected year.
2. **County-wide rate mode:** color by the property’s effective-tax-rate percentile across all CSV-backed properties with a valid rate for the selected year.

Both modes shall use the same green-to-yellow-to-orange-to-red visual direction, but the legend and popup must identify the active mode. The selected mode must never mix values from different tax years.

The default comparable-anomaly color bands are:

| Color | Suggested peer-percentile band | Meaning |
|---|---:|---|
| Green | 0–20th percentile | Lower effective rate than most comparable properties |
| Yellow | >20th–50th percentile | Lower-to-middle comparable rate |
| Orange | >50th–80th percentile | Higher comparable rate |
| Red | >80th–100th percentile | Highest effective rates among comparable properties |
| Gray | Unranked | Missing/insufficient comparable data |

The exact percentile thresholds shall be configurable and stored with the published map style version.

Each map feature shall also expose:

- county-wide effective-rate rank;
- county-wide percentile;
- comparable-peer rank;
- comparable-peer percentile;
- tax anomaly score;
- comparable confidence label;
- effective rate;
- comparable median rate;
- difference from comparable median; and
- data quality/status flag.

The map legend must say whether colors represent comparable-anomaly percentile or county-wide effective-rate percentile. The user must be able to switch modes without changing the selected tax year or viewport.

### B4. Map rendering

The map shall:

- render clustered points or vector tiles at county-wide zoom levels;
- load individual parcel polygons at closer zoom levels or on selection;
- use server-side viewport and year filtering against CSV-backed records only;
- support hover or click inspection;
- preserve the selected year while the user pans and zooms;
- provide a reset-to-county-extent action; and
- display a loading state while a new year or viewport is being fetched.

The browser must not receive 100,000+ full polygon geometries for an ordinary initial load.

### B5. Map popup

Clicking a ranked property shall show:

- address;
- parcel ID/PIN;
- selected tax year;
- effective tax rate;
- comparable median rate;
- tax anomaly score;
- comparable confidence label;
- comparable-peer percentile;
- county-wide percentile;
- tax-rate flag; and
- an action to open the full property view.

Clicking an unranked parcel shall explain why it is unranked, for example missing market value, missing tax, or insufficient peers.

### B6. Map filters

The county map shall support:

- tax year;
- city;
- property class;
- structure type;
- homestead status;
- comparable-rate flag;
- minimum and maximum effective rate;
- ranked-only/all-parcels toggle; and
- search-and-zoom to a property.

The filter state may be represented by stateless URL parameters. No server-side saved-view identifier shall be created in the first release.

## 6. Data and provider model

The logical model shall contain at least these entities:

### `dataset`

- dataset ID;
- county and jurisdiction;
- source URI or source description;
- tax-year range;
- schema version;
- import version;
- imported timestamp;
- source checksum; and
- publication status.

### `property`

- jurisdiction ID;
- parcel ID/PIN;
- normalized address;
- display address;
- city, state, ZIP;
- levy code;
- assessor neighborhood;
- property class;
- use code;
- structure type;
- stories;
- basement; and
- stable geometry reference.

### `property_tax_year`

- property ID;
- tax year;
- market value;
- land value;
- building value;
- classified value;
- total tax;
- special assessments;
- effective tax rate;
- living square feet;
- lot acreage;
- bedrooms;
- bathrooms;
- year built;
- building value;
- land value;
- homestead;
- use program; and
- source/import version.

### `comparable_snapshot`

- property ID;
- tax year;
- peer definition version;
- county-only eligibility tier;
- hard-match context fields and any relaxed criteria;
- peer count;
- match basis;
- comparable property IDs or a reproducible peer-set reference;
- median rate;
- 25th percentile rate;
- 75th percentile rate;
- physical similarity score;
- tax anomaly score;
- confidence score;
- confidence label;
- mean rate;
- difference from median;
- peer percentile;
- estimated excess tax when calculable; and
- classification flag.

### `tax_model_snapshot` (later phase)

- property ID;
- tax year;
- model version;
- model family;
- predicted effective tax rate;
- residual from predicted rate;
- model confidence;
- feature availability summary; and
- validation/evaluation reference.

### `parcel_geometry`

- jurisdiction ID;
- parcel ID/PIN;
- source layer;
- source geometry identifier;
- centroid longitude/latitude;
- simplified geometry;
- full geometry reference or payload;
- coordinate reference system; and
- geometry retrieval status.

### `ingestion_run`

- run ID;
- source dataset;
- requested tax years;
- row counts;
- rejected-row counts;
- geometry match counts;
- validation errors;
- source checksum; and
- completion status.

The Zig application shall interact with these through a provider interface, for example:

- `search_properties(filter)`;
- `get_property(parcel_id, tax_year)`;
- `get_property_history(parcel_id)`;
- `get_comparables(parcel_id, tax_year, page)`;
- `get_map_features(filter, viewport, tax_year)`;
- `get_year_summary(filter, tax_year)`;
- `get_tile_coverage(dataset_version, z, x, y)`;
- `ingest_dataset(source)`; and
- `get_ingestion_status(run_id)`.

PolymorphDB is the intended provider. The interface must make unsupported provider capabilities explicit rather than silently falling back to incorrect in-memory behavior.

### Required PolymorphDB workload surface

The PolymorphDB repository contains related pieces—native CSV/JSON/JSONL validation, bounded aggregation, durable record storage, vector indexing, and query-planning classification—but the documented surfaces do not yet prove this property-tax workload end to end.

The current analyst-table contract is explicitly bounded to a 4 MiB / 10,000-row query path and a narrow single-table `COUNT(*)`/`SUM(...)` grammar. It documents no joins, percentiles, general SQL, persistent analyst tables, or spatial query/index contract. The vector-index work is not a substitute for structured property-feature nearest-neighbor execution.

Before implementation can claim PolymorphDB support for this application, the native Zig provider contract must demonstrate:

- durable storage of all published property-year rows and derived comparable snapshots;
- exact indexes or equivalent access paths for parcel ID, tax year, levy code, property class, neighborhood, and homestead;
- county-only candidate-pool filtering;
- batched retrieval of candidate features;
- deterministic numeric normalization and weighted similarity scoring;
- nearest-neighbor selection with a configurable peer count;
- median and 25th/75th percentile calculation;
- county-wide effective-rate ranking;
- versioned derived-view rebuilds and atomic publication;
- geometry/centroid reference or a documented geometry-cache boundary; and
- restart/recovery behavior for the published dataset and ranking projections.

The two-stage similarity calculation may execute in Zig after PolymorphDB returns the eligible candidate pool. PolymorphDB does not need to pretend that the tax-specific score is a generic vector-search problem; it does need to provide durable, indexed, reproducible candidate retrieval and derived-result persistence.

## 7. Zig service boundaries

The system should be divided into these Zig modules or service responsibilities:

1. CSV and source adapter;
2. schema and numeric validation;
3. normalized property/tax model;
4. comparable-cohort and ranking calculations;
5. PolymorphDB provider adapter;
6. county GIS geometry client;
7. geometry simplification/cache;
8. HTTP API and JSON response serialization;
9. static asset delivery;
10. public read-only request rate limiting and cache controls; and
11. observability and import audit reporting.

The core server should be a single deployable Zig binary where practical. County GIS retrieval should be asynchronous or explicitly job-based so a slow external GIS request does not block ordinary property searches.

## 8. Open-source and free-product requirements

The platform shall avoid proprietary application dependencies.

Recommended components:

- **Zig:** application server, ingestion, API, and domain logic.
- **PolymorphDB:** intended data provider behind the provider interface.
- **MapLibre GL JS:** open-source browser map renderer with GPU-accelerated vector-map support. See https://maplibre.org/projects/gl-js/.
- **OpenStreetMap:** required base-map data source, accessed through the Zig seven-day tile cache/proxy with required attribution and policy compliance.
- **Self-hosted OSM-derived tiles:** a later production option if traffic, availability, or usage limits make the public tile service unsuitable. See https://operations.osmfoundation.org/policies/tiles/.
- **PROJ, if needed:** open-source coordinate transformation support for converting county service coordinates to WGS84/Web Mercator. See https://proj.org/en/stable/.

The county ArcGIS endpoint is a public data source, not a proprietary application dependency. The product must preserve the county’s attribution, source links, and any applicable data-disclaimer requirements.

## 9. API behavior required by the UI

The first public API contract should include:

- `GET /api/years` — available years and dataset status;
- `GET /api/properties/search` — address/PIN search;
- `GET /api/properties/{parcel_id}` — selected-year property detail;
- `GET /api/properties/{parcel_id}/history` — year-by-year history;
- `GET /api/properties/{parcel_id}/comparables` — selected-year comparable page;
- `GET /api/map/features` — viewport/year-filtered map data;
- `GET /api/map/summary` — counts, rate bands, and ranking summary;
- `GET /api/geometry/{parcel_id}` — cached or on-demand parcel geometry; and
- `GET /tiles/{z}/{x}/{y}.png` — cached OpenStreetMap base tile, permitted only when the tile intersects the published CSV-backed coverage index; and
- `GET /api/datasets` — published dataset/source metadata.

All list responses shall support stable pagination. All map responses shall carry the selected tax year and ranking-definition version.

## 10. Acceptance criteria

### Individual property journey

- A user can search by address, city, ZIP, or parcel ID.
- A matching property opens at its map location.
- The selected year’s taxes, market value, effective rate, and comparable statistics are visible.
- The user can move across all available years for that property.
- Each year updates the comparable cohort and comparison statistics.
- Missing historical years are clearly identified.
- The comparable list shows the match basis and peer count.
- A user can return from the property view to the county map with the selected year preserved.

### County map journey

- A user can select a tax year and see only that year’s ranking.
- Ranked properties use the documented green-to-yellow-to-orange-to-red scale.
- Unranked parcels are gray or hidden through a clear layer control.
- Map popups show both comparable-relative and county-wide rank information.
- Filters update the map and summary without downloading the full dataset.
- Selecting a map feature opens the individual-property journey.
- The map remains usable at county-wide scale without rendering every full polygon at once.

### Data integrity

- Every published property-year result identifies its source and tax year.
- Effective-rate calculations are reproducible from stored tax and market-value fields.
- Comparable cohorts are reproducible from a versioned definition.
- Imported historical rows cannot silently overwrite a different tax year.
- Geometry joins are keyed by parcel ID/PIN and report unresolved matches.

## 11. Performance and operational targets

These are design targets to validate with Zig/PolymorphDB benchmarks, not current claims:

- stream-import 100,000+ rows without loading the entire CSV into memory;
- indexed property search p95 below 250 ms on a warm local deployment;
- property history p95 below 500 ms;
- filtered map-data response p95 below 1 second for a normal viewport;
- no full-county polygon payload in the initial browser response;
- repeat map requests served from cache when year/filter/viewport inputs match; and
- failed county GIS requests isolated from the property search and tax-history paths.

## 12. Confirmed product and deployment decisions

- Support every validated tax year found in the imported source files; do not hard-code a year range.
- Comparables are county-only.
- Display both comparable-relative ranking and county-wide effective-rate ranking.
- Use `Total_Tax / Market_Value` for effective tax rate, with special assessments shown separately.
- Show comparable-ranked properties and an optional all-CSV-parcels layer; do not display properties absent from the imported CSV files.
- Use MapLibre GL JS with OpenStreetMap as the base-map source.
- Use a seven-day Zig tile-cache/proxy for the initial deployment, with OpenStreetMap attribution and policy compliance.
- Use PROJ only if local coordinate transformation is required.
- Use the native Zig PolymorphDB interface as documented by the target provider deployment.
- Provide a read-only public explorer. No public CSV upload capability is required.
- Deploy on Linux and self-host the service.
- Use HTTPS without requiring user authentication.
- Support desktop browsers only; no dedicated mobile layout or mobile-specific behavior is required.
- Do not provide server-side saved searches.

## 13. Recommended remaining UX and operations decisions

### Charts

Use three focused views on the individual-property page:

1. effective tax rate over all available years, with the comparable median overlaid;
2. total tax and market value as separate selectable series, avoiding a misleading dual-axis chart; and
3. a selected-year comparable distribution view showing the property, peer median, and peer percentile.

Render the charts as accessible SVG or HTML generated by the browser so the first release does not require another charting dependency. Every chart shall have a data table alternative.

### Exports

Provide CSV export for:

- the selected property’s tax history;
- the selected property’s comparable-property table; and
- the current filtered map result set.

Do not provide a full-county export button in the first release. The source datasets already exist as operator-managed files, and unrestricted bulk export would create unnecessary service load.

### Accessibility

Use a desktop-first accessibility target equivalent to WCAG 2.2 AA for core controls and data views:

- keyboard-operable search, year controls, filters, tables, and popups;
- visible focus states;
- text labels and numeric values in addition to map colors;
- color-safe legend distinctions that do not rely on red/green alone;
- screen-reader-readable tables for map data; and
- a notice that the map is supplementary to the accessible data table.

Dedicated mobile layout testing is out of scope, but the application should fail gracefully when the browser viewport is narrower than the supported desktop layout.

### URL and search state

Do not persist searches or create user accounts. The recommended v1 behavior is to preserve only the current view in browser navigation state. Stateless URL parameters for a property, year, and active filters may be added later because they do not create server-side saved searches.

### Data refresh

Use an operator-triggered import on the Linux host whenever new county files are downloaded:

1. discover tax years from the source rows;
2. validate and stage each year;
3. reject or quarantine invalid rows;
4. calculate/rebuild county-only comparable cohorts and both ranking modes;
5. refresh geometry and tile-coverage indexes only for CSV-backed parcels;
6. publish the new dataset version atomically; and
7. retain the source checksum, import report, and available-year list.

No live external county-property query should be required during ordinary public browsing.

### HTTPS deployment

Run the Zig service behind a self-hosted HTTPS reverse proxy. Caddy is the recommended open-source Linux edge component for the first deployment because its documented default behavior can provision and renew certificates and redirect HTTP to HTTPS when a qualifying domain is configured. See https://caddyserver.com/docs/quick-starts/https.

## 14. Decisions still required before implementation

1. Confirm the PolymorphDB deployment’s supported native query, persistence, aggregation, derived-view, and geometry-cache capabilities against the required workload surface above.
2. Decide whether the independent statistical model is enabled in the first public release. Recommendation: ship the direct comparable engine, anomaly score, and confidence score first; add robust regression as a separately validated second phase.

## 15. Out of scope for the first release

- tax payment or filing;
- legal or tax advice;
- owner identity or contact information;
- parcel editing;
- automated appraisal or prediction;
- bulk address scraping or third-party bulk geocoding; and
- mixing tax years in a single ranking or color layer.
