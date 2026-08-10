---
work_package_id: WP08
title: Build the county-wide map explorer
dependencies: [WP05, WP06]
requirement_refs: [FR-019, FR-021, FR-022, NFR-003, NFR-008]
planning_base_branch: main
merge_target_branch: main
subtasks: [T025, T026, T027]
task_type: implement
tracker_refs:
  - https://github.com/sej69/property_tax/issues/10
---

# Objective

Build the MapLibre county explorer with tax-year and ranking-mode controls.

## Subtasks

- T025: Add MapLibre shell, OSM attribution, clusters/vector overview, and
  viewport feature loading.
- T026: Add year selector, comparable-anomaly mode, county-rate mode, legend,
  gray unranked state, and popup values.
- T027: Link features to property detail and test selection, mode switching,
  viewport stability, and unavailable rankings.

## Definition of done

- Legend names the active statistic.
- Full county data is not loaded into one browser response.
