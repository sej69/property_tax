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
branch_strategy: Planning artifacts for this mission were generated on kitty/mission-property-tax-explorer-01KZPH51. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into kitty/mission-property-tax-explorer-01KZPH51 unless the human explicitly redirects the landing branch.
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
assignee: "codex"
agent: "codex"
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

## Activity Log

- 2026-08-10T21:07:15Z – codex – Moved to in_progress
- 2026-08-10T21:07:19Z – codex – Implementation validated: seven-day tile policy, CSV-backed coverage gate, OSM attribution and read-only tile route; zig build test; zig build.
- 2026-08-10T21:07:22Z – codex – Self-review fallback authorized by project owner.
- 2026-08-10T21:29:04Z – codex – Done override: Owner-authorized non-fast-forward merge delivered the mission branch to main; expected lane branches were unavailable on Windows and acceptance gaps remain documented.
