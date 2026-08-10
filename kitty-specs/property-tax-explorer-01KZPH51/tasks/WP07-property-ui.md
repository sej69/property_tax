---
work_package_id: WP07
title: Build property search and detail UI
dependencies: [WP05, WP06]
requirement_refs: [FR-008, FR-009, FR-010, FR-011, FR-022, NFR-008]
planning_base_branch: main
merge_target_branch: main
subtasks: [T022, T023, T024]
task_type: implement
tracker_refs:
  - https://github.com/sej69/property_tax/issues/9
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
