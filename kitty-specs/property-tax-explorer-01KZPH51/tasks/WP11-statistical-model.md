---
work_package_id: WP11
title: Implement the phase-two independent statistical model
dependencies: [WP04, WP05, WP10]
requirement_refs: [FR-018, NFR-002, NFR-009]
planning_base_branch: main
merge_target_branch: main
subtasks: [T035, T036, T037]
task_type: implement
tracker_refs:
  - https://github.com/sej69/property_tax/issues/13
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
