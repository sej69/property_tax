---
work_package_id: WP02
title: Prove the PolymorphDB provider vertical slice
dependencies:
- WP01
requirement_refs:
- FR-006
- NFR-005
- NFR-006
tracker_refs:
- https://github.com/sej69/property_tax/issues/3
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this mission were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
subtasks:
- T005
- T006
- T007
history: []
authoritative_surface: provider/
create_intent:
- provider/provider.zig
- tests/provider_test.zig
- docs/polymorphdb-provider.md
execution_mode: code_change
owned_files:
- provider/provider.zig
- tests/provider_test.zig
- docs/polymorphdb-provider.md
tags: []
task_type: implement
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
