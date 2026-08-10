# Mission Specification: Anoka County Property Tax Explorer

**Mission Branch**: `kitty/mission-property-tax-explorer-01KZPH51`  
**Target Branch**: `main`  
**Created**: 2026-08-10  
**Status**: Draft for planning  
**Input**: [FUNCTIONALITY_REQUIREMENTS.md](../../FUNCTIONALITY_REQUIREMENTS.md), [ARCHITECTURE_RECOMMENDATION.md](../../ARCHITECTURE_RECOMMENDATION.md), and GitHub issues [#1–#13](https://github.com/sej69/property_tax/issues).

## Product statement

Create a self-hosted, read-only public explorer for Anoka County property-tax
data. A user can search for a CSV-backed property, view its map location and
tax history, understand its county-only comparable-property context, and
explore county-wide effective-tax-rate patterns for any imported tax year.

The application runtime is Zig. PolymorphDB is the intended provider behind a
stable native Zig interface. The browser uses MapLibre GL JS with
OpenStreetMap-derived basemap data. Python remains limited to operator-managed
download utilities and is not an application runtime dependency.

## User scenarios and testing

### User story 1 — Import and publish an available dataset (P1)

As an operator, I can provide one or more county CSV snapshots and publish a
validated dataset version without manually editing identifiers or derived
rankings.

**Independent test**: A fixture containing multiple years, duplicate IDs,
leading-zero IDs, missing comparable fields, and invalid rows produces a
deterministic import report, quarantines invalid input, and either publishes a
complete version or leaves the prior version active.

**Acceptance scenarios**:

1. Given operator-provided CSV files, when ingestion runs, then every tax year
   present in valid source rows is discovered and published without a hardcoded
   year list.
2. Given a parcel ID represented as text or a numeric-looking value, when it is
   normalized, then it remains a 12-character text identifier with leading
   zeroes preserved.
3. Given invalid rows or normalized duplicate parcel IDs, when validation runs,
   then those rows are quarantined and the active dataset is not partially
   replaced.

### User story 2 — Search for one property (P1)

As a public user, I can search by address or parcel ID and select the intended
property when multiple results match.

**Independent test**: Search fixtures cover exact parcel ID, normalized address,
multiple matches, missing addresses, unknown IDs, and properties without valid
tax data.

**Acceptance scenarios**:

1. Given a supported address or parcel ID, when a user searches, then matching
   properties show parcel identity, address, available years, and the latest
   available effective rate.
2. Given multiple matches, when a user selects one, then the selected property
   opens at its cached county parcel location.
3. Given an unknown or unsupported property, when a user searches, then the UI
   explains that it is not present in the imported CSV-backed dataset.

### User story 3 — Understand tax history and comparable context (P1)

As a public user, I can cycle through available tax years and see the selected
property's values, effective rate, comparable cohort, anomaly, and confidence.

**Independent test**: A property fixture with changing peers and missing years
updates all year-dependent fields atomically while keeping property identity and
map location stable.

**Acceptance scenarios**:

1. Given a selected property and available year, when the year changes, then tax
   statistics, comparable peers, percentiles, anomaly, confidence, ranks, and
   linked map styling all update to that year.
2. Given a year with no property record, when the user cycles years, then that
   year is visibly unavailable or skipped and no value is interpolated.
3. Given an insufficient comparable cohort, when the property is displayed,
   then the result is marked insufficient rather than labeled overtaxed.

### User story 4 — Explore county-wide patterns (P1)

As a public user, I can view CSV-backed county properties colored by the
selected year's tax ranking and switch between two ranking definitions.

**Independent test**: Map fixtures verify year switching, comparable-anomaly
mode, county-wide effective-rate mode, gray unranked properties, viewport
filtering, and property selection.

**Acceptance scenarios**:

1. Given a supported year, when the county map loads, then eligible CSV-backed
   properties receive green-to-yellow-to-orange-to-red styling and unavailable
   rankings are gray or hidden by an explicit layer control.
2. Given either map ranking mode, when the user switches modes, then the legend
   names the active statistic and the selected year and viewport remain stable.
3. Given a map feature, when the user selects it, then the property detail view
   opens using the stable parcel ID.

### User story 5 — Operate a safe public service (P1)

As a self-hosting operator, I can restart the service, retain the active
dataset, refresh data atomically, and serve the read-only explorer over HTTPS.

**Independent test**: A Linux lifecycle fixture exercises startup, import,
failed import, successful publication, restart, cache reuse, and recovery of
the last active version.

## Functional requirements

| ID | Requirement | Priority | GitHub ticket |
|----|-------------|----------|---------------|
| FR-001 | Provide a Zig Linux service with configuration, health reporting, logging, static assets, and a stable HTTP boundary. | High | [#1](https://github.com/sej69/property_tax/issues/1) |
| FR-002 | Discover all tax years present in operator-provided files and publish an available-year index. | High | [#2](https://github.com/sej69/property_tax/issues/2) |
| FR-003 | Preserve `Parcel_ID`/`PIN` as a 12-character text identifier, including leading zeroes, across ingestion, storage, joins, exports, and geometry. | High | [#2](https://github.com/sej69/property_tax/issues/2) |
| FR-004 | Retain `Levy_Code`, `Neighborhood`, `Property_Class`, `Homestead`, `Use_Code`, `Structure_Type`, `Living_Sq_Ft`, `Market_Value`, `Year_Built`, `Acres`, `Deed_Acres`, `Bedrooms`, `Bathrooms`, `Stories`, `Basement`, `Building_Value`, and `Land_Value` when present. | High | [#2](https://github.com/sej69/property_tax/issues/2) |
| FR-005 | Quarantine invalid rows, reject normalized duplicate IDs, retain source checksums and import reports, and publish dataset versions atomically. | High | [#2](https://github.com/sej69/property_tax/issues/2), [#11](https://github.com/sej69/property_tax/issues/11) |
| FR-006 | Provide a native Zig PolymorphDB provider contract for durable property-year rows, derived snapshots, indexed filters, batch retrieval, aggregations, ranking projections, and restart recovery. | High | [#3](https://github.com/sej69/property_tax/issues/3) |
| FR-007 | Join only CSV-backed parcel IDs to Anoka County parcel geometry or centroids and cache geometry by dataset version and parcel ID. | High | [#4](https://github.com/sej69/property_tax/issues/4) |
| FR-008 | Permit property search by normalized address and exact parcel ID, with disambiguation and explicit not-found/unsupported states. | High | [#7](https://github.com/sej69/property_tax/issues/7), [#9](https://github.com/sej69/property_tax/issues/9) |
| FR-009 | Display total tax, special assessments separately, market value, land/building value, effective tax rate, rate percentage, property characteristics, source version, and freshness. | High | [#6](https://github.com/sej69/property_tax/issues/6), [#9](https://github.com/sej69/property_tax/issues/9) |
| FR-010 | Define effective rate as `Total_Tax / Market_Value`; return unavailable when market value is zero or missing. | High | [#6](https://github.com/sej69/property_tax/issues/6) |
| FR-011 | Display year-by-year total tax, market value, effective rate, special assessments, comparable median, q25/q75, peer count, difference from median, and peer percentile. | High | [#6](https://github.com/sej69/property_tax/issues/6), [#9](https://github.com/sej69/property_tax/issues/9) |
| FR-012 | Apply a two-stage county-only comparable model: hard tax-context eligibility first, physical similarity second. | High | [#5](https://github.com/sej69/property_tax/issues/5) |
| FR-013 | Require same `Levy_Code` and `Property_Class`; match known `Homestead`; strongly prefer same `Neighborhood` through explicit context tiers. | High | [#5](https://github.com/sej69/property_tax/issues/5) |
| FR-014 | Weight physical similarity as living area 25%, market value 20%, year built 15%, lot acreage 10%, bedrooms 10%, bathrooms 10%, structure/stories/basement 10%. | High | [#5](https://github.com/sej69/property_tax/issues/5) |
| FR-015 | Apply configurable tolerance gates: living area approximately 20%, market value approximately 25%, year built 15 years, bedroom/bathroom difference at most 1, and urban/rural lot-area rules. | High | [#5](https://github.com/sej69/property_tax/issues/5) |
| FR-016 | Never use tax amount, effective rate, tax anomaly, or excess tax as similarity inputs; exclude the subject property; resolve ties deterministically. | High | [#5](https://github.com/sej69/property_tax/issues/5) |
| FR-017 | Select 15 nearest peers by default, configurable from 10 to 20; mark fewer than 5 valid peers insufficient. | High | [#5](https://github.com/sej69/property_tax/issues/5) |
| FR-018 | Calculate peer median, q25/q75, subject percentile, percentage-point difference, percentage difference, estimated excess tax when possible, anomaly score, confidence score, confidence label, and plain-language flag. | High | [#5](https://github.com/sej69/property_tax/issues/5), [#6](https://github.com/sej69/property_tax/issues/6) |
| FR-019 | Calculate both comparable-relative anomaly percentile and county-wide effective-rate percentile for every supported year. | High | [#6](https://github.com/sej69/property_tax/issues/6) |
| FR-020 | Expose read-only property, history, comparables, map ranking, geometry, year, freshness, and CSV export APIs without upload or authentication endpoints. | High | [#7](https://github.com/sej69/property_tax/issues/7) |
| FR-021 | Serve MapLibre-compatible OpenStreetMap-derived basemap access through a seven-day Zig tile cache/proxy with attribution, upstream-header handling, and CSV-derived coverage gating. | High | [#8](https://github.com/sej69/property_tax/issues/8) |
| FR-022 | Provide desktop-first property and county map views with keyboard operation, visible focus, accessible tables, color-safe legends, and no reliance on map color alone. | High | [#9](https://github.com/sej69/property_tax/issues/9), [#10](https://github.com/sej69/property_tax/issues/10) |
| FR-023 | Rebuild all derived comparables, rankings, geometry references, and tile coverage during operator-triggered import, then publish them atomically. | High | [#11](https://github.com/sej69/property_tax/issues/11) |
| FR-024 | Provide reproducible automated tests, Linux benchmarks, accessibility checks, dependency/license review, and public abuse/rate-limit validation. | High | [#12](https://github.com/sej69/property_tax/issues/12) |

## Comparable model contract

### Stage 1: tax-context eligibility

All peers are within Anoka County and the same selected tax year. Candidates
must share `Levy_Code` and `Property_Class`. `Homestead` must match when both
values are known. `Neighborhood` is recorded as an eligibility tier, not a
numeric similarity weight:

1. Tier 1: same levy code, property class, known homestead, and neighborhood.
2. Tier 2: same levy code, property class, known homestead, different
   neighborhood within the same levy code.
3. Tier 3: same levy code and property class when homestead or neighborhood is
   missing or the neighborhood constraint is explicitly relaxed.

Missing hard-match fields are never silently treated as equal. Every selected
tier and relaxation is stored in `comparable_match_basis`.

### Stage 2: physical similarity

Similarity is calculated from normalized numeric differences and explicit
categorical compatibility using the weights in FR-014. Candidates outside the
tolerance gates are excluded before nearest-neighbor selection except in an
explicit lower-confidence fallback. Missing physical fields are not imputed
from tax outcomes or treated as equal. A pair may omit a missing component and
renormalize remaining weights only when at least 70% of configured score weight
remains available; missingness and coverage reduce confidence.

The default peer set is 15, configurable from 10–20. The subject parcel is
excluded. Ties use normalized score followed by parcel ID. Tax outcomes are
never similarity inputs.

Primary comparison statistics are peer median, q25, q75, peer percentile,
percentage-point difference, percentage difference, and estimated excess tax
when calculable. The direct anomaly formula is:

```text
tax_anomaly_score = (subject_effective_tax_rate - peer_median_effective_tax_rate)
                    / peer_median_effective_tax_rate
```

Three concepts remain distinct: comparable score, tax anomaly score, and
confidence score. Confidence labels are High, Medium, Low, or Insufficient;
they reflect peer count, context tier, similarity, missingness, and tolerance
relaxation. The product never labels a property overtaxed.

## Non-functional requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-001 | All normal browsing is read-only; no public upload, authentication, owner identity, or contact data is exposed. | High |
| NFR-002 | All public results identify tax year, source/import version, comparison definition version, and freshness. | High |
| NFR-003 | Ordinary map browsing never sends the full county dataset to the browser; use viewport queries, clusters, or vector tiles. | High |
| NFR-004 | The service targets Linux and remains a self-contained Zig deployment behind HTTPS. | High |
| NFR-005 | Data import and derived publication are deterministic, versioned, restartable, and fail closed. | High |
| NFR-006 | The primary path is server-side filtering, aggregation, ranking, pagination, and export. | High |
| NFR-007 | Open-source dependencies and map attribution/license requirements are documented. | High |
| NFR-008 | Core controls and data views meet a WCAG 2.2 AA-equivalent desktop-first target; mobile layout is not a dedicated release target. | Medium |
| NFR-009 | Performance targets are validated by Linux benchmarks rather than assumed: search/detail responses should remain bounded, map responses viewport-scoped, and imports observable. | High |

## Constraints and non-goals

- Use the operator-provided CSV files; source acquisition/download logistics are
  outside this mission.
- Use PolymorphDB through the documented native Zig interface; unsupported
  capabilities must be surfaced rather than hidden behind incorrect in-memory
  fallbacks.
- Use MapLibre GL JS and OpenStreetMap-derived basemap data. Use PROJ only if
  local coordinate conversion requires it.
- Permit map data and basemap tile coverage only for locations represented by
  imported CSV-backed records. Do not geocode or display unknown properties.
- Do not implement tax payment, filing, legal advice, assessment correction,
  owner contact, property editing, or bulk county export.
- Do not introduce server-side saved searches or accounts.
- Do not enable the independent statistical model in v1 unless held-out
  validation is completed; reserve robust regression as phase two.

## Key entities

- **Dataset version**: immutable source checksums, available years, schema
  version, import report, and publication state.
- **Property**: stable 12-character parcel ID/PIN, address display fields,
  classification, context, characteristics, and geometry references.
- **Property tax year**: year-specific tax, assessment, value, physical,
  classification, source version, and effective-rate data.
- **Comparable snapshot**: versioned peer definition, eligibility tier,
  relaxation record, peer reference, similarity, statistics, anomaly,
  confidence, and classification flag.
- **Rank projection**: year/mode/property rank and percentile for comparable
  anomaly and county-wide effective rate.
- **Geometry cache entry**: versioned parcel ID, centroid/simplified geometry,
  CRS metadata, source reference, and cache freshness.
- **Tile coverage entry**: dataset-version tile coordinate coverage derived from
  CSV-backed parcel geometry or centroids.

## Success criteria

- **SC-001**: An operator can ingest a new CSV year and publish a complete,
  checksummed dataset version without a partial public state.
- **SC-002**: A property search returns stable parcel identity, cached map
  location, selected-year statistics, tax history, and a reproducible comparable
  result when sufficient peers exist.
- **SC-003**: Every comparable result records its context tier, relaxation,
  peer count, similarity, median/q25/q75, anomaly, confidence, and definition
  version.
- **SC-004**: The county map supports both ranking modes and tax-year cycling
  without sending the full county dataset to the browser.
- **SC-005**: No property absent from the imported CSV datasets is displayed or
  queried by the application.
- **SC-006**: The PolymorphDB provider vertical slice proves durable indexed
  retrieval, derived snapshot persistence, ranking calculation, atomic publish,
  and restart recovery.
- **SC-007**: Linux build, API tests, ingestion fixtures, comparable golden
  cases, map/coverage tests, accessibility checks, and benchmark results are
  retained as release evidence.

## Assumptions and decisions

- Current local data is a 2026 snapshot; future source files may contain
  unknown years and the importer discovers them dynamically.
- The existing downloader is the source-field reference, and its parcel-ID
  normalization behavior is part of the ingestion contract.
- The initial direct comparable engine is the v1 anomaly method; the
  independent statistical model is a later phase.
- A 15-peer default and 10–20 configurable range resolves the original
  approximately “10–20” peer request.
- Deployment operations, domain ownership, and certificate administration are
  operator-managed; the application supplies HTTPS-compatible deployment
  guidance and works behind a self-hosted reverse proxy.

## GitHub ticket map

The public issue backlog is the delivery index for this mission:

- #1 service bootstrap
- #2 ingestion and normalized schema
- #3 PolymorphDB provider vertical slice
- #4 geometry join and cache
- #5 hierarchical comparable engine
- #6 tax-year rankings and anomaly projections
- #7 read-only API
- #8 tile proxy and coverage gate
- #9 property search/detail UI
- #10 county map UI
- #11 import rebuild and operations
- #12 tests, benchmarks, accessibility, and security
- #13 phase-two statistical model

The mission plan and work packages may combine or split these issues for
reviewability, but every issue must receive an explicit disposition before
mission closure.
