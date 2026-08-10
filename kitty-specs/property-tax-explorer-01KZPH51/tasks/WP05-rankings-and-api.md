---
work_package_id: WP05
title: Build rankings and the read-only API
dependencies: [WP02, WP03, WP04]
requirement_refs: [FR-008, FR-009, FR-010, FR-011, FR-019, FR-020, NFR-001, NFR-002, NFR-006]
planning_base_branch: main
merge_target_branch: main
subtasks: [T015, T016, T017, T018]
task_type: implement
tracker_refs:
  - https://github.com/sej69/property_tax/issues/6
  - https://github.com/sej69/property_tax/issues/7
---

# Objective

Precompute ranking projections and expose stable read-only JSON/CSV endpoints.

## Subtasks

- T015: Implement effective-rate, county-percentile, and comparable-anomaly
  projections per dataset version and year.
- T016: Add address/parcel search, property detail, history, comparables,
  available-year, and geometry endpoints.
- T017: Add viewport/mode/year map endpoints, pagination, CSV exports, freshness,
  and dataset metadata.
- T018: Add response validation, rate limits, cache headers, unavailable states,
  and provider-error mapping.

## Validation and definition of done

- API contract tests cover every endpoint and zero/missing market-value case.
- Browser API has no upload/authentication surface.
- Both ranking modes are explicit in response and metadata.
