---
work_package_id: WP02
title: Prove the PolymorphDB provider vertical slice
dependencies: [WP01]
requirement_refs: [FR-006, NFR-005, NFR-006]
planning_base_branch: main
merge_target_branch: main
subtasks: [T005, T006, T007]
task_type: implement
tracker_refs:
  - https://github.com/sej69/property_tax/issues/3
---

# Objective

Implement and prove the native Zig provider boundary required by this app.

## Subtasks

- T005: Define provider interfaces for property-year rows, snapshots, exact
  filters, batch candidate retrieval, geometry references, and dataset versions.
- T006: Implement the PolymorphDB adapter or a bounded fixture-backed proof for
  durable writes, restart recovery, aggregation, percentiles, and projections.
- T007: Document capability gaps without claiming that the bounded analyst-table
  surface is general SQL or spatial search.

## Validation and definition of done

- Native Zig provider contract tests and restart/recovery fixture pass.
- Every required PolymorphDB operation has explicit pass/fail evidence.
- HTTP handlers do not depend on provider implementation details.
