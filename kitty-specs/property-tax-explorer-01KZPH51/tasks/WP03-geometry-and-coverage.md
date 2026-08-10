---
work_package_id: WP03
title: Join county geometry and build coverage indexes
dependencies:
- WP01
requirement_refs:
- FR-007
- FR-021
- NFR-003
- NFR-007
tracker_refs:
- https://github.com/sej69/property_tax/issues/4
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on kitty/mission-property-tax-explorer-01KZPH51. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into kitty/mission-property-tax-explorer-01KZPH51 unless the human explicitly redirects the landing branch.
subtasks:
- T008
- T009
- T010
history: []
authoritative_surface: geometry/
create_intent:
- geometry/geometry.zig
- tests/geometry_test.zig
- docs/geometry-and-tiles.md
execution_mode: code_change
owned_files:
- geometry/geometry.zig
- tests/geometry_test.zig
- docs/geometry-and-tiles.md
tags: []
task_type: implement
---

# Objective

Join stable CSV-backed parcel IDs to county GIS and create cached geometry,
centroids, and tile-coordinate coverage.

## Subtasks

- T008: Implement PIN/parcel join, GeoJSON parsing, CRS metadata, and simplified
  geometry/centroid cache.
- T009: Define missing-geometry and remote-service failure behavior; browsing
  must not block on live GIS calls.
- T010: Build coverage entries from CSV-backed geometry or centroids and reject
  unknown property and out-of-coverage requests.

## Validation and definition of done

- Known-PIN, leading-zero, missing-geometry, and unknown-PIN fixtures pass.
- Geometry is versioned by dataset and parcel ID.
- No property absent from imported CSVs is queried or displayed.
