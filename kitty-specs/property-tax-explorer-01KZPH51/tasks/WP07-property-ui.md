---
work_package_id: WP07
title: Build property search and detail UI
dependencies:
- WP05
- WP06
requirement_refs:
- FR-008
- FR-009
- FR-010
- FR-011
- FR-022
- NFR-008
tracker_refs:
- https://github.com/sej69/property_tax/issues/9
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on kitty/mission-property-tax-explorer-01KZPH51. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into kitty/mission-property-tax-explorer-01KZPH51 unless the human explicitly redirects the landing branch.
subtasks:
- T022
- T023
- T024
history: []
authoritative_surface: property-ui/
create_intent:
- property-ui/index.html
- property-ui/app.js
- property-ui/styles.css
- tests/property_ui_test.js
execution_mode: code_change
owned_files:
- property-ui/index.html
- property-ui/app.js
- property-ui/styles.css
- tests/property_ui_test.js
tags: []
task_type: implement
assignee: "codex"
agent: "codex"
---

# Objective

Build the desktop-first property journey with accessible tables and charts.

## Subtasks

- T022: Add address/parcel search, disambiguation, selected property map, and
  property summary.
- T023: Add year cycling, history charts/table fallback, comparable distribution,
  peer table, anomaly/confidence explanation, and exports.
- T024: Add keyboard focus/order, accessible labels, color-safe status text, and
  unavailable/loading/error states.

## Definition of done

- Changing year updates all year-dependent values atomically.
- Map is supplementary to accessible text/table data.

## Activity Log

- 2026-08-10T21:07:33Z – codex – Moved to in_progress
- 2026-08-10T21:07:38Z – codex – Implementation validated: property search/detail UI, year cycling, comparable display and user-facing method labels; zig build test; zig build.
- 2026-08-10T21:07:40Z – codex – Self-review fallback authorized by project owner.
