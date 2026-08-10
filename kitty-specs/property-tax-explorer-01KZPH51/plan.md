# Implementation Plan: Anoka County Property Tax Explorer

**Branch**: `kitty/mission-property-tax-explorer-01KZPH51` | **Target**: `main`  
**Date**: 2026-08-10  
**Spec**: [spec.md](spec.md)  
**Input**: [FUNCTIONALITY_REQUIREMENTS.md](../../FUNCTIONALITY_REQUIREMENTS.md) and GitHub issues [#1–#13](https://github.com/sej69/property_tax/issues)

## Summary

Build one Linux-deployable Zig service and browser application for the Anoka
County tax explorer. Stage work around a versioned dataset boundary: ingest and
validate CSVs, persist normalized property-year rows and derived snapshots
through a PolymorphDB provider adapter, join only CSV-backed parcel IDs to
county geometry, expose bounded read-only APIs, and render MapLibre property
and county map views.

The implementation must remain useful with the current 2026 files while
discovering future years dynamically. Provider limitations must be explicit.
The browser must never become the authority for tax calculations or full-county
data.

## Technical context

| Surface | Decision |
| --- | --- |
| Application runtime | Native Zig service targeting Linux. |
| Browser | HTML/CSS/JavaScript with MapLibre GL JS; no Python browser runtime. |
| Data provider | PolymorphDB through a native Zig provider interface. |
| Source input | Operator-managed CSV snapshots; parcel IDs are 12-character text. |
| Geometry | Anoka County ArcGIS parcel service, cached by dataset version and parcel ID. |
| Basemap | OpenStreetMap-derived data through a seven-day Zig tile cache/proxy. |
| Import model | Stage → validate → derive → publish atomically. |
| Public surface | Read-only, no authentication, no uploads, no saved searches. |
| Deployment | Self-hosted Linux behind HTTPS reverse proxy. |

## Charter and governance checks

| Gate | Plan response |
| --- | --- |
| Deterministic data | Preserve checksums, dataset versions, normalized IDs, definition versions, and reproducible peer sets. |
| Fail closed | Reject duplicate IDs, quarantine invalid rows, return unavailable for zero/missing market value, and never publish partial derived state. |
| Explainability | Persist comparable tier, relaxations, component scores, peer count, statistics, anomaly, and confidence inputs. |
| Provider boundary | Keep PolymorphDB operations behind an interface; do not hide unsupported capabilities behind in-memory behavior. |
| Public safety | Exclude raw CSVs from Git, expose no owner/contact fields, rate-limit reads, and keep tile access CSV-scoped. |
| Reviewability | Each work package has owned surfaces, dependencies, tests, and an independent definition of done. |

## Project structure decision

```text
app/                  Zig service entry point and configuration
ingest/ provider/     CSV staging and PolymorphDB adapter
geometry/ comparable/ ranking/ api/ tiles/ model/
                      Isolated Zig implementation surfaces
property-ui/ county-ui/
                      Browser property and county map surfaces
tests/                Deterministic fixtures, contract, browser, lifecycle tests
build.zig             Linux build and test entry point
docs/                 Provider, ingestion, geometry, API, operations, validation
```

Use the Zig standard library where practical. Add dependencies only when
required for HTTP, CSV, JSON, geometry, or PolymorphDB integration and document
their license/build behavior. Keep the first service as one deployable binary;
imports and remote GIS access must not block ordinary browsing.

## Implementation concerns

### IC-01 — Schema and immutable dataset boundary

Implement normalized text parcel IDs, dynamic year discovery, validation,
duplicate/quarantine reporting, checksums, staging, and atomic publication.

### IC-02 — PolymorphDB structured provider surface

Prove durable property-year and comparable-snapshot storage, exact indexed
filters, batch retrieval, percentile/median access, rank projections, geometry
references, and restart recovery.

### IC-03 — Geometry and tile coverage

Join stable IDs to county GIS, normalize CRS, cache simplified geometry and
centroids, and derive coverage exclusively from CSV-backed parcels.

### IC-04 — Comparable cohort and tax anomaly

Implement hard eligibility tiers followed by weighted/tolerance-gated physical
similarity. Exclude tax outcomes from similarity and persist confidence inputs.

### IC-05 — Ranking and read-only API

Expose search, history, comparables, geometry, years, map features, both ranking
modes, metadata, pagination, exports, rate limits, and cache headers.

### IC-06 — Browser map and property journeys

Build accessible property and county map flows with MapLibre, OSM attribution,
year/mode controls, supplementary tables, and graceful unavailable states.

### IC-07 — Operational publication and evidence

Provide import/rebuild, last-known-good recovery, observability, HTTPS guidance,
tests, benchmarks, accessibility checks, and dependency/license evidence.

### IC-08 — Phase-two independent model

After direct comparables and validation are stable, implement robust regression
with held-out validation and separate residual presentation.

## Work package sequence

1. **WP01 — Zig service and versioned ingestion**: issues #1 and #2.
2. **WP02 — PolymorphDB provider vertical slice**: issue #3.
3. **WP03 — County geometry and coverage**: issue #4.
4. **WP04 — Hierarchical comparable engine**: issue #5.
5. **WP05 — Rankings and read-only API**: issues #6 and #7.
6. **WP06 — Tile cache/proxy**: issue #8.
7. **WP07 — Property search/detail UI**: issue #9.
8. **WP08 — County map UI**: issue #10.
9. **WP09 — Import publication and operations**: issue #11.
10. **WP10 — Tests, benchmarks, accessibility, and security**: issue #12.
11. **WP11 — Independent statistical model**: issue #13.

WPs are implemented in dependency order. WP07 and WP08 may run in parallel
only after WP05 and WP06 expose stable browser contracts.

## Validation matrix

| Area | Evidence |
| --- | --- |
| Identifier integrity | Fixtures prove text preservation, 12-character normalization, duplicate detection, and geometry consistency. |
| Ingestion | Multi-year fixture proves discovery, missing-field report, quarantine, checksum, staging, atomic publication, and restart. |
| Provider | Vertical-slice fixture proves durable writes, indexed retrieval, candidate batch, snapshots, percentiles/ranks, and recovery. |
| Comparables | Golden fixtures prove context tiers, weights, tolerances, missingness, subject exclusion, tie breaks, median/q25/q75, anomaly, and confidence. |
| API | Contract tests cover search, detail, years, comparables, map modes, pagination, exports, unavailable states, cache, and rate limits. |
| Geometry/tiles | Tests prove CSV-only geometry, CRS metadata, simplified cache, coverage gate, attribution, and no prefetch. |
| Browser | Browser evidence covers keyboard controls, map selection, year/mode switching, tables, chart fallback, and color-independent labels. |
| Operations | Linux lifecycle receipt covers build, import failure isolation, publish, restart, cache reuse, and HTTPS compatibility. |
| Phase two | Held-out validation records robust-regression performance, model version, residual behavior, and agreement with comparables. |

## Complexity tracking

| Complexity | Why needed |
| --- | --- |
| Versioned derived snapshots | Responsive, consistent map and property reads across year/mode changes. |
| Provider interface | PolymorphDB capability details are still being proven. |
| Geometry/tile coverage index | Geographic tile squares must respect the CSV-backed product boundary. |
| Two-stage comparable scoring | Tax context and physical similarity represent different causes of variation. |
| Separate phase-two model | Independent evidence should not overstate an unvalidated v1 signal. |
