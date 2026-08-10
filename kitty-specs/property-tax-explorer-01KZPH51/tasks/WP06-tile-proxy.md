---
work_package_id: WP06
title: Implement the seven-day tile proxy and cache
dependencies:
- WP03
- WP05
requirement_refs:
- FR-021
- NFR-003
- NFR-007
tracker_refs:
- https://github.com/sej69/property_tax/issues/8
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
subtasks:
- T019
- T020
- T021
history: []
authoritative_surface: tiles/
create_intent:
- tiles/tiles.zig
- tests/tiles_test.zig
- docs/tile-policy.md
execution_mode: code_change
owned_files:
- tiles/tiles.zig
- tests/tiles_test.zig
- docs/tile-policy.md
tags: []
task_type: implement
---

# Objective

Serve MapLibre-compatible OSM-derived tiles through a bounded cache and
CSV-derived coverage gate.

## Subtasks

- T019: Implement tile validation, upstream identity, seven-day cache policy,
  and upstream-header handling.
- T020: Enforce coverage index, HTTPS assumptions, User-Agent, Referer, and
  visible attribution configuration.
- T021: Test cache hit/expiry, upstream failure, out-of-coverage, and no-prefetch.

## Definition of done

- Tile policy and attribution are documented.
- Property overlays remain strictly CSV-backed.
