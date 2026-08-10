---
work_package_id: WP04
title: Implement the hierarchical comparable engine
dependencies:
- WP01
- WP02
requirement_refs:
- FR-012
- FR-013
- FR-014
- FR-015
- FR-016
- FR-017
- FR-018
tracker_refs:
- https://github.com/sej69/property_tax/issues/5
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
subtasks:
- T011
- T012
- T013
- T014
history: []
authoritative_surface: comparable/
create_intent:
- comparable/comparable.zig
- tests/comparable_test.zig
- docs/comparable-methodology.md
execution_mode: code_change
owned_files:
- comparable/comparable.zig
- tests/comparable_test.zig
- docs/comparable-methodology.md
tags: []
task_type: implement
---

# Objective

Implement the county-only two-stage comparable method with explainable scores
and confidence.

## Subtasks

- T011: Implement levy/class/homestead/neighborhood eligibility tiers and
  persisted relaxation basis.
- T012: Implement normalized physical weights and tolerance gates for living
  area, value, age, acreage, bedrooms, bathrooms, structure, stories, basement.
- T013: Implement missing-feature coverage, subject exclusion, deterministic
  ties, configurable 10–20 peers, and insufficient cohorts.
- T014: Implement median/q25/q75, peer percentile, anomaly, confidence, and
  plain-language classification with golden fixtures.

## Validation and definition of done

- Golden Tier 1/2/3 peer sets and missing/tolerance confidence cases pass.
- Tax outcomes never enter similarity.
- Peer results are reproducible from dataset/year/definition versions.
- The result never says “overtaxed.”
