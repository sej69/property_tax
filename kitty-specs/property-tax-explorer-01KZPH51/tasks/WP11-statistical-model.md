---
work_package_id: WP11
title: Implement the phase-two independent statistical model
dependencies:
- WP04
- WP05
- WP10
requirement_refs:
- FR-018
- NFR-002
- NFR-009
tracker_refs:
- https://github.com/sej69/property_tax/issues/13
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on kitty/mission-property-tax-explorer-01KZPH51. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into kitty/mission-property-tax-explorer-01KZPH51 unless the human explicitly redirects the landing branch.
subtasks:
- T035
- T036
- T037
history: []
authoritative_surface: model/
create_intent:
- model/model.zig
- model/model_api.zig
- model-ui/model.js
- tests/model_test.zig
- docs/statistical-model.md
execution_mode: code_change
owned_files:
- model/model.zig
- model/model_api.zig
- model-ui/model.js
- tests/model_test.zig
- docs/statistical-model.md
tags: []
task_type: implement
---

# Objective

Add a separately validated robust-regression signal without replacing direct
comparables.

## Subtasks

- T035: Define training/held-out splits, feature provenance, model version,
  robust regression fit, and residual calculation.
- T036: Persist predicted rate, residual, model confidence, and validation
  metrics separately from comparable snapshots.
- T037: Add API/UI presentation distinguishing actual, predicted, residual,
  direct anomaly, and agreement/disagreement.

## Definition of done

- Held-out validation passes the documented threshold before enablement.
- Model version and confidence are visible.
- Direct comparable results remain independently available.
