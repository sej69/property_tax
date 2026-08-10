---
work_package_id: WP05
title: Build rankings and the read-only API
dependencies:
- WP02
- WP03
- WP04
requirement_refs:
- FR-008
- FR-009
- FR-010
- FR-011
- FR-019
- FR-020
- NFR-001
- NFR-002
- NFR-006
tracker_refs:
- https://github.com/sej69/property_tax/issues/6
- https://github.com/sej69/property_tax/issues/7
planning_base_branch: kitty/mission-property-tax-explorer-01KZPH51
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on kitty/mission-property-tax-explorer-01KZPH51. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
subtasks:
- T015
- T016
- T017
- T018
history: []
authoritative_surface: ranking/
create_intent:
- ranking/ranking.zig
- api/api.zig
- tests/api_test.zig
- docs/api.md
execution_mode: code_change
owned_files:
- ranking/ranking.zig
- api/api.zig
- tests/api_test.zig
- docs/api.md
tags: []
task_type: implement
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
