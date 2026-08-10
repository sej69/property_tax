---
work_package_id: WP08
title: Build the county-wide map explorer
dependencies:
- WP05
- WP06
requirement_refs:
- FR-019
- FR-021
- FR-022
- NFR-003
- NFR-008
tracker_refs:
- https://github.com/sej69/property_tax/issues/10
planning_base_branch: kitty/mission-property-tax-explorer-01KZPH51
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on kitty/mission-property-tax-explorer-01KZPH51. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into kitty/mission-property-tax-explorer-01KZPH51 unless the human explicitly redirects the landing branch.
subtasks:
- T025
- T026
- T027
history: []
authoritative_surface: county-ui/
create_intent:
- county-ui/map.js
- county-ui/map.css
- tests/county_map_test.js
execution_mode: code_change
owned_files:
- county-ui/map.js
- county-ui/map.css
- tests/county_map_test.js
tags: []
task_type: implement
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
